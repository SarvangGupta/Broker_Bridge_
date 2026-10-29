# RMBUYER-GST-VERIFICATION-01 — Audit Report

**Sprint:** GST-based Buyer verification. Read-only audit and implementation plan.
**Date:** 2026-10-29
**Branch:** `feature/broker-nilesh` (uncommitted work left untouched)
**Audit status:** **PASS WITH LIMITATIONS** (limitations are listed in §1.3)

---

## 1. Summary

### 1.1 Verdict

The business rule ("a Buyer posts requirements only after GST submission and Admin approval") **is not enforced anywhere today**, and the current schema **cannot enforce it safely without changes**. The biggest problems are not missing UI. They are existing backend gaps:

| # | Severity | Finding |
|---|---|---|
| F1 | **Critical** | Buyers can set their own company's `is_verified`, `status`, `trust_score` and `gst`. The live policy `"Users can update their own company"` allows UPDATE on the caller's own company, and `authenticated` has UPDATE on **every** column of `companies`. No trigger protects any column. A verification flag stored in `companies` is self-approvable as things stand. |
| F2 | **Critical** | Most requirement insert paths **bypass RLS**. The Next.js server actions and `/api/v1/requirements/sync` use Drizzle over `DATABASE_URL`, which connects as `postgres` (confirmed live: `current_user = postgres`). RLS policies alone cannot enforce the rule. |
| F3 | **Critical (separate from this sprint)** | Privilege escalation risk in [buyer-auth.ts](../src/server/utils/buyer-auth.ts). `verifyBuyerSession()` auto-provisions a `public.users` row with `role` taken from `user.user_metadata.role`, which the client controls at sign-up, and writes it as `postgres`. The trigger `trg_sync_privileged_role` then copies that role into trusted `raw_app_meta_data`. A user who signs up with `role: 'admin'` and calls any Buyer server action could become an admin. **Not exploited or tested in this audit.** Needs its own fix sprint. |
| F4 | High | `/api/v1/requirements/sync` checks no role at all. Any authenticated user with a `company_id` (including Sellers) can insert `Open` requirements for their company. `verifyBuyerSession()` also never checks the role: `resolveBuyerRole()` always returns `BUYER_ADMIN`. |
| F5 | High | RLS lets Brokers insert a requirement for **any** `company_id`: the branch `broker_id = auth.uid() AND is_broker()` has no company constraint. RMBroker uses this path in [work_repository.dart:287](../apps/rmbroker_mobile/lib/features/work/data/work_repository.dart). Whether Broker-posted requirements for an unverified Buyer are allowed is an owner decision (D3). |
| F6 | Medium | RMBuyer falls back to a hard-coded company ID (`companyId ??= '30000000-…0101'`) in [requirements_repository.dart](../apps/rmbuyer_mobile/lib/features/requirements/data/requirements_repository.dart). RLS currently rejects it for other users, but it must be removed. |
| F7 | Medium | Storage INSERT policies on all three existing buckets only check `auth.uid() IS NOT NULL`. Any authenticated user can write to any path. Do not copy this pattern for certificates. |
| F8 | Info | The existing web Admin "Company Approvals" queue sets `companies.status/is_verified` directly. It records no reviewer, timestamp, reason or audit trail, and on reject it also deactivates every user of the company (`users.status = false`). |

### 1.2 What can be reused

- **Web Admin panel already exists:** `app/(admin)/admin` ("Admin God Mode", desktop-only, with a Company Approvals tab). This is the smallest practical review surface. No new Admin system is needed.
- **RMSeller already has a GST REG-06 OCR parser** (uncommitted, in this working tree): [gst_certificate_parser.dart](../apps/rmseller_mobile/lib/features/profile/data/gst_certificate_parser.dart). It includes a mod-36 checksum (`isValidGstin`), the domain model `gst_certificate_extracted_data.dart`, and unit tests (`gst_certificate_extraction_test.dart`, `gst_certificate_amended_photo_test.dart`). RMSeller also has `google_mlkit_text_recognition ^0.17.1`, `image_picker ^1.2.4`, `file_picker`, `pdfx` and an invoice upload service.
- **Trusted role helpers:** `get_auth_role()`, `is_admin()` and `is_broker()` (all SECURITY DEFINER, reading `raw_app_meta_data`), plus `trg_prevent_self_company_change` on `users`.
- **Notifications:** the `notifications` table has an `idempotency_key` unique index and no INSERT grant for `authenticated`. Inserts already go only through SECURITY DEFINER functions (pattern: `notify_requirement_brokers`). RMBuyer already reads its own notifications.

