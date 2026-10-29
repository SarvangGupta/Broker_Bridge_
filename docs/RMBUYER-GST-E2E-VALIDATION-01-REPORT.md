# RMBUYER-GST-E2E-VALIDATION-01 — GST Verification End-to-End Validation

**Date:** 2026-10-29 · **Branch:** `feature/broker-nilesh` (uncommitted; nothing pushed or deployed)

## Final status: **FAIL as end to end**, **PASS WITH LIMITATIONS for the client half**

| Stage | Result |
|---|---|
| Certificate → OCR/parser | **PASS** against the real phone capture of the reference certificate. Two values are limited by OCR quality; see §2. |
| Parser → review form | **PASS**: all 11 fields map to the right controllers |
| User edits / validation | **PASS**: edits survive validation and repeated submits; new GSTIN-state vs address check |
| Submission → backend → database | **BLOCKED.** No secure submission endpoint, table or certificate bucket exists (re-checked live, read-only, today) |
| Profile/status reload after submit | **BLOCKED** for the same reason. Reload of `companies.is_verified` itself works. |

Because submission and persistence could not be tested, the pipeline cannot be called PASS end to end. Nothing was simulated.

## 1. Files inspected and changed

**Inspected:**
- RMBuyer `lib/features/profile/**` (screen, repository, parser, OCR service, models), `more_screen.dart`, `app_router.dart` and their tests.
- RMSeller `gst_certificate_parser.dart` and `test/unit/gst_certificate_amended_photo_test.dart`.
- Live schema, read-only (`BEGIN READ ONLY`, metadata only; script kept in the session scratchpad):

| Check | Live result |
|---|---|
| Tables, functions or buckets matching gst/verif/certificate | **none** |
| Buckets | only `brokerbridge_documents`, `brokerbridge_lab_evidence`, `brokerbridge_seller_invoices` |
| `companies` UPDATE policies | still include `"Users can update their own company"` |
| `authenticated` UPDATE on `is_verified`, `status`, `trust_score` | still granted (3 of 3) |

**Changed (RMBuyer only):**

| File | Change |
|---|---|
| `lib/features/profile/domain/gst_certificate_data.dart` | Added validity-from, validity-to and issue-date fields. Added a GSTIN-state vs address-state check (`stateMismatch`). Added `GstSubmissionDraft` (reviewed values, OCR values, edited fields; the payload carries no status or company fields). |
| `lib/features/profile/data/gst_certificate_parser.dart` | Extracts validity (only when the value is legible) and the issue date, using RMSeller's logic so the issue date can't be the liability date, a validity date or the signature timestamp. Liability falls back to the first standalone date. |
| `lib/features/profile/presentation/gst_verification_screen.dart` | Labels for the 3 new fields; state-mismatch message |
| `test/unit/gst_reference_certificate_test.dart` | **New.** Reference fixture plus degraded variants, state check and submission-draft tests |
| `test/widgets/gst_verification_screen_test.dart` | Reference-certificate form tests; adjusted one assertion for the new issue-date field |

The certificate image was **not** stored in the repository. The fixture is the verbatim ML Kit text already captured on a phone for this same certificate and kept in RMSeller's tests. No personal data is logged.

## 2. Expected vs actual OCR output

"Phone capture" is the real ML Kit text of the supplied certificate. "Clean reading" is the same certificate as a straight, sharp scan would read.

| Field | Expected | Phone capture (actual) | Clean reading | Notes |
|---|---|---|---|---|
| GSTIN | `08ADRPK6597J1ZL` | `08ADRPK6597J1ZL` ✅ | ✅ | OCR read `6S97`; repaired via the check character and **flagged** for the user to compare. The reference passes the existing checksum unchanged; no rule was weakened. |
| Legal name | HARI SHANKAR KHANDELWAL | ✅ | ✅ | |
| Trade name | Shiv Shanker Pashu Aahar Udyog | `Shiv Shanker Paslhu Aahar Udyog` ⚠️ | ✅ | ML Kit misread "Pashu". Kept as read (no dictionary correction); editable. |
| Additional trade names | blank | not captured (null) ✅ | ✅ | Not a form field; never filled |
| Constitution | Proprietorship | ✅ | ✅ | |
| Address | A-6, KABAR MARG, BANI PARK, Jaipur, Rajasthan, 302006 | ✅ (the doubled `,,` is normalized) | ✅ | "KABAR MARG" is uncertain and stays editable |
| State / code | Rajasthan / 08 | ✅ (from the GSTIN) | ✅ | Address names Rajasthan, so the consistency check passes |
| PIN | 302006 | ✅ | ✅ | Not swapped or truncated |
| Date of liability | 01/07/2017 | ✅ | ✅ | |
| Validity start | 01/07/2017 | **null** ⚠️ | ✅ | The phone OCR read the cell as `Jo/O7/2017`. It is left empty and highlighted rather than copied from the liability date. |
| Validity end | Not Applicable | ✅ | ✅ | |
| Registration type | Regular | ✅ | ✅ | |
| Issue date | 16/06/2022 | ✅ (flagged "identified from layout") | ✅ | Not the signature timestamp `2022.06.. 16:16:33` |
| Approving officer | (must not leak) | not in any field ✅ | ✅ | |

**Degraded images** (simulated OCR output, since ML Kit cannot run inside `flutter test`):

| Case | Result |
|---|---|
| Obscured name/address rows | Those fields stay null; the others are unaffected |
| Unrepairable GSTIN | Kept as read and flagged; no other field changed |
| Skewed or out-of-order lines | Still mapped correctly |
| Non-certificate image | No values; the screen shows "does not look like a GST Registration Certificate" |

**Not done:** running ML Kit on the supplied JPEG in this session. That requires a device, and RMSeller's device notes record MIUI blocking adb input.

