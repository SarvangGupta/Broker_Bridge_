# RMBUYER-GST-BACKEND-PLAN-01 — Secure Backend Plan for Buyer GST Verification

**Date:** 2026-10-29 · **Type:** read-only audit and plan. Nothing was implemented, applied or written.

## Status: **PLAN READY**

The design below is complete enough to implement.

**Implementation is gated** on the owner decisions in §9, especially B1 (a non-production Supabase project) and B2 (the trust-field rule), because the only Supabase project is production.

---

## 1. Current-state findings (evidence)

Sources:
- Live metadata re-checked read-only on 2026-10-29 (`BEGIN READ ONLY`; metadata only).
- `docs/RMBUYER-GST-VERIFICATION-01-AUDIT-REPORT.md` (same day).
- `docs/RB-SEC-PRIV-02-AUDIT-REPORT.md`.
- The client code paths cited below.

### 1.1 How Buyers can modify `is_verified`, `status`, `trust_score`

Three facts combine:

1. **Grant.** `authenticated` holds table-wide `INSERT, UPDATE, DELETE, TRUNCATE, SELECT, REFERENCES, TRIGGER` on `public.companies`. Column privileges confirm UPDATE on every column, including `is_verified`, `status`, `trust_score`, `bank_is_verified`, `bank_verification_status`, `created_by` and `id`.
2. **Policy.** `"Users can update their own company"` is `FOR UPDATE TO authenticated USING/CHECK id IN (SELECT company_id FROM users WHERE id = auth.uid())`. It has no column limit.
3. **No guard.** There are no triggers on `companies`, and no function references these columns.

**Result:** any Buyer (or Seller) can `PATCH /rest/v1/companies?id=eq.<own company>` with `{"is_verified": true, "trust_score": 100, "status": true}` using only their own JWT. The RMBuyer app never does this. Its `BuyerProfileRepository` writes only `users.name/mobile`. But the API allows it.

### 1.2 Other fields with the same exposure

| Column | Risk |
|---|---|
| `bank_is_verified`, `bank_verification_status` | Self-settable "verified bank" flag |
| `gst`, `name` | Self-editable. Acceptable today, but they must lock once a GST verification is pending or approved. |
| `created_by` | Feeds the CRM SELECT/UPDATE policies (`created_by = auth.uid()`) |
| `id` | UPDATE is granted. FKs would mostly fail, but it should not be writable. |
| `crm_companies_insert_policy` | A Broker can INSERT a company with `is_verified = true` and any `trust_score` (RB-SEC-PRIV-02 T4) |
| `TRUNCATE` / `DELETE` grants to `authenticated` | DELETE is blocked by RLS (no policy). TRUNCATE ignores RLS, but PostgREST cannot issue it. Remove as hardening. |

### 1.3 Legitimate writers (must keep working)

| Writer | Role used | Columns written | Evidence |
|---|---|---|---|
| RMSeller profile save | `authenticated` (own company) | `name, gst, state_id, district_id` | `rmseller_mobile/.../seller_profile_repository.dart:818-823` |
| RMBroker own profile | `authenticated` (own company) | `name` | `rmbroker_mobile/.../profile/data/profile_repository.dart:214` |
| RMBroker directory: create counterparty | `authenticated` (broker INSERT) | `name, district_id, state_id, status=true, is_verified=false, trust_score=100` | `rmbroker_mobile/.../directory/data/directory_repository.dart:195-203` |
| RMBroker directory: edit counterparty | `authenticated` (CRM policy) | `name, district_id, state_id`, **`status`** | `directory_repository.dart:931-936` |
| Web Admin Company Approvals | **`postgres`** via Drizzle (`DATABASE_URL`) | `status, is_verified` and `users.status` | `src/server/actions/company-actions.ts:268-312` |
| Web `createCompanyProfile` | `postgres` | `name, gst, state/district/business type` | `company-actions.ts:10+` |
| RMBuyer | — | none on `companies` | `buyer_profile_repository.dart` (`editableColumns = {name, mobile}`) |

