# RMBUYER-GST-STATUS-TRUTH-01 — False "Verified" GST Status

**Date:** 2026-10-29 · **Branch:** `feature/broker-nilesh` (uncommitted; nothing pushed or deployed)

## Status: **PASS WITH LIMITATIONS**

- **Fixed:** the false "Verified" status is fixed, and a regression test passes.
- **Profile integration:** the GST screen now shows the saved profile details separately from OCR results.
- **Limitation:** most GST profile fields have no backend column. Submission, Pending and Rejected need the approved backend work (`RMBUYER-GST-BACKEND-PLAN-01-REPORT.md`).
- **Not changed:** no production flags were altered.

## 1. Root cause (confirmed)

**Account on the device.** I read live data in a `BEGIN READ ONLY` transaction, with identifiers masked. The most recent Buyer sign-in is user `d5929da1…` (`ro***@gmail.com`) at 2026-10-29 06:02 UTC (11:32 IST), during the device session. Its company is `53b23dbe…`.

| Field | Live value |
|---|---|
| `companies.is_verified` | **true** |
| `companies.status` | true |
| `companies.gst` | **empty** |
| `companies.created_by` | null (no creator recorded) |
| `trust_score` | 100 |
| GST verification table, record or certificate | **none exist** (0 matching tables; no Buyer certificate bucket) |

The other Buyer account with a company (`e24072b3…`, last sign-in 2026-10-24) is in the same state: `is_verified = true`, no GSTIN.

**Code path.** `BuyerProfileRepository.getProfile()` loads the company from the signed-in user's own `users.company_id` row. There is no fallback ID on this path; the hard-coded fallback in `requirements_repository.dart` (audit F6) is a different flow.

The old `GstVerificationRepository.loadStatus()` mapped `profile.companyVerified == true` straight to "Verified — Your business is verified". The Edit Profile "Verification" row did the same.

**What `is_verified` actually means.** It is a **legacy company-approval flag**, not GST evidence. Its writers are:
- the web Admin "Company Approvals" action, `approveCompanyAction` (`src/server/actions/company-actions.ts`). It sets `status` and `is_verified` to true **without recording a reviewer, a timestamp or any evidence**.
- seed data
- RMBroker directory creates, which send `false`
- any company member through the open `companies` UPDATE policy (BACKEND-PLAN §1.1)

It is also read across the platform as a trust badge, so that meaning is kept (see §3). It is just no longer treated as a GST result.

**Reproduction.** The previous test "a backend-verified company shows Verified and no upload" fed `is_verified = true` with no GST record and passed on the old code: it rendered **Verified**. Run against the fixed code, the same test fails with `Expected: 'Verified', Actual: 'Not Verified'`. It has been replaced by the regression tests below.

## 2. Fix

GST status now comes **only from a GST verification record**. Mapping:

| Authoritative data | GST screen | Edit Profile "Verification" row |
|---|---|---|
| Approved record | **Verified**, "GST certificate was reviewed and approved", no upload | Verified |
| Pending record | **Pending**, "Submitted — Awaiting Verification.", no new upload | Not verified |
| Rejected record | **Rejected** with the server's `rejection_reason`; upload offered again | Not verified |
| No record (including legacy `is_verified = true`) | **Not Verified**, "No GST certificate submitted… online submission is not available yet". If the legacy flag is set, a note explains that the older "verified" mark has no GST certificate behind it. | Not verified |
| Profile or record read fails | Error state with retry; no badge | Row left empty, never guessed |
| No company linked | Not Verified, contact support; no record read, no upload | Empty |

**Mechanism:**
- `GstVerificationRecordSource` is the single place GST records are read from.
- The live implementation, `NoGstVerificationBackend`, returns "no record" and `available = false`, because the backend tables don't exist.
- When the planned `buyer_gst_verifications` table exists, a Supabase-backed source replaces it. `GstVerificationRecord.fromRow` already parses the planned columns and **throws on an unknown status** rather than guessing.
- No Pending record is ever fabricated.

**Production data:** no flags were cleared or rewritten (see §5).

## 3. Profile fields

**Shown from saved backend data**, in a "Saved profile details" card on the GST screen, kept separate from the OCR review form:
- company name
- GSTIN (`companies.gst`)
- state, **derived from the saved GSTIN** and labelled as such

OCR results stay in the review form and are never written to the profile. A test proves the saved values are unchanged, with zero writes, after OCR and Submit.

**Fields with no safe place in the current schema:**

| Field | Backend |
|---|---|
| GSTIN | ✅ `companies.gst`. Writable by the company today, but the app doesn't write it. |
| Company / trade name | ✅ `companies.name` (single field) |
| Legal name | ❌ none |
| Constitution | ❌ none |
| Principal address, PIN | ❌ none (`companies` has only `state_id` and `district_id`) |
| State | ⚠️ `companies.state_id` (ID, not a GST state). Shown as derived from the GSTIN instead. |
| Registration type, liability / validity / issue dates | ❌ none |
| PAN | Not stored (derived from the GSTIN; no requirement justifies storage) |