### 1.3 Limitations

- Live inspection used a read-only transaction (`transaction_read_only = on`). It covered schema, policies, triggers, grants, buckets and aggregate counts only. No row contents were read or printed.
- Edge Functions: there is no `supabase/functions` directory in the repo. Deployed Edge Functions were **not** enumerated, because that needs the Supabase CLI or Management API. Assumption to confirm: none insert requirements.
- The RMBroker REST path (a Dio call before the direct insert) targets the Next.js API. Its server route was not traced end to end. It ends in `broker-mandate-actions.ts` → Drizzle insert.
- No authorized sample GST certificate corpus was found for RMBuyer. RMSeller tests use fixtures I did not open, for privacy.
- `master_states` was not checked for a GST state-code column. The mapping from code to state may need a constant table (see §7).

---

## 2. Existing schema (live, verified read-only)

### 2.1 Identity and business tables

| Table | Relevant columns | Notes |
|---|---|---|
| `users` | `id, name, mobile, email, role, status, company_id, created_by` | PK only. RLS on. Self-update cannot change `role` (WITH CHECK `lower(role) = get_auth_role()`) or `company_id` (trigger). |
| `companies` | `id, name, gst (text), business_type_id, state_id, district_id, status bool=true, is_verified bool=false, trust_score, created_by, bank_*, bank_is_verified, bank_verification_status, commodity_expertise` | **No unique index on `gst`.** No triggers. Buyers can UPDATE every column of their own row (F1). |
| `profiles_buyer` | `id` only | Empty stub. RLS on, no grants. Not useful. |
| `seller_profile_audit_logs` | (from proposed 0050) | Seller-scoped and **seller-appendable**. Unsuitable for Buyer verification audit, because Buyers must not write their own audit rows. |
| `requirement_documents` | `requirement_id, document_type, is_mandatory` | Requirement-level document *types*, not file storage. Not reusable. |

**Fields that do not exist:** PAN, legal name (separate from `companies.name`), trade name, constitution, principal-place address, pincode, registration date, registration type, verification status/history, reviewer ID, reviewed-at, rejection reason. No KYC or verification table exists.

`companies.is_verified` is read widely as a **public trust badge**: Broker directory/search, match/negotiation actions, the RMBuyer broker cards, and `analytics-actions.ts` "KYC verified". Because it is Buyer-writable today (F1), it cannot be the source of truth for posting rights. It can be a derived display flag that only a definer function writes.

### 2.2 Requirements

`requirements(company_id NN, broker_id, status default 'Open', visibility, …)`. PK only. **No triggers.** Policies:

- INSERT: `(broker_id = auth.uid() AND (is_broker() OR is_admin())) OR is_admin() OR company_id IN (own company WHERE role IN ('buyer','admin'))`. The admin/buyer check reads `public.users.role`.
- UPDATE: own company, broker or admin. There is no status-transition guard, so a Buyer could flip `Draft → Open` directly.

### 2.3 Storage (live)

| Bucket | Public | Size/MIME limits | Objects |
|---|---|---|---|
| `brokerbridge_documents` | false | none | 8 |
| `brokerbridge_lab_evidence` | false | none | 14 |
| `brokerbridge_seller_invoices` | false | none | 0 |

The SELECT policies are scoped by path (deal ID, availability ID, or company ID in segment 2, plus admin). The INSERT policies are unscoped (F7). No bucket sets `file_size_limit` or `allowed_mime_types`.

### 2.4 Admin identity

1 admin user. The web admin checks `public.users.role = 'admin'` inside each server action and then writes as `postgres`. The RLS helpers (`is_admin()`) read `raw_app_meta_data.role`, which `trg_sync_privileged_role` keeps in sync.

---

## 3. Requirement-creation paths (all of them)