**Consequence for the fix:** RB-SEC-PRIV-02's preferred P1 (revoke table UPDATE/INSERT, then grant back a column list) would **break RMBroker**. The directory edit writes `status`, and the directory insert sends `is_verified`/`trust_score` explicitly, which fails without INSERT privilege even when the values equal the defaults.

The smallest safe change is therefore a **trigger guard limited to API sessions** (§2). The web admin and server actions run as `postgres` and are unaffected.

### 1.4 GST backend

There is no verification table or function, and no Buyer certificate bucket.

Buckets: `brokerbridge_documents`, `brokerbridge_lab_evidence`, `brokerbridge_seller_invoices`. All are private, with no size or MIME limits, and their INSERT policies check only `auth.uid() IS NOT NULL`.

Only one Supabase project exists, and it is production.

### 1.5 Existing conventions reused

- **Role helpers:** `public.get_auth_role()`, `is_admin()`, `is_broker()`. All are SECURITY DEFINER and read trusted `raw_app_meta_data`.
- **Definer pattern:** `notify_requirement_brokers` (SECURITY DEFINER, `auth.uid()`, idempotency key).
- **Self-protect trigger:** `prevent_self_company_change` (`SECURITY DEFINER`, `search_path = ''`, `ERRCODE 42501`).
- **Storage path policies** use `regexp_split_to_array(name,'/')`. This plan uses `storage.foldername(name)` instead.
- **Migrations:** numbered SQL in `supabase/proposed/` with a paired `rollback_NNNN.sql`. The next free number is **0053**.

---

## 2. Trust-field protection (prerequisite migration 0053)

**Approach.** Add a `BEFORE INSERT OR UPDATE` trigger on `public.companies` that enforces rules only when `current_user = 'authenticated'`, which is the PostgREST role for signed-in users. Admins are allowed through when `public.is_admin()`. Direct `postgres` sessions (web admin and server actions) are not affected.

```sql
-- 0053_protect_company_trust_fields.sql (outline)
CREATE OR REPLACE FUNCTION public.protect_company_trust_fields()
-- SECURITY INVOKER on purpose: under SECURITY DEFINER, current_user would be the
-- owner (postgres) and the guard below would never fire.
RETURNS trigger LANGUAGE plpgsql SECURITY INVOKER SET search_path = '' AS $$
BEGIN
  IF current_user <> 'authenticated' OR public.is_admin() THEN
    RETURN NEW;                                   -- server/admin paths unchanged
  END IF;
  IF TG_OP = 'INSERT' THEN                        -- broker creates: force safe defaults
    NEW.is_verified := false;  NEW.trust_score := 100;
    NEW.bank_is_verified := false;  NEW.bank_verification_status := 'unverified';
    RETURN NEW;
  END IF;
  IF NEW.is_verified IS DISTINCT FROM OLD.is_verified
     OR NEW.trust_score IS DISTINCT FROM OLD.trust_score
     OR NEW.bank_is_verified IS DISTINCT FROM OLD.bank_is_verified
     OR NEW.bank_verification_status IS DISTINCT FROM OLD.bank_verification_status
     OR NEW.created_by IS DISTINCT FROM OLD.created_by
     OR NEW.id IS DISTINCT FROM OLD.id THEN
    RAISE EXCEPTION 'protected company field' USING ERRCODE = '42501';
  END IF;
  -- status: only a broker editing a CRM counterparty (decision B3), never the company's own members
  IF NEW.status IS DISTINCT FROM OLD.status AND NOT public.is_broker() THEN
    RAISE EXCEPTION 'protected company field' USING ERRCODE = '42501';
  END IF;
  -- GST identity locks while a Buyer verification is pending/approved (added in 0054)
  RETURN NEW;
END $$;
-- Trigger functions run with the caller's rights; is_admin()/is_broker() are already
-- executable by authenticated. No direct EXECUTE is needed on the trigger function itself.
REVOKE ALL ON FUNCTION public.protect_company_trust_fields() FROM PUBLIC, anon;
CREATE TRIGGER trg_protect_company_trust_fields
  BEFORE INSERT OR UPDATE ON public.companies
  FOR EACH ROW EXECUTE FUNCTION public.protect_company_trust_fields();
REVOKE TRUNCATE, DELETE ON public.companies FROM authenticated;   -- hardening (no policy uses them)
```

