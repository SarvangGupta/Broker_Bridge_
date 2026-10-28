# MICRO-SPRINT REPORT: RB-SELLER-OCR-FIELD-MAPPING-01
## Supplier Invoice OCR → Seller Profile Field Mapping

**Application:** RMSeller Mobile App (`apps/rmseller_mobile`)  
**Sprint ID:** `RB-SELLER-OCR-FIELD-MAPPING-01`  
**Execution Timestamp:** 2026-10-28T08:42:00+05:30  
**Status:** COMPLETE (Zero Regressions, All Invariants Satisfied, APK Built & Running On-Device)

---

### 1. Executive Summary

This micro-sprint corrected the end-to-end field mapping from business invoice OCR extractions directly into the Seller Profile domain entity (`SellerProfileModel`), form controllers, review dialogs, and local/backend persistence layers.

Crucial domain invariants enforced:
1. **Business Identifier = Firm Name:** Strictly mapped to the supplier's firm name (`companyName` / `firmName`). GSTIN is **never** mapped into this field.
2. **Version Identifier = Form Name:** Form name (`BILL OF SUPPLY`, `TAX INVOICE`) is extracted and mapped when available; never fabricated.
3. **Supplier vs. Buyer Separation:** Full isolation ensured between supplier (header) and buyer (billed-to / consignee) blocks. Buyer GSTIN (`08ADRPK6597J1ZL`) and buyer phone numbers (`9828539054`) are strictly prevented from contaminating supplier fields.
4. **Address Triple-Mapping:** The complete supplier address is mapped across Corporate Office / HQ (`officeAddress`), Location & Street (`businessLocation.addressLine`), and Shop & Godown Address (`businessLocation.name`), without inventing phantom locations.
5. **Bank Details:** Bank Name, Account Number, IFSC, and Bank Branch (`branchName`) are accurately extracted and mapped. Sensitive banking digits remain masked in logs and review views (`•••• •••• •••• 1234`), and are strictly treated as unverified suggestions requiring explicit user confirmation before saving.

---

### 2. Mandatory Field Mapping Verification

| Seller Profile Field | Required Mapping | Siyaram Trading Co. (Hindi) | Bina Enterprises (English) | Status |
|---|---|---|---|---|
| **Supplier / Business Name** | Supplier's business or firm name | `मे० सियाराम ट्रेडिंग कम्पनी` | `BINA ENTERPRISES` | **PASS** |
| **Business Identifier** | **Firm Name (NOT GSTIN)** | `मे० सियाराम ट्रेडिंग कम्पनी` | `BINA ENTERPRISES` | **PASS** (Zero GSTIN) |
| **Version Identifier** | **Form Name** | `BILL OF SUPPLY` | `BILL OF SUPPLY` | **PASS** |
| **GST Number / GSTIN** | Supplier's GSTIN (Never Buyer) | `09EBCPR5003P1Z8` (Supplier) | `08BCIPJ4336H1ZK` (Supplier) | **PASS** |
| **Contact Details → Mobile** | Supplier's mobile number | `9696700510` | `8094689777` | **PASS** |
| **Corporate Office / HQ Address** | Complete supplier address | `मलिकपुर महेवा, भरवारी, कौशाम्बी` | `82, Paraswanath Colony, Nirman Nagar, Jaipur (Raj.)-302019` | **PASS** |
| **Location and Street** | Complete supplier address | `मलिकपुर महेवा, भरवारी, कौशाम्बी` | `82, Paraswanath Colony, Nirman Nagar, Jaipur (Raj.)-302019` | **PASS** |
| **Shop and Godown Address** | Complete supplier address | `मलिकपुर महेवा, भरवारी, कौशाम्बी` | `82, Paraswanath Colony, Nirman Nagar, Jaipur (Raj.)-302019` | **PASS** |
| **State** | Supplier state (PIN-validated) | `Uttar Pradesh` (Circle 09) | `Rajasthan` (Circle 08) | **PASS** |
| **District** | Supplier district (PIN-validated) | `Kaushambi` | `Jaipur` | **PASS** |
| **PIN Code** | PIN code from supplier address | Preserved / Looked up | `302019` | **PASS** |
| **Bank Name** | Supplier's bank name | `बैंक ऑफ बड़ौदा` (Bank of Baroda) | `ICICI Bank` | **PASS** |
| **Account Number** | Supplier's bank account number | `328702000000341` | `674905500169` | **PASS** |
| **IFSC Code** | Supplier's IFSC code | `BARB0BHARWA` | `ICIC0006749` | **PASS** |
| **Bank Branch / Location** | Supplier's bank branch | `भरवारी - कौशाम्बी` | `Nirman Nagar, Jaipur` | **PASS** |

---

### 3. Detailed Technical Changes

#### A. Domain Model Expansion (`lib/features/profile/domain/seller_profile_model.dart`)
- Added explicit fields `final String businessIdentifier;` and `final String versionIdentifier;`.
- Added helper getter `effectiveBusinessIdentifier` which defaults to `companyName` if uninitialized.
- Updated `copyWith`, `fromMap`, and `toMap` to serialize and restore `business_identifier` and `version_identifier`.

#### B. Domain Mapping Engine (`lib/features/profile/domain/invoice_extracted_data.dart`)
- Implemented `SellerProfileModel mapToSellerProfile(SellerProfileModel current)`:
  - Enforces `businessIdentifier = firmName` (strictly preventing GSTIN injection).
  - Enforces `versionIdentifier = documentType` (Form name).
  - Isolates supplier GSTIN and supplier mobile.
  - Reuses supplier address across HQ, Street Address, and Shop/Godown Address.
  - Maps Bank Name, Account Number, IFSC, and Bank Branch.
  - Preserves unchanged values and avoids fabricating missing fields.