| # | Path | Identity source | Runs as | Rule enforced by RLS? |
|---|---|---|---|---|
| P1 | RMBuyer `RequirementsRepository.createRequirement` → `client.from('requirements').insert` | JWT. `company_id` comes from secure storage, then a `users` lookup, then a **hard-coded fallback** (F6) | `authenticated` | Yes (RLS) |
| P2 | Web `createRequirementAction` ([requirement-actions.ts:34](../src/server/actions/requirement-actions.ts)) | `verifyBuyerSession()`; server-derived company | `postgres` | **No** |
| P3 | Web `saveDraftRequirementAction` ([buyer-requirement-actions.ts:322](../src/server/actions/buyer-requirement-actions.ts)), status `Draft` | as P2 | `postgres` | **No** |
| P4 | `POST /api/v1/requirements/sync` ([route.ts:51](../src/app/api/v1/requirements/sync/route.ts)), bulk `Open` | `auth.getUser()`, no role check (F4) | `postgres` | **No** |
| P5 | Web Broker mandate ([broker-mandate-actions.ts:462](../src/server/actions/broker-mandate-actions.ts)), `companyId` from the client payload | Broker session | `postgres` | **No** |
| P6 | RMBroker REST, then direct insert ([work_repository.dart:287](../apps/rmbroker_mobile/lib/features/work/data/work_repository.dart)), any `company_id` | JWT broker | `authenticated` | RLS allows any company (F5) |
| P7 | `test-booking-action.ts:73` (test fixture code inside `src/server/actions`) | none | `postgres` | **No.** Should not ship. |
| P8 | `seed_broker_demo_dataset.sql` | manual | `postgres` | n/a |
| P9 | Any later status UPDATE `Draft → Open` (RLS UPDATE policy) | JWT | `authenticated` | No transition guard |

**Conclusion:** the only enforcement point that covers P1–P9 is a **database trigger on `public.requirements`**. Triggers fire for `postgres` too, unlike RLS, which `postgres` bypasses as table owner. The one exception is `session_replication_role = replica`, which no app path uses. An RLS change may be added for clearer errors, but it is not sufficient on its own.

---

## 4. Upload, OCR, Admin and notification capabilities

- **RMBuyer `pubspec.yaml`** has none of `image_picker`, ML Kit, `file_picker` or `pdfx`. They must be added. Reuse RMSeller's versions, which are already resolved against the same Flutter SDK.
- **OCR:** ML Kit Text Recognition (on-device, Android/iOS) works on images only. PDF needs page rasterization via `pdfx` first, and this adds risk. Recommendation: **images only in phase 1** (D6).
- **Parser:** port or share RMSeller's `GstCertificateParser`. It already treats unknown fields as null ("Nothing is guessed") and handles OCR column splitting and `O/0` and `I/1` misreads in GSTINs. Recommend extracting it into a shared package instead of copying it (D9).
- **Admin:** extend the existing Next.js admin panel (`MasterDataTabs`) with a "Buyer GST Verifications" tab. Do not reuse `approveCompanyAction`/`rejectCompanyAction`: they have no reason, no audit, and reject deactivates users.
- **Notifications:** an in-app row is inserted by the definer review function, with idempotency key `gstv-{verification_id}-{decision}` and an explicit `action_url` (the column default is `'/seller'`). RMBuyer's `buyer_notifications_repository.dart` already lists the user's notifications. **Push delivery: no verified push dispatcher was found.** `delivery_status` rows show `'Sent'` written directly. Push is a follow-up dependency.

---

## 5. Existing Buyer impact (aggregate counts only)

| Metric | Count |
|---|---|
| Buyer user accounts (`users.role = 'buyer'`, all `status = true`) | **10** |
| … linked to a company | 4 (4 distinct companies) |
| … with no company (cannot post via RLS today) | 6 |
| Buyer companies that have posted requirements | **2** (28 requirements, 23 in active statuses) |
| Buyer companies with a non-empty `gst` | **0** |
| Buyer companies with `is_verified = true` | 2 (no evidence trail of how this was set) |
| Existing verification or certificate records | **0** (no such tables; certificate buckets empty) |
| Duplicate GST values across all companies | 0 |
| Buyers whose verification status can be determined | 0. All 10 are "not submitted" by definition. The 2 `is_verified` flags cannot be traced to any review. |
| All requirements / with `broker_id` set | 34 / 17 |

