# RB-SELLER-POST-INTEGRITY-02 — Implementation Report

**App:** `apps/rmseller_mobile` · **Date:** 2026-10-27 · **Follows:** RB-SELLER-POST-REGRESSION-01

## 1. Phase 1: current state (verified)
- The workspace matched the end of REGRESSION-01 (same modified and new files; nothing unexpected).
- **Still open in code at the start:**
  - `updateCommodityStatus` always returned `true`. It wrote the session cache before the server, swallowed errors, used a hard-coded company fallback, and had no `.select()`.
  - There was no date-window validation.
  - The lab flow still submitted a device-local path as `labReportFileUrl`.
  - Commodity Details showed an invented certificate number.

## 2. Implemented (in this sprint)
| Area | Change | File |
|---|---|---|
| **A. Fulfil / Withdraw** | See A below | `commodities_repository.dart` |
| A (UI) | `_applyStatus` (see A below); `_confirmStatusUpdate` confirms, then calls it | `commodity_details_screen.dart` |
| **B. Dates** | See B below | `post_commodity_screen.dart` |
| B (crash fix) | Date pickers clamp `initialDate` to their window. Editing a lot with a past Valid Until, or Available From older than 30 days, previously **tripped `showDatePicker`'s assertion** | `post_commodity_screen.dart` |
| **C. Lab report** | `labReportFileUrl` is only a real `remoteStorageUrl`, never a device path. The details row shows **"Not provided"** instead of the invented `AGMARK-RAL-2026-9021`. Cancel and failure no longer fabricate files (fixed in REGRESSION-01, re-verified) | `post_commodity_screen.dart`, `commodity_details_screen.dart` |
| **D. Duplicate retry (app side only)** | `createCommodity` maps `23505` to "Lot `<n>` is already listed. Check My Commodities…" (`code: 23505`). It takes effect only once the proposed constraint exists | `commodities_repository.dart` |
| Tests | New `test/unit/seller_lot_integrity_test.dart`. `fake_postgrest.dart` gains unique-constraint enforcement (23505) and a lost-response mode (commit, then 502). New widget tests in `commodity_details_screen_test.dart` and `post_commodity_quantity_price_test.dart`. `commodities_repository_test.dart` was updated to the new return type | `test/…` |

**A. Fulfil / Withdraw (`updateCommodityStatus`):**
- Now returns the **server-confirmed** status and throws `StatusUpdateException` on: an invalid ID (before any request), no session or company, a request failure, 42501 ("not allowed"), **zero rows**, or a stored status that differs from the requested one.
- The session cache and the notifier change **only after** confirmation.
- The company comes from the caller's own `users` row.

**A (UI), `_applyStatus` in the details screen:**
- The screen changes only after confirmation, then **re-reads the lot from the server**. If that re-read fails, it keeps the confirmed value.
- On failure the current state is kept, and a SnackBar shows the message with a **Retry** action that re-sends without the dialog. The duplicate-tap guard is kept.

**B. Dates (`PostCommodityScreen.validUntilError()`):**
- The rule compares calendar days: Valid Until on or after Available From; the same day is allowed.
- It is used in three places, so create and edit (the same screen with `initialLot`) are identical:
  1. a **field-level** `errorText` on Valid Until;
  2. the review gate, which opens Commodity & Pricing **and** Additional Details and shows a SnackBar;
  3. a `_handleSubmit` guard.
- Server-side validation and the API are unchanged; the database has no check constraint here.

## 3. Proposed only: NOT applied
| ID | File | Purpose |
|---|---|---|
| 0045 | `supabase/proposed/0045_unique_company_lot_number.sql` + `rollback_0045.sql` | Partial unique index `(company_id, lot_number) WHERE lot_number IS NOT NULL`, with an abort-if-duplicates guard |
| 0046 | `supabase/proposed/0046_seller_broker_assignment_check.sql` + `rollback_0046.sql` | Seller branch: `broker_id` must be NULL or an **active** `broker` user |

Details are in the security and migration review.

## 4. Audits (Phases 3–4): findings, no changes
- **Broker assignment:**
  - **Not enforced server-side.** A seller can set `broker_id` to any user ID.
  - There is no seller↔broker relationship table. "Trusted brokers" means every `role = 'broker'` user.
  - The proposed fix is 0046.
- **What is persisted where:**

| Value | Stored where | Survives app restart / other device? |
|---|---|---|
| Commodity, grade, unit, quantities, asking price, state/district (warehouse), status, broker, visibility, availability dates, loading status | `availabilities` columns | **Yes** |
| Loading / dispatch text (`loading_remarks`) | `availabilities.loading_remarks` | **Yes** (read back since REGRESSION-01) |
| Payment terms | **No column anywhere** in `public` | **No**: session cache only |
| Warehouse name/address/PIN text, office location | **No column** | **No**: session cache only |
| Mandi name | **No column** | **No** |
| Lab report attachment (file) | Not uploaded; `isUploaded: false` | **No** |
| Lab test request + file URL | `lab_tests` table has `file_url`, `report_number`, `status`; bucket `brokerbridge_lab_evidence` exists (no size or MIME limit) | Only via the lab-testing flow (see §5) |

- **Minimum changes for a real lab-report upload, using existing storage (no new columns):**
  1. After the lot insert returns its `id`, upload to `brokerbridge_lab_evidence/{availability_id}/{file}`. The path format and SELECT policy already exist (`manual_lab_storage_rls.sql`).
  2. Insert a `lab_tests` row (`availability_id`, `company_id`, `report_number`, `file_url`, `status = 'Submitted'`).
  3. Set `remoteStorageUrl` and `isUploaded = true` **only** after both succeed. Show an error with Retry otherwise.
  4. Verify `lab_tests` RLS for seller inserts (not inspected here).
  5. Decide a size limit (see below).
- **File-size limit:** **not applied.** The bucket has `file_size_limit = null` and no MIME restriction, so there is no defensible existing contract. Decision needed (for example 10 MB, with PDF/JPEG/PNG only, enforced on both the bucket and the client).

## 5. Critical finding outside this sprint's change scope (not modified)
- `PostCommodityScreen._handleVerifyUpiPayment` calls `LabTestingRepository.verifyPaymentWithBackend(..., simulateSandboxVerification: true)`.
- In that code path **any unknown transaction reference is marked paid** (`backendConfirmed = true`). The UI then shows **"Paid — Payment Verified"**, and `_syncLabTestRecordToBackend` writes the verified state.
- This is a **false payment confirmation in production builds**.
- Lab payment logic is protected and was out of scope, so **no change was made**. It needs an explicit decision: disable the flag outside debug builds, and verify against a real gateway or admin confirmation.
- Related: the lab report card's `'RSL-REPORT-VERIFIED'` fallback (`commodity_details_screen.dart`, lab-testing card) belongs to the same protected flow and is reported, not changed.

## 6. Files changed in this sprint
- `lib/features/commodities/data/commodities_repository.dart`
- `lib/features/commodities/presentation/commodity_details_screen.dart`
- `lib/features/commodities/presentation/post_commodity_screen.dart`
- `test/support/fake_postgrest.dart`
- `test/unit/seller_lot_integrity_test.dart` (new)
- `test/unit/commodities_repository_test.dart`
- `test/widgets/commodity_details_screen_test.dart`
- `test/widgets/post_commodity_quantity_price_test.dart`
- `supabase/proposed/0045_*`, `rollback_0045.sql`, `0046_*`, `rollback_0046.sql` (new; **not applied**)

No production writes. No migration, RLS, schema or account changes. Migration 0044 was neither applied nor rolled back.