#### C. OCR Bank Branch Extraction (`lib/features/profile/data/invoice_ocr_service.dart`)
- Implemented `_extractBankBranch(String text, List<String> cleanLines)` for invoices:
  - Matches explicit branch prefixes: `(?:branch|br\.|शाखा)\s*[:\-]?\s*([A-Za-z0-9\u0900-\u097F ,\-\.]{3,45})`.
  - Parses bank line location separators (e.g. `बैंक : बैंक ऑफ बड़ौदा, भरवारी - कौशाम्बी`).
  - Correctly extracts `भरवारी - कौशाम्बी` for Siyaram and `Nirman Nagar, Jaipur` for Bina.
  - Passed to `InvoiceExtractedData(branchName: ...)`.

#### D. UI Controller Synchronization (`lib/features/profile/presentation/seller_profile_screen.dart`)
- In `_applyExtractedSuggestions`:
  - `_companyController.text = data.firmName!;`
  - `_officeAddressController.text = data.officeAddress!;`
  - `_locationAddressController.text = data.officeAddress!;` (Location & Street)
  - `_locationNameController.text = data.officeAddress!;` (Shop & Godown)
  - `_mobileController.text = data.contactMobile!;`
  - `_bankBranchController.text = data.branchName!;`
- In `_initiateSaveWorkflow`:
  - Populates `businessIdentifier: _companyController.text.trim()`
  - Populates `versionIdentifier: _extractedInvoiceData?.documentType ?? current.versionIdentifier`

#### E. Confirmation Review Sheet (`lib/features/profile/presentation/widgets/profile_review_confirmation_sheet.dart`)
- Displays side-by-side comparison for all modified fields prior to saving.
- Account numbers masked for privacy (`•••• •••• •••• 1234`).
- Explicit confirmation required before any persistent write.

#### F. Secure Persistence Layer (`lib/features/profile/data/seller_profile_repository.dart`)
- Persists `business_identifier` and `version_identifier` both seller-scoped (`business_identifier_$userId`) and globally with fallback.
- Reads and restores them during `getProfile()`.

---

### 4. Test Execution & Results

#### Test Suite 1: `seller_ocr_field_mapping_test.dart` (15/15 Passed)
```
00:00 +1: OCR-MAP-001: Maps supplier firm name to Business Name and Business Identifier (NOT GSTIN)
00:00 +2: OCR-MAP-002: Version Identifier maps to Form Name (BILL OF SUPPLY)
00:00 +3: OCR-MAP-003: Supplier GSTIN maps to GST Number / GSTIN and NEVER buyer GSTIN
00:00 +4: OCR-MAP-004: Supplier mobile maps to contact details and NEVER buyer mobile
00:00 +5: OCR-MAP-005: Supplier address triple-maps to HQ, Location/Street, and Shop/Godown Address
00:00 +6: OCR-MAP-006: Supplier bank details (Bank Name, Account Number, IFSC, Bank Branch) map accurately
00:00 +7: OCR-MAP-007: Unicode Hindi Devanagari text survives full serialization round-trip
00:00 +8: OCR-MAP-008: Maps supplier firm name to Business Name and Business Identifier (NOT GSTIN)
00:00 +9: OCR-MAP-009: Version Identifier maps to Form Name (BILL OF SUPPLY)
00:00 +10: OCR-MAP-010: Supplier GSTIN maps to GST Number / GSTIN and NEVER buyer GSTIN
00:00 +11: OCR-MAP-011: Supplier mobile maps to contact details and NEVER buyer mobile
00:00 +12: OCR-MAP-012: Supplier address, PIN code, state, and district map accurately
00:00 +13: OCR-MAP-013: Bank details map Bank Name, Account Number, IFSC, and Bank Branch / Location
00:00 +14: OCR-MAP-014: Written address conflicting with PIN triggers conflict notice without losing original address
00:00 +15: OCR-MAP-015: Missing or uncertain values are never fabricated and retain current values
All tests passed!
```

#### Test Suite 2: `reference_invoice_benchmark_test.dart` (11/11 Passed)
- All Hindi printed extraction, handwritten buyer separation, arithmetic consistency, and bank details tests continue to pass with 100% success.

#### Test Suite 3: Profile & Invoice Workflow Widget Tests (22/22 Passed)
- `seller_profile_invoice_workflow_test.dart`
- `seller_ocr_intelligence_workflow_test.dart`
- `seller_profile_bilingual_test.dart`
- `seller_cheque_workflow_test.dart`

#### Flutter Analyze
```
D:\flutter_sdk\flutter\bin\flutter.bat analyze lib/features/profile test/unit/seller_ocr_field_mapping_test.dart test/unit/reference_invoice_benchmark_test.dart
Analyzing 3 items...
No issues found! (ran in 12.3s)
```

#### Physical Device Verification
- **Target Device:** Xiaomi Redmi Note 5 Pro (`e0d9da95`, Android 9 / API 28)
- **Built APK:** `build\app\outputs\flutter-apk\app-debug.apk` (41.0s clean Gradle build)
- **Install:** Streamed install succeeded via ADB.
- **Runtime:** Launched and running under process ID `17800` (`com.brokerbridge.rmseller_mobile`).