Turning the trigger on would immediately block new posts from **both** Buyer companies that are currently active, since neither has a GSTIN on file. The grandfathering policy is **D1**.

---

## 6. Proposed schema (names final only after owner approval)

### 6.1 Why new tables instead of `companies` columns

`companies` is Buyer-writable on every column (F1), shared by all roles, and has no history. Status, reviewer and OCR provenance need their own row per submission, so that we can keep versions, hold one approved row at a time, and give the trigger a row it can lock. Columns on `companies` are left for display data.

### 6.2 `public.buyer_gst_verifications` (one row per submission)

| Column | Type | Notes |
|---|---|---|
| `id` | `uuid PK default gen_random_uuid()` | |
| `company_id` | `uuid NOT NULL → companies(id)` | Derived server-side from `users.company_id` of `auth.uid()` |
| `submitted_by` | `uuid NOT NULL → users(id)` | `auth.uid()` |
| `version` | `int NOT NULL` | Per-company sequence |
| `status` | `text NOT NULL CHECK (status IN ('pending','approved','rejected','superseded','revoked'))` | |
| `gstin` | `text NOT NULL CHECK (gstin ~ '^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z][1-9A-Z]Z[0-9A-Z]$')` | Upper-cased, trimmed |
| `state_code` | `char(2) GENERATED ALWAYS AS (substr(gstin,1,2)) STORED` | |
| `legal_name`, `trade_name`, `constitution`, `principal_address`, `principal_state`, `registration_type` | `text` | Final submitted values |
| `pincode` | `text CHECK (pincode ~ '^[1-9][0-9]{5}$')` | |
| `registration_date` | `date` | |
| `ocr_values` | `jsonb NOT NULL` | Raw extracted values and confidence, as submitted. Untrusted. |
| `edited_fields` | `text[] NOT NULL default '{}'` | Fields that differ from OCR, recomputed server-side |
| `gstin_edited` | `bool NOT NULL` | Server-computed |
| `certificate_path` | `text NOT NULL` | Must start with `{auth.uid()}/` |
| `certificate_mime`, `certificate_bytes` | `text`, `int` | Checked against `storage.objects.metadata` |
| `reviewer_id` | `uuid → users(id)` | Definer-only |
| `reviewed_at` | `timestamptz` | |
| `decision_reason` | `text` | Required when rejected or revoked: `CHECK (status NOT IN ('rejected','revoked') OR length(btrim(decision_reason)) > 0)` |
| `created_at` | `timestamptz NOT NULL default now()` | |

**PAN is not stored.** It is `substr(gstin, 3, 10)` and can be derived on read if needed. This avoids holding a second sensitive identifier.

**Indexes and constraints:**
- `UNIQUE (company_id, version)`
- `UNIQUE (company_id) WHERE status = 'pending'`: one open submission per company.
- `UNIQUE (company_id) WHERE status = 'approved'`: one approval per company.
- `UNIQUE (gstin) WHERE status IN ('pending','approved')`: prevents duplicate GSTIN across Buyer companies and is safe under concurrency, because the second insert fails with `23505`. Whether Seller companies sharing a GSTIN with a Buyer counts as a conflict is D8.
- `INDEX (status, created_at)` for the admin queue.

### 6.3 `public.buyer_verification_events` (append-only audit)

`id uuid PK, verification_id uuid NOT NULL → buyer_gst_verifications, company_id uuid NOT NULL, from_status text, to_status text NOT NULL, actor_id uuid NOT NULL, reason text, created_at timestamptz NOT NULL default now()`, plus an index on `(company_id, created_at)`.

### 6.4 Grants and RLS

- Both tables: `REVOKE ALL FROM anon, authenticated`, then `GRANT SELECT TO authenticated`.
- **No INSERT/UPDATE/DELETE grants** for `authenticated`. All writes go through definer functions.
- SELECT policy: `company_id = (SELECT company_id FROM users WHERE id = auth.uid()) OR is_admin()`. Brokers and Sellers of other companies see nothing.
- Events: same SELECT policy. Buyers see their own history, minus the reviewer identity if D10 requires that (expose through a view).

### 6.5 Fix the `companies` self-update hole (prerequisite)

