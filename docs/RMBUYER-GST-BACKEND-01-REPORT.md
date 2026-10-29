# RMBUYER-GST-BACKEND-01 — Secure GST Verification Backend

**Date:** 2026-10-29 · **Branch:** `feature/broker-nilesh` (uncommitted; nothing committed, pushed or deployed by this session)

## Final status: **BLOCKED**

There are two blockers:

1. **No separate Supabase test project could be created.** This machine has no Supabase CLI, no access token and no Docker; the only credentials point at production. Phase B (real PostgREST, Auth, Storage and signed-URL tests) and the end-to-end device run (§13 steps 6–14 against a real backend) were therefore **not** performed.
2. **⚠ Production incident.** A first draft of migration 0054 is now present in **production**, applied at 2026-10-29 06:53:24 UTC. This sprint did not authorize that, and the evidence in §1 indicates it did not come through this session's database connection. It needs an owner decision before anything else (§1.4).

**Completed and verified offline:**
- Migrations 0053 and 0054 with their rollbacks: **85/85** security tests in PGlite against a schema-only extract of production.
- The `verifyBuyerSession` / provisioning / middleware role-escalation fix: **8/8** tests.
- Admin "Buyer GST Verifications" tab.
- RMBuyer secure submission client, kept **off by default and refused for production**.
- `flutter analyze` clean; **410 passed, 4 skipped, 1 failed** (the known chat date test, root cause below); debug APK builds.

---

## 1. ⚠ Production incident — 0054 (first draft) present in production

### 1.1 What is in production (read-only verification, metadata and counts only)

| Object | State |
|---|---|
| `buyer_gst_verifications`, `buyer_gst_verification_events` | **Present**, 0 rows each |
| 11 functions (`gstin_is_valid`, `gst_state_name`, `gst_address_state_consistent`, `gst_parse_date`, `bgv_enforce_transition`, `bgve_append_only`, `company_has_active_gst_verification`, `lock_company_gst_under_review`, `require_gst_review_for_buyer_verification`, `submit_buyer_gst_verification`, `review_buyer_gst_verification`) | **Present** |
| Triggers on `companies`: `trg_lock_company_gst_under_review`, `trg_require_gst_review_for_buyer_verification` | **Present** |
| Bucket `brokerbridge_buyer_gst_certificates` (private, 5 MB, JPG/PNG) | **Present**, `created_at` **2026-10-29 06:53:24.452 UTC**, 0 objects |
| Storage policies "Buyers upload own GST certificate", "Owner or admin reads GST certificate" | **Present** |
| **0053** (`trg_protect_company_trust_fields`, DELETE/TRUNCATE revoke) | **Not present.** The Buyer self-verify hole is still open. |
| Version | `review_buyer_gst_verification` lacks the later `coalesce(public.is_admin(), false)` fix, so this is the **first draft** of `0054_buyer_gst_verification.sql` |
| `supabase_migrations.schema_migrations` | Table does not exist (not applied through the Supabase CLI) |
| Company flags | 13 of 18 companies `is_verified = true` (counts only; legacy flags untouched) |

### 1.2 How it was applied (evidence)

- `pg_stat_statements` shows every 0054 statement executed **once, as a separate top-level statement**, by role `postgres`. The two `storage.objects` policies were created by **`supabase_admin`**.
- This session's `DATABASE_URL` connects as `postgres` (verified) and cannot act as `supabase_admin`. Executing as `supabase_admin` is characteristic of a Supabase platform path (Dashboard, Management API or an MCP/IDE integration), not this session's connection.
- This session's tools that touched the database:
  - `extract_schema_ro.mjs`: `BEGIN READ ONLY`, verified `transaction_read_only = on`, SELECT only.
  - The read-only check scripts.
  - `gst_backend_offline_test.mjs`: **in-memory PGlite only**; it never opens a Postgres connection.
- **Unexplained coincidence, reported plainly:** the second schema extract started at 06:53:21.6 UTC and the bucket was created 3 seconds later. The statement-level evidence above does not fit this session's connection, but I cannot fully exclude a link without the Supabase platform logs.
- No other Claude session was running (`ListAgents`). This workspace is also an Antigravity (Gemini) IDE workspace, and its agents are not visible to that check.

**Recommended check:** Supabase Dashboard → Logs (Postgres and API/Management audit) around 06:50–06:55 UTC, to identify the client that ran the statements.

