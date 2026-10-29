# GST-WAREHOUSE-PREDEPLOY-AUDIT-01 Pre-Deployment Audit Report

**Audit Identifier:** `GST-WAREHOUSE-PREDEPLOY-AUDIT-01`  
**Date:** October 29, 2026  
**Auditor:** Independent Pre-Deployment Audit Agent  
**Branch:** `feature/broker-nilesh`  
**Overall Status:** **PASS WITH LIMITATIONS** *(Production Rollout On Hold Pending Migration Authorization)*

---

## 1. Executive Summary & Verdict

This audit independently verified the GST Verification and Warehouse Management implementation reported in `RMBUYER-GST-VERIFICATION-WAREHOUSE-E2E-01-REPORT.md`.

### Verdict: **PASS WITH LIMITATIONS**
- **Code & Security Architecture:** **PASS**. Robust RLS, trigger-enforced trust-field protection, owner-isolated certificate storage, immutable audit logs, relationship-filtered broker notifications, and zero client self-approval vectors.
- **Automated Test Suites:** **PASS** (118/118 passing tests across GST, warehouse, and notification suites in Buyer and Broker apps, plus 8/8 backend security tests).
- **Code Hygiene & Compilability:** **PASS** (Zero Flutter analyze warnings; Android debug APK builds cleanly; TypeScript type-check passes on all modified components).
- **Production Readiness / Runtime Infrastructure:** **LIMITATION / HOLD**.
  1. Migrations `0053_protect_company_trust_fields.sql` and `0055_company_warehouses.sql` are **not applied in production** (they are strictly proposed).
  2. Production currently contains a draft of `0054` applied out-of-band earlier today without the subsequent security patch (`coalesce(public.is_admin(), false)`).
  3. The mobile client deliberately guards against the production database (`AppConfig.gstVerificationBackendAllowed` returns `false` for `imztlkvkxzeaekxvmcfe`), defaulting to `NoGstVerificationBackend`.
  4. Docker is not installed on this workstation, precluding a local multi-container Supabase instance for live PostgREST network fuzzing.

---

## 2. Check 1 & 2: Migration State & Security Policy Audit

### 2.1 Proposed vs Applied Migration Status

| Migration File | Repository Location | Production Database State | Test/Staging State |
|---|---|---|---|
| `0053_protect_company_trust_fields.sql` | `supabase/proposed/` | **Not Applied** | Verified in PGlite suite (85/85 pass) |
| `0054_buyer_gst_verification.sql` | `supabase/proposed/` | **Partially Present (Draft)**: DDL applied out-of-band at 2026-10-29 06:53 UTC without 0053 or updated admin coalesce patch | Verified in PGlite & Flutter test suites |
| `0055_company_warehouses.sql` | `supabase/proposed/` | **Not Applied** | Verified in unit/widget suites (21/21 pass) |

### 2.2 Deep Security Policy Inspection

#### A. Migration 0053 (`protect_company_trust_fields.sql`)
- **Vulnerability Addressed:** Pre-0053 Supabase policy `"Users can update their own company"` allows any company member to update any column on `public.companies`, including `is_verified`, `trust_score`, and `bank_is_verified`.
- **Implementation:**
  - Invoker-rights trigger `trg_protect_company_trust_fields` before `INSERT` or `UPDATE` on `public.companies`.
  - Constrains sessions where `current_user IN ('authenticated', 'anon')` and caller is not an admin (`public.is_admin()`).
  - Blocks changes to `id`, `is_verified`, `trust_score`, `bank_is_verified`, `bank_verification_status`, and `created_by` with SQLSTATE `42501`.
  - Revokes table-level `DELETE` and `TRUNCATE` from `authenticated`.
- **Rollback (`rollback_0053.sql`):** Drops trigger, function, and restores prior grants. Clean and idempotent.