Notes:
- **Test #1 in §7 must prove the guard fires for a real `authenticated` session.** A definer/invoker mistake fails open silently.
- RMBroker's directory insert keeps working: the explicit `false`/`100` it sends are simply re-set to the same values.
- The trigger does **not** clear existing values. The 2 Buyer companies with `is_verified = true` keep them (decision B6).
- The existing `"Tier 0 admin…"` policy reads `public.users.role`, and `is_admin()` reads app metadata. `trg_sync_privileged_role` keeps the two in sync, so either works.
- Not covered here (tracked separately): the `verifyBuyerSession` role-from-`user_metadata` escalation (audit F3). It is fixed in web code, not in this migration.

---

## 3. Data model (migration 0054)

### 3.1 `public.buyer_gst_verifications`: one row per submission

| Column | Type | Notes |
|---|---|---|
| `id` | `uuid PK DEFAULT gen_random_uuid()` | |
| `company_id` | `uuid NOT NULL REFERENCES public.companies(id)` | Server-derived |
| `submitted_by` | `uuid NOT NULL REFERENCES public.users(id)` | `auth.uid()` |
| `status` | `text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','approved','rejected','superseded'))` | |
| `gstin` | `text NOT NULL CHECK (gstin ~ '^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z][1-9A-Z]Z[0-9A-Z]$')` | Checksum is verified in the RPC |
| `legal_name` | `text NOT NULL` | |
| `trade_name`, `constitution`, `registration_type` | `text` | Null when absent, never a placeholder |
| `principal_address` | `text NOT NULL` | |
| `pin_code` | `text NOT NULL CHECK (pin_code ~ '^[1-9][0-9]{5}$')` | |
| `registration_date`, `validity_from`, `issue_date` | `date` | Parsed from `dd/mm/yyyy` |
| `validity_to` | `text` | A date or `'Not Applicable'` |
| `ocr_values` | `jsonb NOT NULL DEFAULT '{}'` | Raw OCR suggestions (`GstSubmissionDraft.ocr`) |
| `edited_fields` | `text[] NOT NULL DEFAULT '{}'` | **Recomputed by the server** |
| `certificate_path` | `text NOT NULL` | Object name inside the certificate bucket |
| `submitted_at` | `timestamptz NOT NULL DEFAULT now()` | |
| `reviewed_by` | `uuid REFERENCES public.users(id)` | Set only by the review RPC |
| `reviewed_at` | `timestamptz` | |
| `rejection_reason` | `text` | `CHECK (status <> 'rejected' OR length(btrim(rejection_reason)) > 0)` |

**Not stored:**
- PAN: it is `substr(gstin, 3, 10)`.
- State: derived from the GSTIN state code.
- District, jurisdictional office: not needed for verification.

`companies.gst` and `companies.name` stay the display fields. Approval copies `gstin` into `companies.gst`, and copies legal/trade name into `companies.name` if decision B5 allows.

**Constraints and indexes**
- `CREATE UNIQUE INDEX ON buyer_gst_verifications (company_id) WHERE status = 'pending';`: one active submission per company.
- `CREATE UNIQUE INDEX ON buyer_gst_verifications (company_id) WHERE status = 'approved';`
- `CREATE UNIQUE INDEX ON buyer_gst_verifications (gstin) WHERE status IN ('pending','approved');`: a GSTIN can be held by only one company. This makes concurrent duplicates fail with `23505`.
- `CREATE INDEX ON buyer_gst_verifications (status, submitted_at);`: the admin queue.
- `CHECK ((status IN ('approved','rejected')) = (reviewed_by IS NOT NULL AND reviewed_at IS NOT NULL))`

### 3.2 `public.buyer_gst_verification_events`: append-only history

Columns:
- `id uuid PK`
- `verification_id uuid NOT NULL REFERENCES buyer_gst_verifications(id)`
- `company_id uuid NOT NULL`
- `from_status text`
- `to_status text NOT NULL`
- `actor_id uuid NOT NULL`
- `reason text`
- `created_at timestamptz NOT NULL DEFAULT now()`

Index on `(company_id, created_at)`.

