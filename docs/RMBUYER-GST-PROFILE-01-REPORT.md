# RMBUYER-GST-PROFILE-01 — GST Certificate Upload, OCR Autofill and Verification Status

**Date:** 2026-10-29 · **Branch:** `feature/broker-nilesh` (uncommitted, nothing pushed)

## Status: PASS WITH LIMITATIONS — submission is BLOCKED on a backend dependency

Everything a Buyer does on the device works:
- open **More → GST Verification**
- see the real backend status
- take or choose a certificate photo, with preview and Retake/Replace
- on-device OCR
- review and correct the extracted values, with missing and edited fields flagged
- client-side validation, including the GSTIN check character

**Submit for Verification does not save anything.** No authorized backend path exists to store the certificate or a submission status (details in "Backend dependency" below). After a successful validation the screen says so plainly: *"Online submission is not available yet… nothing was saved or sent. Your status remains Not Verified."* It never shows a success message.

## Files changed (RMBuyer only)

| File | Change |
|---|---|
| `lib/features/profile/domain/gst_certificate_data.dart` | **New.** `GstinRules` (format, mod-36 check character, PAN/state derivation), GST state-code map, `GstCertificateData`, `GstSubmissionValidation` |
| `lib/features/profile/data/gst_certificate_parser.dart` | **New.** REG-06 parser ported from RMSeller |
| `lib/features/profile/data/gst_certificate_ocr_service.dart` | **New.** On-device ML Kit (Latin script) wrapper with an injectable recognizer. Never logs the recognized text. |
| `lib/features/profile/data/gst_verification_repository.dart` | **New.** Read-only status from the existing `BuyerProfileRepository`. `submissionAvailable = false`. |
| `lib/features/profile/presentation/gst_verification_screen.dart` | **New.** Status, upload and review screen |
| `lib/features/home/presentation/more_screen.dart` | Added the "GST Verification" tile |
| `lib/app/router/app_router.dart` | Added the `/gst-verification` route |
| `pubspec.yaml` / `pubspec.lock` | Added `image_picker ^1.2.4` and `google_mlkit_text_recognition ^0.17.1` (same versions as RMSeller) |
| `ios/Runner/Info.plist` | Camera and photo-library usage strings, required by image_picker |
| `test/unit/gst_certificate_test.dart`, `test/widgets/gst_verification_screen_test.dart` | **New tests** |

No other files were touched. Existing uncommitted work in RMSeller and elsewhere was preserved.

## Components reused

- **OCR and parser:** RMSeller's `GstCertificateParser` and its mod-36 `isValidGstin` / `repairGstin` (O↔0, I↔1 repair using the check character). It is **ported** rather than shared (audit decision D9 is still open). The India Post PIN directory was left out, so the state comes from the GSTIN state code. Registration-type extraction was added.
- **Engine and picker:** the same ML Kit and image_picker versions RMSeller ships.
- **Status reads:** the existing `BuyerProfileRepository.getProfile()`, which reads `users` plus `companies(id, name, gst, is_verified)`.
- **Widgets:** the existing `AppCard`, `AppButton` and `AppErrorState`.
- **PDF:** not supported. RMBuyer has no PDF upload or processing path, so PDF stays out per the sprint rule.

## Fields

Extracted, shown for review and editable:
- GSTIN
- legal name
- trade name
- constitution
- principal-place address
- PIN code
- registration date (Date of Liability)
- registration type

Derived for display only: **PAN and state from the GSTIN**. No PAN field was added.

**Nothing on the profile is populated or overwritten.** The screen lists where the reviewed values differ from the stored profile ("Company name: X → Y", "GSTIN: (empty) → …") but does not write them. The Buyer app's existing rule is that it "never writes the company record", and the only path that could is the unsafe `companies` self-update policy (see below).

**Smallest field addition the backend needs:** none of trade name, constitution, address, PIN, registration date/type, OCR values, edited-field flags, certificate reference, or submission status has a home in the live schema. They belong in the proposed `buyer_gst_verifications` table (audit report §6.2), not as new `companies` columns.

## Verification status source