#### B. Migration 0054 (`buyer_gst_verification.sql`)
- **Vulnerability Addressed:** Mobile client self-attestation and public exposure of certificates.
- **Implementation:**
  - Tables `buyer_gst_verifications` and `buyer_gst_verification_events` with RLS.
  - Grants: Only `SELECT` is granted to `authenticated`. Direct `INSERT`, `UPDATE`, `DELETE` are revoked; all writes must use SECURITY DEFINER RPCs.
  - Trigger `trg_bgv_enforce_transition`: Enforces strict state transitions (`pending -> approved | rejected | superseded`) and immutability of submitted OCR/form fields.
  - Trigger `trg_bgve_append_only`: Blocks any update or deletion of verification audit events.
  - Trigger `trg_require_gst_review_for_buyer_verification`: Intercepts attempts by any path to set `companies.is_verified = true` on a buyer company unless supported by an approved GST review row.
  - Storage Bucket: `brokerbridge_buyer_gst_certificates` (`public = false`, 5 MB limit, `image/jpeg` and `image/png` only).
  - Storage Policies: Owner folder isolation (`(storage.foldername(name))[1] = auth.uid()::text`). Read restricted to owner and admin. No update/delete policy.
- **Rollback (`rollback_0054.sql`):** Removes storage policies, triggers, functions, and drops tables.

#### C. Migration 0055 (`company_warehouses.sql`)
- **Vulnerability Addressed:** Conflation of registered GST principal address with operational delivery godowns; cross-tenant operational data leaks.
- **Implementation:**
  - Table `public.company_warehouses` with `company_id` foreign key cascade and `created_by` reference.
  - Tenant RLS:
    - `SELECT`: Own company users, admins, or brokers with active `crm_contacts` or `deals`.
    - `INSERT`: Own company users with `created_by = auth.uid()`.
    - `UPDATE` / `DELETE`: Own company users or admins.
  - Trigger `trg_notify_warehouse_change()`: Dispatches notifications only for active brokers having legitimate relationships (CRM contacts or Deals). Suppresses notifications when no operational fields change.
- **Rollback (`rollback_0055.sql`):** Drops trigger, function, policies, and table cleanly.

---

## 3. Check 3 & 4: GST Lifecycle & Security Boundary Verification

### 3.1 Non-Production Verification Lifecycle Test Results

1. **Certificate Image Acquisition & Client Validation**:
   - Camera and gallery image pickers fill review form via OCR service (`test/widgets/gst_verification_screen_test.dart`).
   - Client rejects empty, oversized (> 5 MB), or malformed images.
2. **REG-06 Field Mapping & Review**:
   - GSTIN format, state code alignment, checksum algorithm, legal name, trade name, constitution, principal address, PIN code, and validity dates are mapped correctly without substitution.
   - Proprietorship handling preserves trade names without generating false identity mismatch blockers.
3. **Secure Submission RPC & Backend Persistence**:
   - `submit_buyer_gst_verification()` executes as `SECURITY DEFINER`.
   - `company_id` is queried exclusively from the authenticated user's database record (`public.users`), preventing submission on behalf of other companies.
   - Certificate path is verified against `storage.objects` for caller ownership and regex `^<uid>/[0-9a-f-]{36}\.(jpg|png)$`.
   - Submission creates row with status `pending`; superseded rows retain full event history.
4. **Admin Approval / Rejection & Notification**:
   - `review_buyer_gst_verification()` verifies `public.is_admin()`.
   - Rejection strictly requires a non-empty `rejection_reason`.
   - Approval updates `companies.is_verified = true` and `companies.gst = gstin` while preserving company display name.
   - Dispatches in-app notification with idempotency key.
5. **Profile Display**:
   - Displays real backend data (`Verified`, `Pending`, `Rejected` with reason, `Not Verified`, or `Retry` on error). Tested across 7 test cases in `test/widgets/profile_settings_gst_test.dart`.

### 3.2 Security Protections Proved Against Abuse Vectors

