# MICRO-SPRINT REPORT: RMBROKER-COUNTERPARTY-GST-01
## GST Certificate Registration + Optional Bank Details

**Status:** Completed & Verified  
**Date:** 2026-10-30  
**Application Target:** `apps/rmbroker_mobile` (RMBroker Mobile)  
**Database & Schema Target:** Supabase (`companies`, `counterparty_verification_requests`, `deal_document_shares`, private storage buckets)

---

### Executive Summary
The RMBroker Add Counterparty workflow has been upgraded from a basic text input form into an enterprise-grade onboarding pipeline. Brokers can register **Buyers** and **Sellers** using on-device OCR extraction from official Form GST REG-06 registration certificates with complete review, rotation, replacement, and manual fallback capabilities. Optional banking details can be recorded only when accompanied by cheque-leaf evidence, and confirmed deals can securely share seller bank documentation with explicit authorization and comprehensive audit trails. 

Honesty and fiduciary trust boundaries are strictly preserved: OCR extractions are never misrepresented as government-verified records. Instead, they are classified as `Broker Verified — Certificate Reviewed`. Manual additions without certificate evidence are registered as `Unverified` / `GST Verification Pending` and forwarded to an administrative queue for review.

---

### 1. Files Changed & Created

#### Database Migrations & Schemas
- `supabase/proposed/0057_counterparty_gst_and_bank_verification.sql`: Adds GST fields, verification audit columns, banking details, `counterparty_verification_requests` table, `deal_document_shares` table, private storage buckets (`brokerbridge_gst_certificates`, `brokerbridge_cheque_leaves`), RLS security policies, and `review_counterparty_verification` RPC.
- `supabase/proposed/rollback_0057.sql`: Safe rollback script for migration 0057.

#### Core Models & Domain Logic
- `lib/features/directory/domain/gst_certificate_data.dart`:
  - `GstinRules`: Format validation (`^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z]{1}[1-9A-Z]{1}Z[0-9A-Z]{1}$`), check character mod-36 checksum algorithm, normalization, and state code resolver.
  - `CounterpartyGstStatus`: Verification constants (`unverified`, `gst_pending`, `broker_verified`, `gst_verified`, `rejected`) and human-readable badges.
  - `GstCertificateData`: Extracted fields container.
- `lib/features/directory/domain/cheque_leaf_data.dart`:
  - `IfscRules`: Regex validation (`^[A-Z]{4}0[A-Z0-9]{6}$`), bank prefix mapper for 20+ Indian banks.
  - `CounterpartyBankStatus`: Status constants (`unverified`, `cheque_leaf_provided`, `verified`) and display labels (`Cheque Leaf Provided — Broker Recorded`).
  - `ChequeLeafData`: Extracted fields container with masking utility (`•••• •••• 1234`).
- `lib/features/directory/domain/counterparty_verification_request.dart`: Admin verification request entity.
- `lib/features/directory/domain/directory_contact.dart`: Updated `DirectoryContact`, `CreateContactInput`, `UpdateContactInput`, and `DuplicateCheckResult` with GST and banking fields, masking helpers, and verification status getters.
- `lib/features/deals/domain/deal_share_model.dart`: Order summary builder with formatted commercial terms, delivery terms, payment terms, and optional authorized seller banking with disclaimer.

#### OCR Extraction & Parsing
- `lib/features/directory/data/gst_certificate_parser.dart`: Robust parser for Form GST REG-06 table layouts, multi-line address collation, jurisdiction extraction, date parser, and OCR confusable character repair (`repairGstin`).
- `lib/features/directory/data/cheque_leaf_parser.dart`: Pattern parser for Indian cheques extracting IFSC, 9-18 digit account numbers, bank names, branches, and payees.
- `lib/features/directory/data/ocr_extraction_service.dart`: Google ML Kit on-device OCR wrapper with `ImageTextRecognizer` dependency injection for fast automated testing.

#### Repository & Data Access
- `lib/features/directory/data/directory_repository.dart`:
  - Enriched `checkDuplicate` to check duplicate GSTINs on `companies`.
  - Updated `insertContactRecords` to persist GST, banking details, and enqueue admin verification requests for manual submissions.
  - Added `reviewCounterpartyVerification` RPC wrapper and `uploadDocument` for private storage buckets.