`REVOKE UPDATE ON public.companies FROM authenticated`, then grant column UPDATE only on the profile columns Buyers and Sellers legitimately edit. At minimum, exclude `is_verified, status, trust_score, created_by, id, bank_is_verified, bank_verification_status`. Add a `BEFORE UPDATE` trigger that rejects changes to `gst`/`name` by non-admins when the company has a `pending` or `approved` verification. Those changes then go only through the resubmit RPC.

**Impact check required before implementation:** RMSeller's bank-details and profile flows, and the Broker CRM company update, may write these columns today. This must be traced and tested first, because otherwise the column revoke would break Seller saves.

---

## 7. Functions, statuses and transitions

### 7.1 Lifecycle

```
not_submitted ──submit──▶ pending ──approve──▶ approved
                             │                   │
                             └─reject─▶ rejected │ GSTIN/legal-name change (resubmit)
                                          │      ▼
                                  resubmit└──▶ pending (new version); old approved → superseded
approved ──admin revoke(reason)──▶ revoked
```

"Not submitted" means that no row exists. The UI must show it only when the read actually succeeds and returns zero rows. A failed read shows an error, not a status.

### 7.2 `public.submit_buyer_gst_verification(p_payload jsonb) RETURNS uuid` (SECURITY DEFINER, `search_path = ''`)

1. `auth.uid()` must not be null, and `get_auth_role()` must be `'buyer'`. The company comes from `public.users`, never from the payload.
2. Normalize, then validate: format regex, **mod-36 checksum in PL/pgSQL** (ported from `isValidGstin`, with shared test vectors), required fields, pincode format, and state code consistent with `principal_state`. The latter uses a constant GST state-code map if `master_states` lacks one.
3. Verify that the certificate object exists in `storage.objects` with `bucket_id` = certificate bucket, name prefix `auth.uid()::text || '/'`, an allowed MIME type and size.
4. Recompute `edited_fields` and `gstin_edited` by comparing the final values with `ocr_values`. Never trust the client's flags.
5. `SELECT … FOR UPDATE` on the company's current rows. If a `pending` row exists, reject with "already under review", or replace it if D7 allows. If an `approved` row exists and the GSTIN or legal name changed, mark it `superseded` and write an event. All of this happens in the same transaction.
6. Insert the `pending` row and its event. Catch `unique_violation` and return "GSTIN already registered to another account" without revealing which account.

### 7.3 `public.review_buyer_gst_verification(p_id uuid, p_decision text, p_reason text)` (SECURITY DEFINER)

`is_admin()` is required. Lock the row `FOR UPDATE`; it must be `pending`. Reject requires a non-empty reason. Then set `reviewer_id = auth.uid()` and `reviewed_at = now()`, insert the event, insert a notification for every Buyer user of the company (idempotent key), and, if D5 says so, set `companies.is_verified` (the definer bypasses the revoked grant). `p_decision = 'revoke'` on an `approved` row follows the same path.

### 7.4 `public.buyer_company_can_post(p_company_id uuid) RETURNS boolean`

Returns true only if an `approved` row exists. In the trigger it is called with a lock (below).

### 7.5 Requirement gate: `BEFORE INSERT OR UPDATE OF status, company_id ON public.requirements`

- Applies when `NEW.status` is a posting status (`Open`, …). Whether `Draft` is allowed for unverified Buyers is D4. It also applies on UPDATE when the status moves from a non-posting to a posting status, or when `company_id` changes.
- Applies when the target company is a Buyer company (has a user with role `buyer`). Broker- and admin-originated inserts are covered by D3.
- Check: `PERFORM 1 FROM buyer_gst_verifications WHERE company_id = NEW.company_id AND status = 'approved' FOR SHARE;`. If no row is found, `RAISE EXCEPTION 'BUYER_NOT_VERIFIED' USING ERRCODE = '42501'`.
- **Concurrency:** revoke and supersede `UPDATE` the approved row, which needs a lock that conflicts with `FOR SHARE`. An in-flight insert therefore either commits before the revoke or, after waiting, re-evaluates under READ COMMITTED, finds `status <> 'approved'`, and fails. No requirement can commit after the revocation commits.
- The function is SECURITY DEFINER with `search_path = ''`, owned by `postgres`, and `REVOKE EXECUTE FROM PUBLIC`.

