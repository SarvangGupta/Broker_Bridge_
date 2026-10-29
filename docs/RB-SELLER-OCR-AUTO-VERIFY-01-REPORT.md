# RB-SELLER-OCR-AUTO-VERIFY-01 — Supplier-Only OCR Verification Report

**Date:** 2026-10-28 · **App:** RMSeller (debug build, branch `feature/broker-nilesh`, uncommitted) · **Device:** Redmi Note 5 Pro (`e0d9da95`)
**Invoice:** Siyaram Trading Company, Bill of Supply No. 11. Scope is **supplier fields only**; buyer details are not assessed.

## How OCR was run

- **Genuine on-device OCR:** the app's own `InvoiceOcrService.extractFromFile` (Google ML Kit, Devanagari model) ran on the original invoice image, on the device. It was followed by the app's real mapper, `InvoiceExtractedData.mapToSellerProfile`.
- **No UI driving:** ADB input injection is blocked on this phone (MIUI "USB debugging (Security settings)" is off). Every `input tap` was silently ignored, so the Profile → Scan Invoice UI could not be driven. Instead, OCR ran from a temporary probe entrypoint built into the app package. The probe has since been deleted.
- **Raw OCR output:** saved verbatim to `ocr_verify/raw_ocr_siyaram.txt` (session scratchpad). It is also the fixture in `test/unit/siyaram_real_ocr_supplier_test.dart`.

## Defect found by the real OCR run (fixed)

ML Kit emits text blocks **out of reading order**. The handwritten buyer block (`मेसर्स …`, `पता …`, `शहर …`) came out as lines 1–3, before the printed supplier header. The previous supplier/buyer split assumed the buyer section comes below the supplier header. As a result, the first real run mapped:

| Field | First-run value | Problem |
|---|---|---|
| Full Name / Business Name | `श.शकर...्शE 5] ..` | Buyer text |
| HQ Address | `..K..A.,...प, शहर ..c1 पु र., क्र.स., १` | Buyer `पता` block |
| Bank Name | (empty) | OCR read `बैंक अफ बड़ौदा` without `ऑ` |

Fixes in `invoice_ocr_service.dart`:

1. **Firm name:** taken first from the supplier's signature line (`वास्ते-…` / `For …`), which does not depend on OCR order.
2. **Buyer block:** now detected as the buyer header plus its form lines wherever they appear. Supplier name, address, PIN and email skip those lines.
3. **PIN:** item rows and totals (`योग 336600`) are no longer accepted as PIN candidates.
4. **Bank name:** Hindi bank names are matched on consonant skeletons, so a dropped vowel sign still matches.
5. **Honorific:** the firm name keeps `मे०` / `M/s` as printed.

## Results — second on-device run (after fix)

| Field | Expected | Raw OCR evidence | Mapped value | Result | Category |
|---|---|---|---|---|---|
| Full Name | मे० सियाराम ट्रेडिंग कम्पनी | `मे0 सियाराम द्रेडिंग कम्पनी`; `वास्ते-मे० सियाराम द्रेडिंग कम्पनी` | मे० सियाराम द्रेडिंग कम्पनी | REVIEW REQUIRED | OCR (ट read as द); mapping correct |
| Business Name | same | same | मे० सियाराम द्रेडिंग कम्पनी | REVIEW REQUIRED | OCR (ट→द) |
| Mobile Number | 9696700510, 9919808347 | `मो० : 9696700510, 9919808347` | 9696700510; 9919808347 kept as second supplier candidate | PASS | Field holds one number |
| Email | Preserve existing | No email on invoice | Existing email unchanged | PASS | — |
| GSTIN | 09EBCPR5003P1Z8 | `GSTIN : 09EBCPR5003P1Z8` | 09EBCPR5003P1Z8 | PASS | — |
| Corporate Office HQ Address | मलिकपुर महेवा, भरवारी, कौशाम्बी, उत्तर प्रदेश | `मलिकपुर महेवा, भरवारी, कौशाम्बी मो० : …` | मलिकपुर महेवा, भरवारी, कौशाम्बी | REVIEW REQUIRED | "उत्तर प्रदेश" is not printed and is not appended |
| Location Name | Supplier firm name | — | मे० सियाराम द्रेडिंग कम्पनी | PASS (mapping), OCR caveat as above | — |
| PIN Code | Blank unless printed | No supplier PIN printed | Not extracted (null); existing value kept | PASS | — |
| District | Kaushambi | `कौशाम्बी` in address | Not populated | REVIEW REQUIRED | Field mapping: district comes only from PIN; the directory has English names only |
| Street / Mandi / Area | Complete supplier address | as above | मलिकपुर महेवा, भरवारी, कौशाम्बी | PASS | — |
| Bank Name | Bank of Baroda | `बैंक : बैंक अफ बड़ौदा, …` | बैंक ऑफ बड़ौदा | PASS | — |
| Account Number | 328702000000341 | `আता सं० - 32870200000341` (14 digits) | 32870200000341 | REVIEW REQUIRED | OCR: 14 digits read versus 15 expected |
| IFSC Code | BARB0BHARWA (verify manually) | `FSC कोड - BARB0BHARWA` | BARB0BHARWA | REVIEW REQUIRED | Printed code may be incomplete (per spec) |
| Bank Branch | Bharwari – Kaushambi | `…, भरवारी - कौशाम्बी` | भरवारी - कौशाम्बी | PASS | — |

**Overall:**

| Result | Count | Fields |
|---|---|---|
| PASS | 8 | Mobile, Email, GSTIN, Location Name, PIN, Street, Bank Name, Branch |
| REVIEW REQUIRED | 6 | Full Name, Business Name, HQ Address, District, Account Number, IFSC |
| FAIL | 0 | — |
| BLOCKED (UI / persistence) | — | See screenshots below |

Supplier values never came from buyer data.

## Screenshot evidence

All files are in the session scratchpad folder `ocr_verify/`.

| File | Status |
|---|---|
| `01_home_before_scan_existing_profile.png` | Captured (1080×2160, opens). This is the Home screen, not Profile; the Profile screen couldn't be reached because taps are blocked. It shows the pre-fix stored Business Name `GSTIN : 09EBCPR5003P1Zz8`. |
| `02_invoice_selected.png` – `06_supplier_profile_after_reopen.png` | **BLOCKED**: ADB input injection is disabled on the device. |

## Save / persistence

**BLOCKED.** It requires driving the UI. No profile save was performed, and no production data was written.

## Build and tests

- **Debug APK:** builds and installs (`flutter build apk --debug`).
- **Tests:** 15 OCR/profile unit and widget test files, **126/126 passed**. This includes the new `siyaram_real_ocr_supplier_test.dart`, which uses the real ML Kit output as its fixture.
- **Analyze:** `flutter analyze` on the changed code: no issues.
- **Assertion updates:** existing assertions that expected the honorific to be stripped were updated to keep `मे०`, as this spec requires.

## Remaining limitations

1. **OCR character errors:** errors such as ट→द in the firm name, and the 14-digit account number, can't be corrected without inventing data. The seller must correct them in the review step.
2. **District:** not derived when no PIN is printed. Hindi-script district matching needs a Devanagari district reference that the app doesn't have.
3. **Mobile field:** holds one number. The second supplier number is only kept as a candidate.
4. **UI flow not verified on device:** to unblock it, enable *Developer options → USB debugging (Security settings)* on the phone, then re-run steps 01–06 and the save/reopen on the test account.