**Required change:** the `buyer_gst_verifications` columns in `RMBUYER-GST-BACKEND-PLAN-01-REPORT.md` §3.1, written only through the submit RPC. No client-only fields were added, and the app does not claim to save them. The card states "…are not stored by the server yet".

The Edit Profile screen keeps its existing localized rows. Only the meaning of its Verification row changed; no new translation keys were needed.

## 4. Files changed

| File | Change |
|---|---|
| `lib/features/profile/data/gst_verification_repository.dart` | New status enum (notSubmitted, pending, approved, rejected, noCompany); `GstVerificationRecord` with `fromRow`; `GstVerificationRecordSource` / `NoGstVerificationBackend`; status no longer derived from `is_verified`; `hasUnbackedLegacyFlag` |
| `lib/features/profile/presentation/gst_verification_screen.dart` | Status card for all states; upload only when not submitted or rejected; legacy-flag note; "Saved profile details" card |
| `lib/features/profile/presentation/buyer_profile_screen.dart` | Verification row reads the GST record source, not `is_verified`; read failure leaves the row empty |
| `test/unit/gst_status_truth_test.dart` | **New** |
| `test/widgets/gst_verification_screen_test.dart` | Replaced the bug-encoding test; added the status-truth group; refresh test now uses records |
| `test/widgets/profile_screen_test.dart` | Added verification-row tests |

**Not changed:** `BuyerProfileRepository` write paths, the l10n files, chat code, other apps, and anything on the server.

## 5. Affected records and proposed remediation (not applied)

Both Buyer companies that have users (`53b23dbe…`, `567f1ce4…`) have `is_verified = true` with no GSTIN and no review record. The app now shows them as **GST Not Verified**, while their legacy flag is left in place.

**Proposed for owner review** (decision B6 in the backend plan; nothing applied):
1. Keep `is_verified` as the legacy company-approval meaning until the GST backend exists.
2. After migration 0054, have both companies submit through the new flow.
3. Optionally reset the legacy flag. The reset would run as a reviewed one-off `UPDATE … WHERE id IN (…)` by an admin, with an export first, and **only** if the owner decides the badge should mean GST-verified.

## 6. Tests and results

The regression checklist maps to tests as follows:

| # | Requirement | Covered by |
|---|---|---|
| 1 | `is_verified = true` without a GST record is not Verified | Widget: "regression: is_verified=true with no GST record is NOT shown as Verified". Unit: legacy → notSubmitted. Profile row: "legacy … shows Not verified". |
| 2 | No submission → Not Verified / not submitted | Widget and unit |
| 3 | Authoritative approval → Verified | GST screen (with and without the legacy flag) and profile row |
| 4 | Pending / Rejected only from server data | Pending and rejected widget tests (with reason); unknown or missing status throws |
| 5 | Read failure → error | Profile-read and record-read failure tests (no badge) |
| 6 | Correct company, no fallback | Records read for `c-001` only; no company → no read; `profileFromRows` with null company stays null |
| 7 | Profile fields from saved data | Saved-details card test |
| 8 | OCR not persisted | Saved values unchanged and `writes` empty after OCR and Submit |
| 9 | Client can't set approval fields | `editableChanges` drops `is_verified`, `status`, `trust_score`, `company_id` and `role` |
| 10 | Profile edits intact | Existing profile edit and save tests pass |

The Admin approval path is server code and was not changed.

| Command | Result |
|---|---|
| `flutter analyze` | **No issues found** |
| Focused (9 files: GST, profile, More, router, settings) | **89 passed** |
| `flutter test test/widget_test.dart test/widgets test/unit` | **401 passed, 4 skipped, 1 failed**: `chat_screen_test.dart` "send is disabled until text; sending shows a confirmed bubble" (missing "Today" label). This is the same pre-existing failure tracked separately; chat code is untouched. |
| `flutter build apk --debug` | Built, and installed on the Redmi Note 5 Pro (`e0d9da95`) |

**Not done:** an on-device visual check of the fixed screen. The app was installed but not driven, because MIUI blocks adb taps and the device is shared with the user.

## 7. Approval-required backend work (unchanged from the backend plan)

1. **0053:** an invoker-rights trigger so Buyers can no longer set `is_verified`, `status`, `trust_score` or the bank-verified fields. This is still exploitable today: the live grant and policy were confirmed this sprint.
2. **0054:** the `buyer_gst_verifications` and events tables, the submit and review RPCs, and the private certificate bucket. This provides the GST profile columns from §3 and the real Pending, Approved and Rejected data.
3. **Client follow-up** after 0054: a Supabase-backed `GstVerificationRecordSource` plus the upload and submit call.
4. **Decisions** B1 (non-production project) and B6 (the legacy flags in §5).

No migrations, policies, grants, storage or production data were changed.