Optional, for clearer client errors: add `AND public.buyer_company_can_post(company_id)` to the Buyer branch of `requirements_insert_policy`. The trigger stays the authority.

---

## 8. Storage design

- New bucket `brokerbridge_buyer_gst_certificates`: `public = false`, `file_size_limit = 5 MB`, `allowed_mime_types = {image/jpeg, image/png}`, plus `application/pdf` only if D6 approves.
- Path: `{auth.uid()}/{verification-uuid}.{ext}`. The file is immutable; a replacement is a new object.
- INSERT: `bucket_id = … AND (storage.foldername(name))[1] = auth.uid()::text AND public.get_auth_role() = 'buyer'`.
- SELECT: `(storage.foldername(name))[1] = auth.uid()::text OR public.is_admin()`. Brokers, Sellers and other Buyers are denied.
- No UPDATE or DELETE policies for `authenticated`.
- Admin preview: an admin server action creates a **60-second signed URL** using the admin's own session client (passes SELECT via `is_admin()`). No service-role key is used and no public URL is generated.
- Retention: certificates of `superseded` or `rejected` versions are kept for N days, then purged by an admin job (D11).

---

## 9. Files likely to change

**Database (new migration plus rollback, under `supabase/proposed/` until approved)**
- `0053_buyer_gst_verification.sql` / `rollback_0053.sql`: tables, indexes, functions, trigger, bucket, storage policies, `companies` grant fix.

**RMBuyer** (`apps/rmbuyer_mobile`)
- `pubspec.yaml`: `image_picker`, `google_mlkit_text_recognition`, possibly `pdfx`. Android `minSdk` and the iOS camera/photo usage strings.
- `lib/features/profile/…`: new `gst_verification_repository.dart`, domain model, a "Verify with GST" card in `buyer_profile_screen.dart`, and upload/review/submit screens.
- Parser (shared package or port) plus `gstin_validator.dart`.
- `lib/features/requirements/data/requirements_repository.dart`: remove the hard-coded fallback (F6) and map `BUYER_NOT_VERIFIED`.
- `lib/features/requirements/presentation/post_requirement_screen.dart`: blocked state with an info icon.
- Tests under `test/unit`, `test/widgets` and `test/support` (fake repository).

**Web / backend** (`src/`, `app/(admin)`)
- New `app/(admin)/admin/_components/buyer-gst-verification-queue.tsx` and a tab in `MasterDataTabs.tsx`.
- New `src/server/actions/buyer-gst-verification-actions.ts`: list, signed URL, and approve/reject that **call the RPC via the user-scoped Supabase client**, so `auth.uid()` and `is_admin()` apply.
- `requirement-actions.ts`, `buyer-requirement-actions.ts`, `api/v1/requirements/sync/route.ts`, `broker-mandate-actions.ts`: map the trigger error. Add role checks in sync (F4).
- `src/server/db/schema.ts`: Drizzle definitions for the new tables (read-only use).
- F3 fix in `src/server/utils/buyer-auth.ts`, in a separate sprint.

**RMBroker:** only error mapping for P6, depending on D3.

---

## 10. Risks, privacy, rollout and rollback

**Risks**
- Fixing the `companies` grants (§6.5) can break existing Seller and Broker writes. Trace every `companies` update first.
- The trigger blocks the 2 active Buyer companies on day one unless D1 grandfathers them.
- OCR quality on phone photos is uneven (see the RMSeller device notes). The manual-correction path must be usable, and the Admin is the real control.
- A valid checksum or OCR result **does not prove** the certificate is genuine. Only Admin review provides that in this phase. No paid GST API is used.

**Privacy**
- Certificates contain names, addresses and the PAN embedded in the GSTIN. Use a private bucket, owner/admin-only access, 60-second signed URLs, and no logging of OCR text or certificate content (remove the `debugPrint`s of payloads).
- PAN is not stored separately. `ocr_values` is readable only by the owner and admins.

**Rollout order**
1. F3 fix (separate sprint).
2. The `companies` grant fix plus regression tests for RMSeller and RMBroker.
3. Tables, functions, bucket and admin queue, with the **trigger not yet created**.
4. RMBuyer UI and submission.
5. Apply the D1 policy to existing Buyers.
6. Create the trigger last.