This is needed because the verification row is updated in place on review, and the sprint requires an auditable trail. The existing `seller_profile_audit_logs` is unsuitable: it is seller-scoped, and Sellers can append to it.

### 3.3 Status transitions (enforced only in the RPCs)

| From → To | Who |
|---|---|
| (none) → `pending` | Buyer, via `submit` |
| `pending` → `approved` / `rejected` | Admin, via `review` |
| `rejected` → (new row) `pending` | Buyer resubmits; the old row stays `rejected` |
| `approved` → `superseded`, plus a new `pending` row | Buyer resubmits a changed GSTIN or legal name (B4) |
| `pending` → `superseded`, plus a new `pending` row | Only if B7 allows replacing before review |

### 3.4 Grants, RLS and retention

- **Both tables:** `REVOKE ALL FROM anon, authenticated`, then `GRANT SELECT TO authenticated`. RLS is on.
  - SELECT on the verifications table: `company_id = (SELECT company_id FROM public.users WHERE id = auth.uid()) OR public.is_admin()`.
  - The events table uses the same rule.
- **No INSERT, UPDATE or DELETE** for any API role. All writes go through definer functions.
- **Retention:**
  - Keep all rows; they are small.
  - Certificates of `rejected`/`superseded` rows become purge-eligible after N days (B8). The purge is an admin job that deletes the storage object and nulls nothing (the path remains as history).

---

## 4. Server function contracts (migration 0054)

All functions are `SECURITY DEFINER`, use `SET search_path = ''`, `REVOKE ALL FROM PUBLIC, anon` and `GRANT EXECUTE TO authenticated`. Errors use `ERRCODE 42501` (forbidden), `23505` (duplicate) and `22023` (invalid input). The client maps these codes; it never parses message text.

### 4.1 `public.submit_buyer_gst_verification(p_submission jsonb, p_certificate_path text) RETURNS public.buyer_gst_verifications`

**Input shape.** `p_submission` is exactly `GstSubmissionDraft.toPayload()`, already in the app:

```json
{ "submitted": {"gstin": "...", "legalName": "...", ...}, "ocr": {...}, "edited_fields": [...] }
```

**Steps**
1. `v_uid := auth.uid()` must not be null, and `public.get_auth_role()` must be `'buyer'`.
2. `v_company := (SELECT company_id FROM public.users WHERE id = v_uid AND status)`. If it is null, fail with "no company". **No `company_id` is read from the input.**
3. Normalize and validate:
   - required fields
   - GSTIN format and **mod-36 check character** (a PL/pgSQL port, tested against the same vectors as the Dart `GstinRules`)
   - PIN format
   - GSTIN state vs the state named in the address
   - dates parse as `dd/mm/yyyy`
4. **Certificate ownership:**
   - `p_certificate_path` must match `^<v_uid>/[0-9a-f-]{36}\.(jpg|png)$`.
   - The object must exist: `EXISTS (SELECT 1 FROM storage.objects WHERE bucket_id = 'brokerbridge_buyer_gst_certificates' AND name = p_certificate_path AND owner = v_uid)`.
   - The path must not be referenced by any other verification row.
5. Lock the company's rows with `SELECT … FOR UPDATE`, then:
   - **Pending row exists:** reject with "already under review" (or supersede it, per B7).
   - **Approved row exists with the same GSTIN and legal name:** reject with "already verified".
   - **Approved row exists with a different GSTIN or legal name:** mark it `superseded`, insert an event, and set `companies.is_verified = false` (B4).
6. Recompute `edited_fields` by comparing the submitted values with the `ocr` values. The client's list is ignored.
7. Insert the row with `status = 'pending'`. `reviewed_*` and `rejection_reason` stay null, whatever the input says.
8. Insert an event (`null → pending`) and return the row.

**Client never sets:** status, reviewer, timestamps, `company_id`, `is_verified` or `trust_score`.

### 4.2 `public.review_buyer_gst_verification(p_id uuid, p_decision text, p_reason text DEFAULT NULL) RETURNS public.buyer_gst_verifications`