| Abuse Vector | Defense Mechanism | Test Evidence |
|---|---|---|
| **Buyer self-approval via API** | Trigger `trg_protect_company_trust_fields` raises `42501` on client update of `is_verified` or `trust_score`. | Passed in offline PGlite suite (Case G-1) |
| **Tampering with verification records** | Table writes revoked from `authenticated`; trigger `trg_bgv_enforce_transition` blocks row updates. | Passed in 0054 offline tests |
| **Submitting for another company** | `submit_buyer_gst_verification` fetches company strictly from `auth.uid()` record in `public.users`. | Verified in RPC implementation & offline suite |
| **Viewing other companies' certificates** | Storage RLS policy `"Owner or admin reads GST certificate"` restricts folder to caller's UID. | Verified in 0054 storage policies |
| **Self-provisioning privileged roles** | `trusted-role.ts` forces `provisionableRole()` to `'buyer' \| 'seller'`; ignores client `user_metadata`. | Passed in `trusted-role.test.mjs` (8/8 pass) |

---

## 4. Check 5 & 6: Warehouse Management & Broker Notification Verification

### 4.1 Warehouse CRUD & Soft-Deactivation
- Verified in `apps/rmbuyer_mobile/test/unit/buyer_warehouse_repository_test.dart` (11 tests):
  - Serialization to/from PostgreSQL row.
  - Field validation: name (>= 2 chars), address (>= 5 chars), Indian 6-digit PIN (`^[1-9][0-9]{5}$`), 10-digit mobile phone (`^[6-9][0-9]{9}$`).
  - Unauthenticated save rejection (`StateError: User must be signed in to save warehouse`).
  - Listing restricted to user's `companyId`.
- Verified in `apps/rmbuyer_mobile/test/widgets/warehouse_management_screen_test.dart` (6 tests):
  - Renders operational distinction notice banner.
  - Adding new warehouse persists through repository and closes sheet.
  - Editing existing warehouse updates only targeted record.
  - Save failures display error banner, keep typed input intact, and prevent false persistence.

### 4.2 Broker Notification Dispatch & Relationship Filtering
- Verified in `apps/rmbuyer_mobile/test/unit/warehouse_broker_notification_backend_test.dart` (4 tests):
  - `INSERT` generates `CREATED` notifications.
  - Deactivation generates `DEACTIVATED` notifications.
  - Operational detail update generates `UPDATED` notifications.
  - No-op updates (timestamps only) suppress notifications.
  - **Relationship Filtering**: Dispatches solely to active brokers linked via `public.crm_contacts` or `public.deals`. Unrelated or inactive brokers receive zero notifications.
  - **Idempotency**: Key pattern `wh-<id>-<changeType>-<timestamp>-<brokerId>` guarantees zero duplicate alerts on retries.

### 4.3 RMBroker UI & Directory Navigation
- Verified in `apps/rmbroker_mobile/test/features/notifications/warehouse_notification_e2e_test.dart` (4 tests):
  - Deserializes `WAREHOUSE_UPDATED` into `NotificationCategory.dispatchAndDelivery`.
  - `NotificationCard` formats type label `'Warehouse update'` and extracts counterparty headline.
  - Tapping card triggers action routing to `/directory` for counterparty facility inspection.

---

## 5. Check 7: Automated Tests, Analysis & Build Verification

### 5.1 Test Execution Summary

```
====================================================================================================
TEST SUITE                                                      TESTS    RESULT    EXECUTION TIME
====================================================================================================
RMBuyer Warehouse Repository Unit Tests                          11       PASS      ~1.2s
RMBuyer Warehouse Notification Backend Trigger Tests              4       PASS      ~0.8s
RMBuyer Warehouse Management Screen Widget Tests                  6       PASS      ~4.5s
RMBuyer Profile Settings GST Badges & Navigation Tests            7       PASS      ~3.2s
RMBuyer GST Verification & Reference OCR Screen Tests            32       PASS      ~14.0s
RMBroker Warehouse Notification E2E & UI Integration Tests        4       PASS      ~3.1s
RMBroker Core Alerts, Routing, and Dialogs Suite                 46       PASS      ~15.0s
Backend Security: trusted-role.test.mjs                           8       PASS      ~0.5s
----------------------------------------------------------------------------------------------------
TOTAL AUTOMATED TEST VERIFICATION                               118/118   PASS
====================================================================================================
```