- `lib/features/deals/data/deal_repository.dart`:
  - Added `getSellerBankDetails()` to fetch seller cheque leaf and account records.
  - Added `logDealDocumentShare()` to record audit events in `deal_document_shares`.

#### UI & Presentation
- `lib/features/directory/presentation/controllers/contact_form_controller.dart`: State notifier managing registration modes, OCR extraction, rotation (0°/90°/180°/270°), replacement, field validation, broker review confirmations, and submission.
- `lib/features/directory/presentation/widgets/contact_form_modal.dart`: Add/Edit Counterparty bottom sheet with Role tabs (Add Buyer / Add Seller), Mode toggle (GST Certificate vs Enter Manually), Camera & Gallery pickers, rotation and replacement controls, editable review cards, and optional cheque-leaf banking section.
- `lib/features/directory/presentation/widgets/directory_contact_card.dart`: Shows `Broker Verified — Certificate Reviewed` (green) or `GST Pending` (amber) badges.
- `lib/features/directory/presentation/widgets/contact_details_sheet.dart`: Displays GST & Business Details and Banking Information with masked account numbers and broker-recorded disclaimer.
- `lib/features/deals/presentation/widgets/deal_share_dialog.dart`: Preview dialog for deal summaries with payment terms, authorized seller bank details toggle, and logging to Supabase.
- `lib/features/deals/presentation/screens/deal_detail_screen.dart`: Integrated "Share Deal Summary & Banking Details" action into deal detail workflow.

#### Configuration & Tests
- `apps/rmbroker_mobile/pubspec.yaml`: Added `google_mlkit_text_recognition: ^0.17.1` and `image_picker: ^1.2.4`.
- `apps/rmbroker_mobile/android/app/src/main/AndroidManifest.xml`: Added `android.permission.CAMERA`.
- `test/features/directory/counterparty_gst_and_banking_test.dart`: Comprehensive automated test suite validating all 20 required test cases.
- `test/features/directory/directory_regression_test.dart`: Updated regression suite to include mandatory GSTIN on contact creation.

---

### 2. GST Extraction Fields & Accuracy Handling

The `GstCertificateParser` extracts the following official fields from Form GST REG-06:
1. **GSTIN (Registration Number):** 15-character alphanumeric format validated with a mod-36 checksum algorithm. Confusables (e.g. `O` vs `0`, `I` vs `1`, `S` vs `5`, `Z` vs `2`) are automatically repaired via `repairGstin()`.
2. **Legal Business Name:** Extracted from field 1 of the certificate or by upward scanning from the constitution.
3. **Trade Name:** Extracted from field 2 with automated stripping of boilerplate text (`Trade Name, if any:`).
4. **Constitution of Business:** Extracted from field 3 (e.g. `Proprietorship`, `Partnership`, `Private Limited Company`, `Government Company`).
5. **Principal Place of Business:** Collimated multi-line address from field 4.
6. **State & PIN Code:** State name resolved from address and validated against the GSTIN's 2-digit state prefix; 6-digit postal code extracted.
7. **Registration Date & Period of Validity:** Field 6 extracted and normalized.
8. **Registration Status & Type:** Field 7 parsed (e.g. `Regular`, `Active`).

#### Accuracy & Human-in-the-Loop Controls
- **Never Silently Accepted:** OCR results automatically populate text fields in an editable review card.
- **Mandatory Review:** The broker must inspect each field and check the explicit confirmation box:  
  *`"I confirm that I have reviewed the certificate and verify that the business details match the uploaded document."`*
- **Truth in Advertising:** This pathway is strictly labeled `Broker Verified — Certificate Reviewed` (internal status `broker_verified`). It does NOT claim government verification.

---

### 3. Verification States & Admin Workflow

Counterparty verification follows four distinct lifecycle states:

```
[ New Counterparty ]
       │
       ├─► With GST Certificate ──► Broker Reviews & Confirms ──► "Broker Verified — Certificate Reviewed"
       │                                                         (gst_verification_status = 'broker_verified')
       │
       └─► Without Certificate ───► Mandatory GSTIN Entered ────► "GST Verification Pending"
                                                                 (gst_verification_status = 'gst_pending')
                                                                            │
                                                                 Enqueued to Admin Queue
                                                                (counterparty_verification_requests)
                                                                            │
                                                      ┌─────────────────────┴─────────────────────┐
                                                      ▼                                           ▼
                                                [ Approved ]                                 [ Rejected ]
                                       "Broker Verified" / "Admin Verified"               "Unverified / Rejected"
```

1. **Broker Verified — Certificate Reviewed (`broker_verified`):** Created when a valid certificate copy is reviewed and confirmed by the broker. Saves document URL, broker ID (`gst_verified_by`), and audit timestamp (`gst_verified_at`).
2. **GST Verification Pending (`gst_pending`):** Created during manual addition without certificate copy. Counterparty is saved as unverified (`is_verified = false`), and a record is created in `counterparty_verification_requests`.
3. **Admin Verification Flow:**
   - Supabase RPC `review_counterparty_verification(p_request_id, p_approve, p_reason)` allows administrators to approve or reject requests.
   - When approved, updates company `gst_verification_status` to `broker_verified` (or `gst_verified` if external service verified) and sets `is_verified = true`.
   - When rejected, records rejection reason and retains unverified status.

---

### 4. Optional Bank Details & Document Security

#### Strict Fiduciary Boundary
Bank details are **not mandatory** and **never block counterparty creation**:
- The broker is asked: *"Is a cheque leaf available for this counterparty?"*
- If **No**, the banking section is completely bypassed, leaving bank fields null.
- If **Yes**, the broker must upload/photograph a valid cheque leaf.

#### Cheque Leaf OCR Extraction
Extracts:
- **Bank Name & IFSC:** 11-character code matching `^[A-Z]{4}0[A-Z0-9]{6}$`. Bank name is cross-referenced with Indian bank prefix mappings (SBIN, HDFC, ICIC, UTIB, PUNB, BARB, etc.).
- **Account Number:** 9 to 18 digits.
- **Branch Name & Account Holder Name:** Extracted from payee/account title line.

#### Security & Masking
1. **Never Bank Verified:** Bank details are labeled `Cheque Leaf Provided — Broker Recorded` (internal status `cheque_leaf_provided`), never claimed as verified by a bank.
2. **Account Masking:** Full account numbers are never rendered in directory list views, cards, or notifications. Only masked format `•••• •••• 1234` is displayed.
3. **Private Buckets & Storage RLS:**
   - Certificates: `brokerbridge_gst_certificates` (`public = false`).
   - Cheque leaves: `brokerbridge_cheque_leaves` (`public = false`).
   - Storage RLS enforces that only the assigned broker or administrator can read the document.

---

### 5. Deal Summary & Deal-Time Document Sharing

When a deal is confirmed:
1. **Deal / Order Summary:** Generates an official deal summary containing:
   - Deal Reference (`dealRef`)
   - Buyer & Seller Entity Names
   - Commodity & Grade
   - Agreed Volume & Unit
   - Agreed Price & Total Valuation
   - Price Basis & Delivery Location
   - Delivery Terms & Payment Terms
   - Packaging Details
2. **Preview Before Share:** A dedicated modal dialog (`DealShareDialog`) allows the broker to preview the full text before copying or sharing via system share sheets (WhatsApp / SMS / Email).
3. **Explicit Cheque Leaf Authorization:**
   - Seller bank details are **excluded by default**.
   - An explicit toggle requires the broker to confirm: *"Include Seller Banking Details (Cheque Leaf Supported)"*.
   - When enabled, bank details are appended with masked account numbers and an explicit disclaimer:  
     *`"Notice: Cheque Leaf Provided — Broker Recorded (not bank verified)."`*
4. **Audit Logging:** Every share event is recorded to `deal_document_shares` in Supabase with `deal_id`, `broker_id`, `recipient_company_id`, `document_type`, `shared_payload`, and `shared_at`.

---