1. Require `public.is_admin()`, with `v_admin := auth.uid()`.
2. `p_decision` must be in `('approve','reject')`. A reject needs a non-empty `p_reason`.
3. `SELECT … FOR UPDATE` the row; its status must be `pending`.
4. Set `status`, `reviewed_by = v_admin`, `reviewed_at = now()` and `rejection_reason`. Insert an event.
5. On approve, write `companies.is_verified = true` and `companies.gst = gstin`, and `name` only per B5. The RPC is SECURITY DEFINER (owner `postgres`), so inside it `current_user` is `postgres`, and the invoker-rights 0053 trigger lets the write through. The RPC itself has already checked `is_admin()`.
6. Insert an in-app notification for the company's Buyer users, using the existing `notifications` pattern:
   - idempotency key `gstv-<id>-<decision>`
   - `action_url` `/gst-verification`

   The `notifications` table has no client INSERT grant, so definer-only insertion is consistent with how the table is used today.

### 4.3 Status read: no new function

The client reads `buyer_gst_verifications` directly through the SELECT policy, newest first, `limit 1`, alongside `companies.is_verified`. The display rules:

| Latest row | Display |
|---|---|
| `pending` | Submitted, awaiting verification |
| `rejected` | The stored reason, plus resubmit |
| `approved` and `is_verified` | Verified |

### 4.4 Web Admin integration

The existing **Company Approvals** tab and `approveCompanyAction`/`rejectCompanyAction` stay as they are, so current behaviour does not change.