### 1.3 Production impact today

| Area | Effect |
|---|---|
| **Legacy web Company Approvals → Approve on a Buyer company** | **Now fails.** The production web build still sets `is_verified = true`, and the new trigger blocks that without an approved GST review. Seller and Broker companies are unaffected. |
| Submit / review RPCs, certificate upload | Callable in production through PostgREST by any signed-in Buyer (submit) or admin (review). The production apps don't call them: RMBuyer's backend flag is off and refused for the production ref. |
| First-draft `review_buyer_gst_verification` | Fails open only for a still-valid JWT of a **deleted** account (`is_admin()` returns NULL), fixed in the current file. This is narrow but real. |
| 0053 not applied | The Buyer and Seller self-verify gap (`is_verified`, `trust_score`, `status`) remains exactly as before |
| Data | No rows, objects or flags changed. Legacy companies untouched. |

### 1.4 Owner decision required (this session made no production change)

- **Option A (recommended):** roll back now with `supabase/proposed/rollback_0054.sql`. The bucket and tables are empty, so this restores the pre-incident state exactly, and the legacy Approve flow works again.
- **Option B:** keep it, then deploy the reviewed current 0054 (`CREATE OR REPLACE` the two functions changed since the first draft), apply 0053, and update the web approval action, all in one approved window.

---

## 2. Files changed (this sprint)

At the start the working tree had 68 entries; at the end it has 84. All 16 new entries are below. No reset, stash, clean or overwrite of others' work.

| Area | File | Change |
|---|---|---|
| DB | `supabase/proposed/0053_protect_company_trust_fields.sql`, `rollback_0053.sql` | **New**: invoker-rights trust-field trigger; revoke DELETE/TRUNCATE |
| DB | `supabase/proposed/0054_buyer_gst_verification.sql`, `rollback_0054.sql` | **New**: tables, history, guards, RPCs, bucket and policies |
| DB tests | `supabase/proposed/0054_tools/gst_backend_offline_test.mjs` | **New**: 85-case offline security suite |
| Web | `src/server/utils/trusted-role.ts`, `src/server/utils/__tests__/trusted-role.test.mjs` | **New**: trusted role helper plus escalation tests |
| Web | `src/server/utils/buyer-auth.ts` | Provisioning role from `provisionableRole`; Buyer-only check |
| Web | `src/server/actions/company-actions.ts` | Both auto-provisioning sites fixed; legacy Approve no longer sets `is_verified` on Buyer companies |
| Web | `lib/supabase/middleware.ts` | Routing role from `app_metadata` / DB, never `user_metadata`; null-safe |
| Web | `src/app/api/v1/requirements/sync/route.ts` | Buyer-only (audit F4). Note: `src/app` routes are shadowed by root `app/` (KI-44). |
| Admin | `src/server/actions/buyer-gst-verification-actions.ts`, `app/(admin)/admin/_components/buyer-gst-verification-queue.tsx` | **New**: queue, 60 s signed preview, approve/reject through the RPC with the admin's own session |
| Admin | `MasterDataTabs.tsx`, `company-approval-queue.tsx` | New tab; approval toast states when GST review is still required |
| RMBuyer | `lib/core/config/app_config.dart` | `GST_VERIFICATION_BACKEND` flag, refused for the production ref |
| RMBuyer | `lib/features/profile/data/gst_verification_repository.dart` | `SupabaseGstVerificationBackend` (upload to own folder, then RPC); `submit` contract; SQLSTATE error mapping |
| RMBuyer | `gst_verification_screen.dart`, `buyer_profile_screen.dart` | Server-confirmed submit, reload, errors, double-tap guard; build-selected source |
| RMBuyer tests | `gst_status_truth_test.dart`, `gst_verification_screen_test.dart`, `profile_screen_test.dart` | Submission, persistence and reload, failure, timeout, duplicate, prod-guard tests |

**Scratchpad only (not in the repo):**
- schema-only extract `baseline_schema.sql` (no data)
- read-only check scripts
- PGlite install

---

## 3. Phase A — offline migration validation (PGlite)

**Method.** I extracted a **schema-only** copy of the live tables the feature touches: `users`, `companies`, `crm_contacts`, `notifications`, plus their 5 functions, all policies, triggers and grants, with **no rows**. That extract was loaded into PGlite with minimal Supabase `auth`/`storage` stubs, then 0053 and 0054 were applied.