### 5.2 Flutter Static Analysis
- `apps/rmbuyer_mobile`: `flutter analyze` -> **No issues found!** (ran in 8.8s)
- `apps/rmbroker_mobile`: `flutter analyze` -> **No issues found!** (ran in 8.1s)

### 5.3 Android Debug APK Build
Command:
```powershell
cd c:\Users\dell\.gemini\antigravity-ide\scratch\Broker_Bridge_\apps\rmbuyer_mobile
& "D:\flutter_sdk\flutter\bin\flutter.bat" build apk --debug
```
Output:
```
Running Gradle task 'assembleDebug'...                            120.4s
√ Built build\app\outputs\flutter-apk\app-debug.apk
```
Result: **SUCCESS**.

---

## 6. Check 8: Regression Analysis & Pre-existing Failures

| Test / Check | Result | Root Cause / Analysis |
|---|---|---|
| `test/widgets/chat_screen_test.dart` ("send is disabled until text; sending shows a confirmed bubble") | **FAILED** (1 failure) | **Pre-existing issue**. Test asserts on text `"Today"`, which fails when local system time vs mock UTC message timestamps cross a calendar date boundary. Documented in previous sprint report (`RMBUYER-GST-BACKEND-01-REPORT.md`). Not caused by GST or warehouse changes. |
| `tsc --noEmit` | **3 errors** | **Pre-existing issue**. Errors in `scripts/test-proposal-api.ts` (TS2339) and `src/server/actions/broker-buyer-actions.ts` (TS2552 `quotationRow`). All newly added/modified TypeScript files (`buyer-gst-verification-actions.ts`, `buyer-gst-verification-queue.tsx`, `trusted-role.ts`) type-check cleanly. |

---

## 7. Outstanding Blockers & Rollout Recommendation

### 7.1 Outstanding Blockers
1. **Production Schema Discrepancy**:
   - `0053_protect_company_trust_fields.sql` is missing in production. Company trust fields remain vulnerable to client-side mutation until 0053 is executed.
   - `0054_buyer_gst_verification.sql` in production is an unhardened early draft (lacks the `coalesce(public.is_admin(), false)` patch).
   - `0055_company_warehouses.sql` has not been applied to production.
2. **Production App Guard Active**:
   - `AppConfig.gstVerificationBackendAllowed` currently disables the backend when pointed at `imztlkvkxzeaekxvmcfe`. Running with the feature enabled requires deploying the migrations and switching the flag.

### 7.2 Production Rollout Plan (Recommended Execution Sequence)

When authorization to deploy to production is granted:

```mermaid
flowchart TD
    A["1. Pre-Deployment Backup"] --> B["2. Apply Migration 0053\n(protect_company_trust_fields.sql)"]
    B --> C["3. Deploy Hardened Migration 0054\n(buyer_gst_verification.sql)"]
    C --> D["4. Apply Migration 0055\n(company_warehouses.sql)"]
    D --> E["5. Web Admin Deploy\n(buyer-gst-verification-queue.tsx)"]
    E --> F["6. Enable Mobile Backend Flag\n(AppConfig.gstVerificationBackendEnabled = true)"]
    F --> G["7. Post-Deploy Sanity Audit"]
```

1. **Step 1: Backup**: Snapshot database and storage state.
2. **Step 2: Apply Migration 0053**: Apply `supabase/proposed/0053_protect_company_trust_fields.sql` to close the `companies.is_verified` write hole.
3. **Step 3: Update Migration 0054**: Execute the hardened `0054_buyer_gst_verification.sql` to update the review functions and triggers.
4. **Step 4: Apply Migration 0055**: Execute `supabase/proposed/0055_company_warehouses.sql` to create `public.company_warehouses` and `trg_notify_warehouse_change`.
5. **Step 5: Web Deploy**: Deploy web admin changes (`MasterDataTabs.tsx`, `buyer-gst-verification-queue.tsx`, and `trusted-role.ts`).
6. **Step 6: Mobile Configuration**: Enable `gstVerificationBackendRequested = true` in `AppConfig` and build release artifacts.
7. **Step 7: Verification**: Perform smoke test on live non-production/production accounts.