Add a **Buyer GST Verifications** tab (`app/(admin)/admin/_components/buyer-gst-verification-queue.tsx`). It lists pending rows (via the admin's own session) and shows:
- the certificate, through a 60-second signed URL created with the admin's session
- OCR values against submitted values, with edited fields highlighted
- the stored company name and GST

Approve and Reject call `review_buyer_gst_verification` through the **user-scoped Supabase server client** (`@/lib/supabase/server`), **not Drizzle**. That way `auth.uid()` and `is_admin()` apply, and the event records the real reviewer.

Decision B9 covers whether the legacy Approve button on a company should also be blocked for Buyer companies that have a pending GST row.

---

## 5. Certificate storage (migration 0054)

| Setting | Value |
|---|---|
| Bucket | `brokerbridge_buyer_gst_certificates`, `public = false`, `file_size_limit = 5242880` (5 MB), `allowed_mime_types = '{image/jpeg,image/png}'` (PDF excluded; B10) |
| Object path | `<auth.uid()>/<uuid>.jpg` (the client generates the UUID) |
| INSERT | `bucket_id = '…' AND (storage.foldername(name))[1] = auth.uid()::text AND public.get_auth_role() = 'buyer'` |
| SELECT | `bucket_id = '…' AND ((storage.foldername(name))[1] = auth.uid()::text OR public.is_admin())` |
| UPDATE / DELETE | **No policy** for any API role. Objects are immutable, and Replace uploads a new object. Deleting a never-submitted object is left to a purge job (B8). |
| Admin access | SELECT through `is_admin()`. Previews use `createSignedUrl(path, 60)` from the admin's session. No service-role key, and never `getPublicUrl`. |
| Reference handling | The client sends only the object path. The RPC re-checks prefix, existence, owner and that the path isn't reused. URLs are never stored. |

Brokers, Sellers and other Buyers fail both policies, so they cannot read or overwrite another company's certificate. The existing three buckets are unchanged.

---

## 6. Test environment

**Tier 1 — offline. Can start now and touches nothing remote.**
- Extend `supabase/proposed/0052_tools/staging_replay.mjs`, the PGlite replay of `supabase/migrations` with stubs for `auth`/`storage`, to apply 0053 and 0054.
- Run the SQL test matrix (§7) with `SET ROLE authenticated` plus `request.jwt.claim.sub`.
- This proves the trigger, RLS, RPC logic, constraints and concurrency of the unique indexes.
- It **cannot** prove real Storage, PostgREST or Auth behaviour.

**Tier 2 — a separate Supabase project (needs B1).** Minimum steps:
1. Create a free-tier project, e.g. `brokerbridge-test`, in a different organization or one clearly named.
2. Load the schema:
   - **Preferred:** a schema-only `pg_dump --schema-only --schema=public` from production. This is a read, but production access still needs owner approval.
   - **Alternative:** replay `supabase/migrations/*` plus the live-drift patch already recorded by the replay tool.
3. Recreate the buckets and storage policies (the `manual_*.sql` files).
4. Apply 0053 and 0054.
5. Create test accounts through the Auth admin UI: Buyer A and Buyer B (different companies), a Broker, a Seller and an Admin. Set `raw_app_meta_data.role` for each. Seed only synthetic companies and the synthetic GST certificates from the tests. **No production data or real certificates.**
6. Point RMBuyer and the web app at it with a separate `.env.test` / `--dart-define` (URL plus anon key only).
7. The RMBuyer test guard (`test/flutter_test_config.dart`) already rejects the production ref. Add the test project's ref to an opt-in allow-list.

**Tier 3 — production rollout**, only after Tier 2 passes (§8).

---

## 7. Test matrix (Tier 1 and Tier 2)

| # | Actor | Action | Expected |
|---|---|---|---|
| 1 | Buyer | PATCH own company `is_verified`, `trust_score`, `status`, `bank_is_verified`, `created_by` | 42501, row unchanged |
| 2 | Buyer / Seller | PATCH own company `name`, `state_id`, `district_id` (and `gst` with no pending/approved row) | Succeeds |
| 3 | Broker | Directory insert with `is_verified = true`, `trust_score = 50` | Row stored with false / 100 |
| 4 | Broker | Directory edit of a CRM counterparty's `status` | Succeeds, per B3 |
| 5 | Web admin (postgres) | `approveCompanyAction` / `rejectCompanyAction` | Unchanged behaviour |
| 6 | Buyer A | Upload to `A/…` | OK. Upload to `B/…` is denied. Upload as a Seller or Broker is denied. Upload of a PDF or a file over 5 MB is rejected. |
| 7 | Buyer B, Broker, Seller | Read `A/…` object | Denied. Admin can read it, and a signed URL expires after 60 s. |
| 8 | Buyer A | `submit` with a valid draft and own path | Row `pending`, event written, `edited_fields` recomputed |
| 9 | Buyer A | `submit` with a forged `status`, `reviewed_by` or `company_id` in the JSON | Ignored. The row is still `pending` and tied to A's company. |
| 10 | Buyer A | `submit` with B's path, a missing object or a reused path | 42501 / 22023 |
| 11 | Buyer A | `submit` twice; then two concurrent submits | The second fails with "already under review"; the concurrent pair yields exactly 1 row |
| 12 | Buyer B | `submit` with A's GSTIN while A's is pending or approved | 23505, without revealing which company |
| 13 | Buyer A | Bad checksum, state mismatch, missing required field | 22023 |
| 14 | Buyer / Broker | `review` | 42501 |
| 15 | Admin | Reject with no reason | 22023. With a reason: `rejected`, event and notification. |
| 16 | Admin | Approve | `approved`, `companies.is_verified = true`, `gst` set, event, one notification even if retried |
| 17 | Buyer A | Read own verification rows / events; Buyer B reads A's | Own rows only / none |
| 18 | Buyer A | Resubmit after rejection | New `pending` row; the old one stays `rejected` |
| 19 | Buyer A | Approved, then changes GSTIN through submit | Old row `superseded`, `is_verified = false`, new `pending` (B4) |
| 20 | RMBuyer app | Submit → kill app → reopen | Shows Pending. Approve on the server → refresh shows Verified. Server error or timeout → error, no success. |

---

## 8. Compatibility, rollout and rollback

**Compatibility**

| Area | Effect |
|---|---|
| Ordinary profile edits (§1.3) | Unaffected. Name, state, district and GST stay writable; GST locks only while a verification is pending or approved. |
| Web admin approvals | Unaffected (`postgres` role). |
| Existing Buyer companies | Keep their current flags (B6). |
| Current RMBuyer GST screen | Keeps working. It shows "submission not available" until the client sprint flips `submissionAvailable`. |
| Posting gate | **No** requirement-posting gate in this work. |

**Rollout order** (each production step needs explicit approval)
1. Tier 1 offline tests pass.
2. Tier 2 project passes the full §7 matrix.
3. Production: apply 0053, then run smoke tests 1–5 with the existing test accounts, read-only where possible.
4. Production: apply 0054 (tables, RPCs, bucket, policies) and verify grants and policies read-only.
5. Ship the RMBuyer client change (upload, RPC, status read) and the web admin tab.

**Rollback**
- `rollback_0053.sql`: `DROP TRIGGER trg_protect_company_trust_fields`; drop the function; re-grant `TRUNCATE, DELETE` only if required for strict restoration (not recommended).
- `rollback_0054.sql`:
  - Drop the RPCs and the storage policies.
  - Drop the bucket only if it is empty; otherwise keep it with policies removed and export first.
  - Drop the tables after a `COPY` export.
  - Approved flags already written to `companies` remain. Revert them manually from the events table if required.

Both rollbacks are independent, and the client keeps working: its submit path detects a missing RPC (`PGRST202`) and shows "not available".

---

## 9. Decisions requiring approval before implementation

| ID | Decision |
|---|---|
| **B1** | Create a separate non-production Supabase project, and allow a schema-only `pg_dump` of production to seed it. Without this, only Tier 1 offline testing is possible. **This is the main blocker.** |
| **B2** | Approve the trigger-based trust-field guard (0053) instead of the column-grant split proposed in RB-SEC-PRIV-02 P1, which would break RMBroker. |
| **B3** | Should brokers keep changing a counterparty's `companies.status` from the RMBroker directory? The plan allows brokers and blocks a company's own members. |
| **B4** | When an approved Buyer changes GSTIN or legal name, does the old approval end immediately (`is_verified = false`) until re-review? |
| **B5** | On approval, should `companies.name` be overwritten with the trade name (or legal name), or left as the Buyer typed it? |
| **B6** | What happens to the 2 Buyer companies that already have `is_verified = true` with no review record: keep, reset, or ask them to submit? |
| **B7** | May a Buyer replace a pending submission before review? |
| **B8** | Retention period for rejected or superseded certificates, and for orphan uploads. |
| **B9** | Should the legacy Company Approvals "Approve" be blocked for Buyer companies with a pending GST row, or stay independent? |
| **B10** | Keep PDF certificates out (images only) for now? |
| **B11** | Should a GSTIN already used by a Seller company count as a duplicate for a Buyer? |
| **B12** | Approve the separate fix for audit F3 (the `verifyBuyerSession` role taken from `user_metadata`) in the same release. |

---

## 10. Files and resources that would change (implementation sprint)

**Database:** new files in `supabase/proposed/`
- `0053_protect_company_trust_fields.sql`, `rollback_0053.sql`
- `0054_buyer_gst_verification.sql` (two tables, indexes, RLS, two RPCs, bucket and storage policies), `rollback_0054.sql`
- `supabase/tests/0053_0054_security_check.sql` and `0052_tools/staging_replay.mjs`: Tier 1 tests

**RMBuyer**
- `lib/features/profile/data/gst_verification_repository.dart`: upload, RPC call, status-row read; `submissionAvailable` becomes true
- `lib/features/profile/presentation/gst_verification_screen.dart`: pending/rejected states, success only on RPC confirmation, error and timeout states
- `lib/features/profile/domain/gst_certificate_data.dart`: a status model for verification rows
- Tests under `test/unit` and `test/widgets`
- No change to `BuyerProfileRepository` write paths

**Web**
- `app/(admin)/admin/_components/buyer-gst-verification-queue.tsx` (new)
- `MasterDataTabs.tsx`: new tab
- `src/server/actions/buyer-gst-verification-actions.ts` (new; user-scoped Supabase client)
- `src/server/db/schema.ts`: read-only Drizzle definitions for the new tables
- `src/server/utils/buyer-auth.ts`: F3 fix, only if B12 is approved

**Unchanged:** RMSeller, RMBroker, existing buckets, existing policies other than adding the 0053 trigger, and the requirement-posting rules.

---

## 11. Confirmation

- This sprint was read-only. No application code, schema, grants, RLS, storage, Edge Functions or data were changed.
- Nothing was committed, pushed or deployed. Uncommitted work was preserved.
- This report contains no secrets or certificate contents.