Each case runs as a real `authenticated` session (`SET ROLE` plus a JWT `sub` claim), so grants, RLS, invoker vs definer rights and triggers execute for real.

**Not proven offline:** PostgREST, Auth sign-in, Storage API size and MIME enforcement, signed-URL expiry, true concurrent sessions.

**Result: 85 passed, 0 failed.** Command:

```
node supabase/proposed/0054_tools/gst_backend_offline_test.mjs <repo> <baseline_schema.sql> <pglite dir>
```

### 3.1 Trust-field protection (0053), proof

- **Before 0053:** a Buyer **can** set its own `is_verified` and `trust_score`. This reproduces the live exposure.
- **After 0053:** Buyer UPDATEs of `is_verified`, `trust_score`, `bank_is_verified`, `bank_verification_status`, `created_by`, `status` and `id` are all rejected with `42501`. A Seller self-verify is rejected too.
- **Mutation check:** with the trigger disabled, the same Buyer write succeeds. So the test fails if the guard ever silently fails open.
- **Still works:**
  - Buyer profile edit (`name`, `state_id`, `district_id`)
  - RMSeller profile save (`name`, `gst`, …)
  - Broker's own name update
  - Broker directory insert (client-sent `is_verified = true`, `trust_score = 50` are stored as false/100)
  - Broker directory status edit of a CRM counterparty
  - Admin with a trusted `app_metadata` role
  - The `postgres` server path
- **Blocked:** a broker changing its own company's status, an unrelated company's status, or verifying a CRM counterparty. A `user_metadata` "admin" claim is not trusted. DELETE is no longer granted.

### 3.2 Defects found and fixed during testing

1. **G-4, NULL fail-open in 0053 (broad).** `OLD.created_by = auth.uid()` is NULL when `created_by` is NULL, so `NOT (… AND NULL)` made the `IF` false. A broker could have changed `status` on any company with a NULL creator, including its own. Fixed with `IS NOT DISTINCT FROM` and `coalesce(…, false)`, with a regression test.
2. **Review RPC / gst lock / 0053 entry check (narrow).** `is_admin()` returns **NULL**, not false, when the JWT's user has no `auth.users` row (a deleted account with a live token). Verified: for a roleless *existing* user it returns false, because `get_auth_role()` coalesces to `''`. All three checks now use `coalesce(public.is_admin(), false)`, with a regression test.

**The production copy (§1) predates fix 2.** Fix 1 is in 0053, which is not in production.

### 3.3 GST records, submission, storage and review (0054)

| Area | Verified offline |
|---|---|
| Bucket | Private, 5 MB, JPG/PNG |
| Storage policies | Owner uploads only to `<uid>/<uuid>.jpg\|png`. Other user's folder, Seller, Broker, PDF and nested paths are denied. Owner and admin read; other Buyer, Seller and Broker get 0 rows. No overwrite or delete, even by the owner. |
| Submit | Pending only. Forged `status`, `company_id` and `reviewed_by` in the payload are ignored. The company comes from the caller's own `users` row. `edited_fields` is recomputed server-side. Dates are parsed strictly, and absent values stay null. A `submitted` event is written. The company flag is not touched. |
| Submit rejections | Someone else's certificate path, a missing object, a co-worker's upload, a bad checksum, a state mismatch, a missing legal name, a bad date (`22023`), Seller or Broker callers (`42501`), the same active GSTIN at another company (`23505`), and identical resubmission while approved |
| Replace pending | The old row becomes `superseded` with a `replaced` event; history is retained; one pending row per company |
| Seller GSTIN conflict | Flagged (`seller_gstin_conflict = true`), not rejected |
| Direct writes | A Buyer cannot INSERT or UPDATE verification or event rows |
| Visibility | Own company only; admin sees all |
| Review | Buyer, Broker, `user_metadata` "admin", roleless and deleted-account callers are all denied. Reject needs a reason; reviewer and timestamp are recorded; **exactly one notification per Buyer user**. A decided row cannot be re-reviewed, and `rejected → approved` is blocked even for `postgres`. |
| Approval | Sets `is_verified` and `gst`; **company name is not overwritten**; event actor is the admin |
| Re-review | `companies.gst` is locked while pending or approved. A material GSTIN change marks the approval `superseded`, clears `is_verified` and creates a new pending row. |
| Integrity | History is append-only and submitted details are immutable (even for `postgres`). A failure part-way through review (forced notification error) rolls back status, flag and history together. |
| Legacy | The legacy flag is unchanged by the migrations. The legacy web Approve cannot verify a Buyer company without GST review, but still can for Sellers. |
| Rollback | Restores the pre-0053 state exactly. Re-applying is idempotent. |