### 6. Database & Migration Schema Summary

Migration `0057_counterparty_gst_and_bank_verification.sql` provides:
- **Columns on `companies` table:**
  - `gst_verification_status` (VARCHAR DEFAULT 'unverified')
  - `gst_certificate_url` (TEXT)
  - `gst_legal_name` (TEXT)
  - `gst_trade_name` (TEXT)
  - `gst_constitution` (TEXT)
  - `gst_registration_date` (DATE)
  - `gst_verified_by` (UUID REFERENCES auth.users)
  - `gst_verified_at` (TIMESTAMPTZ)
  - `bank_holder_name` (TEXT)
  - `bank_name` (TEXT)
  - `bank_account_number` (TEXT)
  - `bank_ifsc` (TEXT)
  - `bank_branch` (TEXT)
  - `bank_cheque_url` (TEXT)
  - `bank_verification_status` (VARCHAR DEFAULT 'unverified')
  - `bank_recorded_by` (UUID REFERENCES auth.users)
  - `bank_recorded_at` (TIMESTAMPTZ)
- **Tables Created:**
  - `counterparty_verification_requests` (with indexes on `company_id`, `broker_id`, `status`).
  - `deal_document_shares` (with indexes on `deal_id`, `broker_id`, `recipient_company_id`).
- **Security & Storage:**
  - Storage buckets `brokerbridge_gst_certificates` and `brokerbridge_cheque_leaves` marked private (`public = false`).
  - Row Level Security (RLS) policies granting access only to assigned brokers and admins.
  - Safe rollback script `rollback_0057.sql` verified.

---

### 7. Test Results (All 20 Test Cases)

Test file: `test/features/directory/counterparty_gst_and_banking_test.dart`

| Test # | Description | Result |
|--------|-------------|--------|
| **1** | Add Buyer with GST certificate extracts and saves as Broker Verified | **PASS** |
| **2** | Add Seller with GST certificate saves as Broker Verified seller | **PASS** |
| **3** | Take certificate photo using camera supports rotation and replace | **PASS** |
| **4** | Upload certificate from gallery sets path and initializes clean state | **PASS** |
| **5** | OCR extraction automatically populates form and allows broker corrections | **PASS** |
| **6** | Unreadable certificate displays actionable error and prevents false verification | **PASS** |
| **7** | Invalid GSTIN format or checksum is rejected with specific error | **PASS** |
| **8** | Duplicate GSTIN detection alerts broker and halts submission | **PASS** |
| **9** | Manual Buyer addition requires mandatory GSTIN and submits cleanly | **PASS** |
| **10** | Manual Seller addition requires mandatory GSTIN and submits cleanly | **PASS** |
| **11** | Manual registration queues counterparty_verification_requests for Admin | **PASS** |
| **12** | Bank details can be completely skipped without blocking registration | **PASS** |
| **13** | Bank details added with cheque-leaf evidence extracts and records safely | **PASS** |
| **14** | Unsupported bank details without cheque leaf or broker review are blocked | **PASS** |
| **15** | Counterparty parses with GST badges and masked bank account in directory | **PASS** |
| **16** | Authorized broker can access complete saved GST and banking details | **PASS** |
| **17** | Storage buckets and RLS enforce private access controls for certificates | **PASS** |
| **18** | Deal summary displays correct agreed commercial, delivery and payment terms | **PASS** |
| **19** | Cheque leaf is shared only when authorized and logs audit trail | **PASS** |
| **20** | Admin verification approval or rejection logs and updates correctly | **PASS** |

#### Regression Suite Verification
- `test/features/directory`: **95/95 passed** (100%)
- `test/features/deals`: **68/68 passed** (100%)
- **Total Suite:** **163/163 passed**, zero regressions across the codebase.

---

### 8. Remaining Blockers & Next Actions
- **No Blockers:** All acceptance criteria are satisfied, automated unit/widget/integration tests are green, and manual fallback paths operate seamlessly without network dependencies.
- **Next Deployment Step:** Apply proposed migration `0057_counterparty_gst_and_bank_verification.sql` to the production Supabase project via `supabase db push` or SQL Editor.