Every step requires explicit production approval. There is no staging environment.

**Rollback:** `rollback_0053.sql` drops the trigger first, which immediately restores today's posting behaviour, then the functions, the storage policies, the bucket (only if empty; otherwise keep it and revoke the policies), and the tables (export first if they hold rows). It also restores the `companies` table-level UPDATE grant.

---

## 11. Test plan (for implementation; nothing executed against the live DB in this audit)

**GSTIN validation** (Dart and PL/pgSQL share one vector file): valid/invalid format, correct/incorrect check character, empty/whitespace/lower-case input, `O/0` and `I/1` confusion, state-code mismatch, duplicate GSTIN (second submission gets `23505` → friendly error), and two concurrent submissions of the same GSTIN where exactly one succeeds.

**OCR parser:** 3–4 **synthetic or owner-authorized** REG-06 images (no private real certificates without written authorization). Tests cover the full field set, missing fields stay null, low-confidence highlighting, a misread GSTIN corrected by the user being flagged, and `edited_fields` computed correctly.

**Authorization / RLS** (run only against a disposable local Supabase via `supabase start`, never production; see the memory note on live-writing tests):
- Unverified, pending and rejected Buyer inserts are rejected through P1 **and** through the postgres-role paths P2–P5.
- An approved Buyer insert succeeds.
- `Draft → Open` UPDATE by an unverified Buyer is rejected.
- A Buyer cannot UPDATE `companies.is_verified/status/trust_score` and cannot INSERT/UPDATE verification or event rows.
- A Buyer cannot call the review RPC.
- Brokers, Sellers and other Buyers cannot read a certificate object or verification rows.
- The admin signed URL works and expires.
- An upload outside `{uid}/` is rejected.

**Lifecycle:** approve, reject with a required reason, resubmit (new version), a GSTIN change on an approved company supersedes the approval atomically and blocks posting, revoke during a concurrent insert (insert fails or commits strictly before), exactly one notification per decision (idempotency), and existing requirements behave according to D2.

**Regression:** RMSeller profile/bank save, RMBroker CRM company edit, Broker requirement creation (according to D3), and the web admin Company Approvals tab.

---

## 12. Decisions requiring owner approval

| ID | Decision |
|---|---|
| **D1** | Existing Buyers (10 accounts; 2 companies with 23 active requirements; 0 with a GSTIN): block until verified, give a time-boxed grace period, or grandfather? |
| **D2** | When approval is superseded or revoked, what happens to the company's existing open requirements: keep, pause, or cancel? |
| **D3** | Do Broker- or Admin-created requirements for an unverified Buyer company bypass the gate? (Affects P5, P6 and the trigger condition.) |
| **D4** | Can unverified Buyers save `Draft` requirements? |
| **D5** | Should approval also set the public `companies.is_verified` badge, and should rejection or revocation clear it? |
| **D6** | Accept PDF certificates in phase 1, or images only? |
| **D7** | May a Buyer replace a `pending` submission before review, or must they wait? |
| **D8** | Is a GSTIN shared with a *Seller* company a conflict, or only one shared with another Buyer? |
| **D9** | Share the GST parser as a common Dart package, or copy it into RMBuyer? |
| **D10** | Should Buyers see the reviewer's identity, or only the decision and reason? |
| **D11** | Retention period for rejected or superseded certificates and `ocr_values`. |
| **D12** | Approve fixing F1 (the `companies` column grants) and F3 (the role escalation in `verifyBuyerSession`) as prerequisite sprints. |
| **D13** | Remove or relocate `test-booking-action.ts` (P7) out of production server actions. |

---

## 13. Confirmation

- No application code, migrations, database objects, policies, grants, triggers, functions, storage buckets, configuration or production data were changed.
- Live inspection ran inside `BEGIN READ ONLY`, from a script kept in the session scratchpad outside the repository. Only schema metadata and aggregate counts were read. No personal records, secrets or certificate contents appear in this report.
- No tests were run. Nothing was committed, pushed or deployed.
- The only file added to the repository is this report. All pre-existing uncommitted work (RMSeller profile/OCR changes and untracked files) was left untouched.