**Concurrency:** duplicate-GSTIN protection is a partial unique index (`23505`), and per-company submissions lock the company row with `FOR UPDATE`. PGlite has a single connection, so **true parallel sessions were not exercised**; that needs the test project.

---

## 4. `verifyBuyerSession` role escalation (F3): fixed, with proof

**Root cause.** `user_metadata` is client-writable at sign-up and through `auth.updateUser()`. Three server sites inserted `public.users.role` from it: `verifyBuyerSession`, plus `createCompanyProfile` and `getCompanyProfile`. `trg_sync_privileged_role` then copied that role into **trusted** `app_metadata`, so a self-claimed "admin" became a real admin. The middleware also routed by `user_metadata.role` first.

**Fix.**
- `trusted-role.ts`: `provisionableRole()` only ever yields `buyer` or `seller`; privileged accounts are created explicitly by an admin. `trustedRole()` uses `app_metadata`, then the stored role, never `user_metadata`.
- Applied at all three provisioning sites and in the middleware.
- `verifyBuyerSession` now requires a Buyer (any role used to pass).
- The sync route requires a Buyer.

**Other paths checked and confirmed allow-listed:**
- sign-up: `z.enum(["buyer","seller"])`
- broker directory: `contactRoleEnum`
- admin broker creation: hard-coded `"broker"`
- users RLS: a self-update must keep the trusted role

**Tests:** `node --test src/server/utils/__tests__/trusted-role.test.mjs` gives **8/8 pass**. They cover:
- hostile `user_metadata` roles (`admin`, `ADMIN`, ` admin `, `broker`, `super_admin`, `service_role`, …)
- `app_metadata` admin never provisioned
- legitimate buyer and seller kept
- `trustedRole` ignoring `user_metadata`
- source assertions that no provisioning or routing site reads `user_metadata.role`
- the sync route and legacy-approval guards

**Type-check:** `tsc --noEmit` shows only the 3 **pre-existing** errors (`scripts/test-proposal-api.ts`, `broker-buyer-actions.ts`). ESLint on changed files: 0 errors (warnings only, matching existing `error: any` style).

**Not run:** a live sign-in escalation attempt. That needs the test project.

---

## 5. Admin "Buyer GST Verifications" tab

- A new sidebar tab next to Approvals, listing pending submissions with flags for "N edited" and "Seller GSTIN conflict".
- The review dialog shows:
  - the certificate, through a **60 s signed URL** issued with the admin's own session (no service key, no public URL)
  - OCR value vs submitted value per field, with edited fields highlighted
  - the stored company name and GSTIN, with the note "name is not changed by approval"
  - Approve, and Reject with a required reason
- The server actions use the **user-scoped Supabase client**, so RLS and `is_admin()` decide access and the RPC records the real reviewer.
- **Company Approvals:**
  - It remains for its other legitimate purposes.
  - For Buyer companies it now only activates (`status`), and the toast says GST review is still required.
  - 0054 also enforces this in the database for every path.

**Not exercised in a browser** (no test project).

---

## 6. RMBuyer end-to-end connection

- **`SupabaseGstVerificationBackend`:**
  - Rejects images over 5 MB or empty files on the device.
  - Uploads to `<uid>/<uuid>.jpg|png` (no upsert), then calls `submit_buyer_gst_verification` with `GstSubmissionDraft.toPayload()` and the object path.
  - Accepts success **only** when the RPC returns the saved row with status `pending`.
  - Reads status from the latest non-superseded row.
  - Has 30 s timeouts.
- **Errors** map by SQLSTATE (23505, 22023, 42501), timeout and storage failure to buyer-facing text. Success is never shown before the server confirms.
- **Off by default:** `GST_VERIFICATION_BACKEND=true` is honoured only when `SUPABASE_URL` is not the production ref (unit-tested). The installed and production builds therefore behave exactly as before.

**Widget tests (fake backend standing in for the RPC):**
- The draft sent is exactly the displayed values, including edits, with no status or verification keys.
- After success the screen shows Pending and success; reopening reloads Pending.
- Duplicate-GSTIN error shows actionable text with no success, and values are kept.
- Timeout shows no success.
- A second tap while submitting sends no duplicate.
- Invalid values are never sent.