## 3. Review-screen mapping

The widget test drives the reference capture through the real screen with a fake picker, recognizer and repository.

**Mapping**
- Every value lands in its own controller (§2 values exactly).
- PAN `ADRPK6597J` and state are derived for display.
- The repaired GSTIN shows "Corrected from the OCR reading".
- The empty validity start shows "Not found on the certificate".
- Dates display as `dd/mm/yyyy` throughout.
- Null values stay empty.

**Edits and validation**
- Editing the trade name, then failing validation (bad PIN), then fixing it and submitting twice keeps the edited trade name and PIN unchanged.
- An address in another state (Gujarat) shows the state-mismatch error and blocks the submit notice.

**Replace and Retake**
- Re-reads the new image and **replaces** all values, including earlier edits.
- This is predictable but discards edits. Adding a confirmation before discarding edits is a possible follow-up; it wasn't changed here.

**Error states**
- Loading, OCR failure, picker/permission failure and status-load failure each have their own message. These were covered in the previous sprint and still pass.

**Profile comparison**
- Differences from the stored company name and GSTIN are listed, never written.

## 4. Database field mapping and persistence

**Not tested, because there is no endpoint.**

| Question | Finding |
|---|---|
| Which endpoint saves the submission? | None exists. `GstVerificationRepository.submissionAvailable` is `false`; the screen says "nothing was saved or sent". |
| Which columns receive each value? | None. The intended home is the proposed `buyer_gst_verifications` table (audit §6.2). `GstSubmissionDraft.toPayload()` is the client side of that contract: `submitted`, `ocr`, `edited_fields`. |
| How is status loaded after navigating away? | `BuyerProfileRepository.getProfile()` → `companies.is_verified`, re-read on every open and on refresh. Pending/approved/rejected submission states don't exist in the backend, so they aren't shown. |
| False success on server failure? | Not possible today: no request is made, and the only message after a valid submit is the "not available, nothing saved" notice. |
| Can client code modify `is_verified`, `status`, `trust_score`? | **RMBuyer code: no.** `BuyerProfileRepository` writes only `users.name`/`mobile`, and the draft payload is tested to contain no status, company or reviewer keys. **The database still allows it** for any authenticated user on their own company (F1). That is a backend fix. |
| Hard-coded company ID or client-trusted ownership in this feature? | No. (The separate hard-coded fallback in `requirements_repository.dart`, audit F6, is outside this feature and was not changed.) |

Persistence checks 1–10 from the sprint (server-side company mapping, saved record, duplicate protection, cross-user access, self-approval, pending/rejected display) **remain open until the backend exists**. Running them needs an authorized non-production project; the only Supabase project is production.

## 5. Tests executed

| Command | Result |
|---|---|
| `flutter analyze` | **No issues found** |
| `dart format` on changed files | clean |
| GST unit + widget tests, profile, More, router and settings tests (8 files) | **69 passed** |
| `flutter test test/widget_test.dart test/widgets test/unit` | **381 passed, 4 skipped, 1 failed**. The failure is `test/widgets/chat_screen_test.dart` "send is disabled until text; sending shows a confirmed bubble" (expects a "Today" date label). It also fails on its own; chat code and test are untouched committed files. It's not caused by this sprint, but whether it was already failing wasn't proven, because stashing was not allowed. |
| `flutter build apk --debug` | **Built** |

**Not available:**
- tests for a successful submission response, backend failure or timeout
- reload of a saved submission
- cross-user ownership or RLS tests

There is no endpoint to test, and writing fake ones would only test the fakes.

## 6. Confirmed defects and fixes

1. **Issue date and validity were not extracted** (reference fields missing). **Fixed**, with tests.
2. **No GSTIN-state vs address-state check** (required by the audit design). **Fixed:** an error when the address names a different state; no guess when it names none.
3. **No submission-preparation contract** recording final values, OCR values and edited fields. **Added** `GstSubmissionDraft` and tested that edits survive and that no status/company fields are included. It isn't wired to any request yet.

No mapping, controller or false-success defects were found in the existing screen.

## 7. Remaining limitations and approval-required backend changes

The persistence half needs these approved and applied (SQL design in `RMBUYER-GST-VERIFICATION-01-AUDIT-REPORT.md` §6–§8). **Nothing here was applied.**

1. Revoke `authenticated` UPDATE on `companies.is_verified`, `status`, `trust_score` (and the other protected columns); grant only profile columns.
2. Create the `buyer_gst_verifications` table plus the `buyer_verification_events` audit table, with SELECT-only RLS for the owner and admins.
3. Create the `submit_buyer_gst_verification(jsonb)` SECURITY DEFINER function. It derives the company from `auth.uid()`, repeats the checksum, state and PIN checks, sets `pending` only, and uses a partial unique index for duplicate GSTIN and repeated submits.
4. Create a private bucket `brokerbridge_buyer_gst_certificates` with `{auth.uid()}/…` INSERT and owner/`is_admin()` SELECT policies, a 5 MB limit and jpeg/png only.
5. Provide a non-production Supabase environment, or explicit production approval with a test Buyer and company, to run persistence checks 1–10.

After (2)–(4), the client work is: upload the image, call the RPC with `GstSubmissionDraft.toPayload()` plus the object path, show success only on the RPC's returned row, and read pending/rejected status from the new table.

Other limitations:
- ML Kit has not been run on this JPEG on a device in this session.
- Validity start is unreadable in the current phone capture.
- Replace discards edits.

## Confirmation

No database, RLS, grant, storage or configuration changes were made. No production writes were made, and the live check was read-only metadata. Nothing was committed, pushed or deployed. Unrelated uncommitted work was preserved.
