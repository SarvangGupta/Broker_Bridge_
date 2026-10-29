# RB-SELLER-GST-CERTIFICATE-PROFILE-01 — GST Certificate Upload & Profile Auto-fill

**Date:** 2026-10-28 · **App:** RMSeller · **Branch:** `feature/broker-nilesh` (uncommitted) · **Scope:** Seller Profile only

**Production statement:** there were no schema changes, no migration, no RLS or auth changes, and no production data writes. `harishanker` and other real accounts were not used.

## What was built

In **Profile → Edit Profile**, a new card below *Scan Business Invoice*:

- **Checkbox:** **"I have a GST Registration Certificate"** (`chk_has_gst_certificate`). Unchecking only hides the section; it never clears form values, saved data or documents. The card states that this is *not* GST verification.
- **Upload:** **Camera / Gallery / PDF-File** via the existing document service, which supports images and PDF (first 2 pages rendered).
- **Preview:** image thumbnail (or PDF icon) plus file name, with **Replace / Remove**. Remove only drops the unsaved certificate draft.
- **Extraction:** real on-device OCR (the existing ML Kit pipeline, `InvoiceOcrService.recognizeRawTextFromFile`), then the new `GstCertificateParser`.
- **Review panel:** all six values (Legal Name, Trade Name, GSTIN, Principal Place, Jurisdictional Office (internal), Issue Date (internal)), plus review notes.
- **Godown checkbox:** **"The principal place of business is also my shop/godown address"**, unchecked by default.
- **Fill profile fields:** fills the editable form only. Saving still requires **Save → Confirm and Save** (the existing confirmation sheet). The success message is shown only after `updateProfile` returns.

### Field mapping

| Certificate field | Destination |
|---|---|
| Legal Name | Full Name |
| Trade Name, if any | Business Name. If absent, the Legal Name is suggested instead. |
| Registration Number | GSTIN, verified with the GSTIN check character |
| Address of Principal Place of Business | Corporate Office HQ Address, complete |
| PIN in that address | State / District via the India Post directory and live master (the existing rules). Street address + PIN go to the shop/godown section **only** if the godown box is ticked. |
| Jurisdictional Office | `jurisdictional_office`, **hidden** |
| Date of issue of Certificate | `gst_certificate_issue_date`, **hidden** |

The approving authority's name and designation are never mapped. Email and mobile are untouched. Values missing from the certificate keep the existing profile values.

### Hidden fields: storage and visibility (no migration needed)

- **Model:** the fields were added to `SellerProfileModel` (`jurisdictionalOffice`, `gstCertificateIssueDate`; `toMap` / `fromMap` / `copyWith`).
- **Storage:** they follow the **existing convention for non-schema seller fields** (bank details, commodity expertise). They are written to the seller's own **Supabase auth `user_metadata.gst_certificate`** and to local secure storage. Auth metadata is readable only by that user (and by service-role/admin), not through table RLS, so it can't appear in listings or broker cards. **No database schema change, migration or RLS change was needed.**
- **Visibility:** not shown in the profile summary, the editable field list, or the confirmation diff. They are shown only in the pre-apply review panel, so the seller sees what will be stored. `SellerProfileModel.toMap()` is not used by any listing or broker payload (checked by search).

## Reference certificate: real on-device OCR

- **How it was run:** ML Kit was run on the supplied REG-06 on the Redmi Note 5 Pro, through a temporary probe build (no taps; the probe has been deleted). The raw output (42 lines) is stored verbatim as the test fixture in `test/unit/gst_certificate_extraction_test.dart`.
- **Labels and values come out as separate columns.** All labels are emitted first, then the values in a different order (e.g. "Superintendent" before "Rajendra Singh Shekhawat"). Label-to-value same-line matching therefore can't work. The parser uses same-line labels when present (text PDFs), otherwise each value's shape:
  - **Names:** the constitution anchors them; the name lines directly above it are the Legal Name and Trade Name.
  - **Address:** the line with the PIN.
  - **Jurisdictional office:** Circle / Ward / Range terms.
  - **Dates:** see the issue-date row below.
- **GSTIN misread** as `08AWIPG6115A1ZO` (letter O for the final digit 0). It was checked against the source image and the GSTIN check-character algorithm (mod-36): `08AWIPG6115A1Z0` is valid and `…ZO` is not. The parser repairs O↔0 / I↔1 only when exactly one variant passes the check, and **flags the correction for review**.