**§13 steps 1–5:** done on device in earlier sprints, offline here. **Steps 6–14** against a real backend: **not done** (blocker 1).

---

## 7. Tests executed (exact results)

| Suite | Result |
|---|---|
| Offline DB security (`gst_backend_offline_test.mjs`) | **85 passed, 0 failed** |
| Web escalation (`node --test …trusted-role.test.mjs`) | **8 passed, 0 failed** |
| `tsc --noEmit` (web) | 3 errors, **all pre-existing**, none in changed files |
| `flutter analyze` | **No issues found** |
| Focused RMBuyer (GST, profile, More, router, settings, 9 files) | **98 passed** (before the final lint-only edit) |
| `flutter test test/widget_test.dart test/widgets test/unit` | **410 passed, 4 skipped, 1 failed** |
| `flutter build apk --debug` | **Built** (not installed) |
| Supabase test-project integration (grants, RLS, storage, signed URLs, concurrency, live sign-in) | **Not run** (blocker 1) |

**The 1 failure** is `chat_screen_test.dart` "send is disabled until text; sending shows a confirmed bubble". Root cause, confirmed by reading the code:
- `test/support/fake_chat_gateway.dart:18` fixes the fake clock at `DateTime.utc(2026, 10, 26, 9)`.
- `chat_screen.dart:347` labels days against the real `DateTime.now()`.
- So the test passes only on 26 Oct 2026.

This is a test-fixture bug, not an app defect. The fix is to seed the fake clock from `DateTime.now()`. It is untouched here and tracked separately.

---

## 8. Outstanding limitations

- No Supabase test project (CLI, token and Docker are unavailable).
- PostgREST, Storage, Auth, signed URLs and true concurrency are unverified.
- No device run of upload, submit and review against a real backend.
- The production incident (§1) is awaiting your decision.
- Retention (12 months for rejected and superseded certificates) is documented, not automated.

---

## 9. Production rollout proposal (NOT authorized; requires separate approval)

Prerequisite: resolve §1 first (Option A rollback recommended).

1. **Test project:**
   - Create `brokerbridge-test`.
   - Load a schema-only `pg_dump` of production.
   - Seed synthetic Buyer A/B, Seller, Broker and Admin accounts (set `app_metadata.role`).
   - Apply 0053 and 0054.
   - Run the §3 matrix through real PostgREST and Storage, plus concurrency.
   - Build RMBuyer with `--dart-define=SUPABASE_URL=… SUPABASE_ANON_KEY=… GST_VERIFICATION_BACKEND=true` and run §13 steps 1–14 on the device.
2. **Backup:**
   - A logical export of `companies` (`id`, `is_verified`, `status`, `trust_score`, `gst`) and `users` (`id`, `role`, `company_id`).
   - Snapshot `storage.buckets` and the policies.
3. **Database:**
   - 0053, then smoke-test the Buyer self-verify denial, Broker directory flows and admin flows.
   - 0054 (reviewed current version), then verify grants and policies read-only.
4. **Web:**
   - Deploy the escalation fix and the admin tab **in the same window as 0054**, because the legacy Approve change depends on it.
5. **Mobile:**
   - Remove the production-ref refusal in `AppConfig`.
   - Release RMBuyer with `GST_VERIFICATION_BACKEND=true`.
6. **Legacy companies:**
   - Keep their flags.
   - Ask those Buyers to submit.
   - Any reset is a separate, exported, reviewed one-off.
7. **Monitoring:**
   - Daily counts of pending submissions and decisions.
   - Notifications per decision.
   - `42501` and `23505` rates.
8. **Rollback:**
   - `rollback_0054.sql`: export first. It drops the bucket only when empty.
   - `rollback_0053.sql`: restores the exact prior grants.
   - Revert the web deploy.
   - Mobile falls back automatically, because the flag stays false without the backend.

---

## 10. Confirmation

- **This session made no production write:** every production access was a verified `BEGIN READ ONLY` transaction (metadata and counts only).
- **Production nonetheless changed** (§1): first-draft 0054 is present, applied at 06:53:24 UTC through a path this session does not use. It has not been rolled back, because that would be a production write requiring your approval.
- Nothing was committed, pushed or deployed.
- The two legacy Buyer companies' flags are unchanged.
- No secrets, keys or certificate contents are included in this report.
