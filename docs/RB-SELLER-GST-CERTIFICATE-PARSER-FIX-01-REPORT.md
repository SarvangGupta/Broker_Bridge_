# RB-SELLER-GST-CERTIFICATE-PARSER-FIX-01 — "Not found on certificate" fix

**Date:** 2026-10-28 · **App:** RMSeller · **Branch:** `feature/broker-nilesh` (uncommitted) · **Scope:** GST REG-06 parser only

**Production statement:** there were no schema, RLS, auth or production-data changes, and no profile was saved.

## Diagnosis on the real pipeline

1. **Reference document:** `/sdcard/Download/GST.jpg`, a phone photo of an *Amended* REG-06 for 08ADRPK6597J1ZL, saved on the test phone at 11:31. A passive screenshot showed it loaded in the app as `scaled_GST.jpg`.
2. **Image picker ruled out:** the picker caps width at 1920 px and the photo is 1080×1440, so it is only re-encoded (JPEG quality 85), not downscaled.
3. **OCR:** genuine on-device ML Kit (Devanagari + Latin) was run through the app's `recognizeRawTextFromFile`, via a temporary probe build, with your permission to use the phone. The probe was deleted and the normal app reinstalled afterwards. The verbatim 53-line output is the fixture in `test/unit/gst_certificate_amended_photo_test.dart`.

**Result: OCR recognised every needed value. The failure was in the parser (the earliest responsible stage)**, not the OCR engine, the field model, or the UI fallback.

| Field | Genuine OCR line | Why the old parser returned nothing |
|---|---|---|
| Legal Name | `\|HARI SHANKAR KHANDELWAL` | The table-border `\|` glued to the value failed the name-shape check. |
| Constitution (anchor for both names) | `\|Proprietorship` | `^proprietorship` did not match with the leading `\|`, so the name anchor was never found. |
| Trade Name | `Shiv Shanker Paslhu Aahar Udyog` | Never reached. The emblem motto, OCR'd as Devanagari noise (`ाथगेय जग)`), also sat between the names and the constitution and stopped the upward scan. |
| Issue date | `\|16/06/2022` | The "standalone date line" test failed because of the `\|`. |
| GSTIN | `08ADRPK6S97J1ZL` (`S` for `5`) | Already handled: repaired by the check character and flagged. |
| Address | `\|A-6, KABAR MARG,, BANI PARK, Jaipur, Rajasthan, 302006` | Found, but kept the `\|` and the printed `,,`. |

## Fix (`lib/features/profile/data/gst_certificate_parser.dart`)

- **Table borders:** leading and trailing `|` / `¦` are stripped from every OCR line before parsing.
- **Name scan:** the upward scan from the constitution skips lines with fewer than 3 Latin letters (seal and motto noise) but still stops at any real label or value. Names can never be pulled from further away.
- **Label variants:** `Additional trade names, if any` and `Date of Validity` are recognised as labels, so they are never treated as values.
- **Normalisation:** repeated commas in the address (`,,` → `,`) and slash spacing in the jurisdictional office (`AC/ CTO` → `AC / CTO`). Words are never changed.
- **Unchanged:** GSTIN check-character repair (still flagged for review), the date rules (issue date ≠ liability, validity, or signature timestamp), the "not GST verification" wording, and the rule that a field it cannot identify stays empty.

## Results on the real OCR (all executed)

| Field | Expected | Extracted | Result |
|---|---|---|---|
| Legal Name | HARI SHANKAR KHANDELWAL | HARI SHANKAR KHANDELWAL | PASS |
| Trade Name | Shiv Shanker Pashu Aahar Udyog | **Shiv Shanker Paslhu Aahar Udyog** | **REVIEW REQUIRED.** ML Kit misread "Pashu" as "Paslhu"; the parser picks the correct row and keeps OCR text unaltered. The seller corrects it in the editable Business Name field (covered by a test). |
| GSTIN | 08ADRPK6597J1ZL | 08ADRPK6597J1ZL (repaired from `…6S97…`, flagged) | PASS + review note |
| Principal place | A-6, KABAR MARG, BANI PARK, Jaipur, Rajasthan, 302006 | same | PASS |
| PIN / State / District | 302006 / Rajasthan / Jaipur | same | PASS |
| Constitution | Proprietorship | Proprietorship | PASS |
| Jurisdictional Office | Circle-H, Jaipur I, AC / CTO Ward | same | PASS |
| Issue date | 16/06/2022 | 16/06/2022 | PASS |
| Not liability / validity / signature date | 01/07/2017, `2022.06.16 16:16:33` | not used | PASS |

## Tests

| Suite | Result |
|---|---|
| `test/unit/gst_certificate_amended_photo_test.dart` (new, real OCR fixture) | **10/10.** Covers required tests 1–10: names not swapped; the empty "Additional trade names" row is ignored; the approving authority never becomes the seller; with names and date removed, fields stay null and a review note is raised. |
| `test/unit/gst_certificate_extraction_test.dart` (previous certificate, real OCR) | **25/25**, still passing. |
| `test/widgets/seller_gst_certificate_workflow_test.dart` | **10/10.** New #12: the review panel shows all six values and **no "Not found on certificate"**; the seller can correct "Paslhu" → "Pashu" before saving. |
| Full RMSeller `test/unit` + `test/widgets` | **528 passed, 16 failed.** The 16 are identical to the pre-existing HEAD failures, so there are **0 new regressions**. All invoice-OCR and Hindi suites pass. The two invoice-named failures are the pre-existing `invoice_details_screen_test.dart` (sales-invoice screen, not OCR). |
| `flutter analyze` | No issues |

## UI evidence: BLOCKED

ADB input is still disabled on the phone (`persist.security.adbinput = 0`), so the app cannot be driven to the review panel. **No post-fix review-screen screenshot exists.**
- A passive pre-fix screenshot of your own session is in the session scratchpad (`gst2/_user_screen.png`).
- The fixed build is installed on the phone, so if you scan `GST.jpg` again I can capture the review panel passively, without input.

## Minor UI note (not changed; out of scope)

In the certificate preview row, the long "Remove Document" label squeezes the file name ("scaled_GST.j / pg" wraps).