`companies.is_verified`, read through `BuyerProfileRepository`:
- `true` → **Verified**
- `false` → **Not Verified** with upload
- no company → **Not Verified** with a "contact support" message

A failed read shows an error, never a status. Refresh is available from an app-bar button and by pulling down.

The existing Edit Profile screen already shows the same real value (`profile-verification`), so no change was needed there.

**Pending** ("Submitted — Awaiting Verification") and **Rejected** with a reason **cannot be shown**, because the backend stores neither. They are not inferred from OCR, GSTIN validity or an upload.

**Caveat:** `companies.is_verified` is itself buyer-writable today (audit finding F1), so "Verified" reflects the stored value, not proof of a review.

## Backend dependency (why submission is blocked)

Checked against the live schema in RMBUYER-GST-VERIFICATION-01 (read-only):

1. **No submission or status record.** There is no verification table and no pending/rejected/reviewer fields.
2. **No Buyer certificate storage.** The only private buckets belong to deals, lab evidence and seller invoices. Their INSERT policies accept any path from any signed-in user. Putting a Buyer certificate in the seller-invoice bucket would misuse it, and its read policy is keyed on company ID rather than the owner.
3. **The only company-write path is unsafe.** `"Users can update their own company"` plus column-wide UPDATE lets a Buyer set `is_verified`. The app does not use it and never sends `is_verified`.

**Smallest backend fix needed (requires your approval; nothing was applied):**
- (a) Revoke the column-wide `companies` UPDATE from `authenticated`, so `is_verified`, `status` and `trust_score` are not client-writable.
- (b) Create the `buyer_gst_verifications` table plus the `submit_buyer_gst_verification` SECURITY DEFINER RPC, which sets status `pending` only.
- (c) Create a private bucket `brokerbridge_buyer_gst_certificates` with `{auth.uid()}/…` INSERT/SELECT policies (owner plus `is_admin()`).

These are audit report §6–§8. Once (b) and (c) exist, the client change is small: upload the image, call the RPC with the reviewed values, the OCR values and the edited fields, and show the pending status from the new row.

## Tests and results

| Run | Result |
|---|---|
| `flutter analyze` | **No issues found** |
| `dart format` (new files only; the package is not fully formatted) | Clean |
| `test/unit/gst_certificate_test.dart` + `test/widgets/gst_verification_screen_test.dart` + existing `profile_screen_test.dart`, `buyer_profile_test.dart` | **30 passed** |
| Existing `navigation_shell_test`, `settings_language_test`, `route_guard_test` (touch More and the router) | **19 passed** |
| `flutter build apk --debug` (checks the new native ML Kit and picker plugins) | **Built** |
| Full RMBuyer `test/widgets test/unit` run | **Not run.** The permission classifier denied it. Please run `flutter test test/widget_test.dart test/widgets test/unit` yourself. |

Coverage maps to the sprint checklist:
- the menu tile appears
- a backend-verified company shows Verified with no upload
- an unverified company shows both options
- camera and gallery each call the picker
- OCR fills all 8 fields plus the derived PAN and state
- edits are kept and flagged "Edited by you"
- missing fields are flagged "Not found on the certificate"
- a bad check character and an empty required field show errors
- a valid submit shows the "nothing was saved" notice, stays Not Verified and makes **zero profile writes**
- unreadable images and picker failures show errors
- refresh re-reads the backend
- a failed load shows an error, not a status

Unit tests cover the checksum (correct and wrong), malformed and empty input, PAN and state derivation, validation errors, labelled REG-06 extraction, O→0 repair being flagged, and missing fields staying null.

All test certificates are **synthetic** (fictitious PAN `ABCDE1234F`, generated check character). No real certificate was used. No test touched the network or the production database.

**Not verified on a device:** the real camera and gallery, and ML Kit accuracy on real photos. The device notes for RMSeller say OCR block order on real photos is unreliable, so a device pass with an authorized sample is recommended.

## Confirmation

No database, RLS, grant, trigger, storage or production configuration changes were made. Nothing was committed, pushed or deployed. Awaiting approval of the backend fix above before submission can be completed.