| Field | Expected | Raw OCR | Mapped | Result |
|---|---|---|---|---|
| Legal Name | Raghuveer Prasad Goyal | `Raghuveer Prasad Goyal` | same → Full Name | PASS |
| Trade Name | Piyush General Store | `Piyush General Store` | same → Business Name | PASS |
| Registration Number | 08AWIPG6115A1Z0 | `08AWIPG6115A1ZO` | `08AWIPG6115A1Z0` (checksum repair, flagged) | PASS, review note |
| Principal Place | B-391, Shanti Nagar, Gurjer Ki Thadi, Jaipur, Rajasthan, 302019 | `…Shanti Nagar. Gurjer…` | exact expected text (OCR full stop → comma) | PASS |
| PIN / State / District | 302019 | — | 302019 → Rajasthan / Jaipur | PASS |
| Jurisdictional Office | Circle-A, Jaipur - Ward-2 | `Circle-A, Jaipur- Ward-2` | `Circle-A, Jaipur - Ward-2` | PASS |
| Issue date | 23/07/2020 | standalone `23/07/2020` | 23/07/2020 (latest date that is not the liability date or the validity "From"; flagged as layout-inferred) | PASS, review note |
| Date of Liability not used | 16/07/2020 | `16/07/2020`, `16/07/2020 To` | excluded | PASS |

## Tests (all executed)

| Suite | Result |
|---|---|
| `test/unit/gst_certificate_extraction_test.dart` (new) | **25/25**. Both the real on-device OCR and reading-order text; GSTIN checksum and repair; Trade Name fallback; a single date gives no issue date (flagged); a non-certificate gives nothing; `applyToProfile` with and without godown; hidden fields round-trip. |
| `test/widgets/seller_gst_certificate_workflow_test.dart` (new) | **9/9**. Checkbox on/off keeps values and invoice scanning stays available; upload → preview + file name → extracted values → fill; nothing saved before confirmation; godown → street, PIN, Jaipur; seller correction saved; hidden fields persisted and **not displayed after reopen** (all sections expanded); cancel saves nothing; extraction failure keeps manual editing; server failure keeps the draft and stores nothing; Remove; Hindi labels. |
| Full RMSeller `test/unit` + `test/widgets` | **517 passed, 16 failed.** The 16 are identical to the pre-existing HEAD failures, so there are **0 new regressions** (including all invoice-OCR, PIN, Hindi/Unicode and profile suites). |
| `flutter analyze` (profile feature + new tests) | No issues |
| Debug APK | Builds. Reinstalled on the device (`install -r`, app data kept). |

Issues found and fixed during testing:
- A `CheckboxListTile` inside the card's decorated background hid ink effects (Flutter assertion). It is now wrapped in a transparent `Material`.
- A duplicate `removeDocument` string was removed; the existing one is reused.

## Not done / blocked

- **Server-confirmed save and reopen:** BLOCKED. There is still no staging project or dedicated test account (see `RB-SELLER-OCR-STAGING-01-REPORT.md`). Persistence was verified through the real screen and repository against local storage only.
- **Device UI screenshots:** BLOCKED. ADB input is still disabled (`persist.security.adbinput = 0`), so the UI could not be driven. No screenshots were taken.
- **Hidden-field server write:** like bank details, the `user_metadata` write happens in the existing `try/catch` that only logs on failure. If the metadata call fails, the core profile save still reports success and the two hidden fields stay local until the next save. Making it fail the save would change existing bank-details behaviour too, so it was left for your decision.

## Files

| Change | File |
|---|---|
| Added | `lib/features/profile/data/gst_certificate_parser.dart` |
| Added | `lib/features/profile/domain/gst_certificate_extracted_data.dart` |
| Changed | `lib/features/profile/data/invoice_ocr_service.dart` (`extractGstCertificateFromFile` / `FromText`, result type) |
| Changed | `lib/features/profile/domain/seller_profile_model.dart` (2 hidden fields) |
| Changed | `lib/features/profile/data/seller_profile_repository.dart` (load/save of hidden fields: storage + user_metadata) |
| Changed | `lib/features/profile/presentation/seller_profile_screen.dart` (GST card, handlers, save wiring, `_applyStateDistrict` reuse) |
| Changed | `lib/features/profile/presentation/profile_strings.dart` (English/Hindi strings) |
| Added | `test/unit/gst_certificate_extraction_test.dart`, `test/widgets/seller_gst_certificate_workflow_test.dart` |
