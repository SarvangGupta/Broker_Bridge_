# RB-SELLER-POST-UX-02 — Pre-Implementation Audit Report
## Lab Report Simplification, Automatic Reference Generation & My Trusted Broker

**Project:** RMBroker  
**Application:** RM Seller App (`apps/rmseller_mobile`)  
**Sprint ID:** `RB-SELLER-POST-UX-02`  
**Date:** October 21, 2026  
**Auditor:** Antigravity AI Coding Agent  
**Audit Status:** **AUDIT COMPLETE — READY FOR IMPLEMENTATION**

---

### 1. Executive Summary

This pre-implementation audit investigates the Post Commodity Lot page in `rmseller_mobile` to achieve the five core objectives of `RB-SELLER-POST-UX-02`:
1. **Remove Redundant Lab Test / Quality Assay Document Selection Field:** The legacy dropdown offering *"NABL Certified Lab Report Available"*, *"Government Mandi Assay Certificate"*, and *"Visual Mandi Inspection"* is manual, confusing, and redundant when native file attachments and certified lab testing exist.
2. **Remove Manual Report Reference / Certificate Number Input:** The manual text field `_labReportNumberController` must be eliminated so sellers are not forced to type arbitrary certificate numbers.
3. **Automatic Reference Generation:**
   - **For Certified Lab Testing:** Authoritative request reference (e.g. `LAB-REQ-<timestamp>-<hash>`) generated upon testing request creation, displayed read-only, and preserved without re-generating on screen refreshes or repeated taps.
   - **For Attached Existing Lab Reports:** Deterministic/authoritative document reference (e.g. `DOC-REF-<lotNumber>-<hash>`) generated upon file acceptance, displayed read-only on the attachment card, and mapped to `lab_report_number`.
4. **Rename Broker Mandate Assignment to "My Trusted Broker":** Update visible section heading from *"4. Broker Mandate Assignment"* to *"4. My Trusted Broker"*, and supporting copy to *"Choose the broker or brokers you trust to handle this commodity."*
5. **Multi-Broker Capability Verification:** Inspect the authoritative backend database schema (`availabilities.broker_id`) to verify whether multiple brokers can be simultaneously assigned. Reiterate the verified single-broker contract, document schema boundaries, and preserve existing listing re-assignment workflows with confirmation reviews.
6. **Preservation of Certified Lab Testing:** Keep the 16-test rate card, Jaipur laboratory details, UPI deep-linking, trusted backend verification, and admin notification pipeline completely intact.

---

### 2. Workspace & Git Preflight Status

- **Application Directory:** `apps/rmseller_mobile/`
- **Root Repository:** `Broker_Bridge_/`
- **Current Branch:** `feature/broker-nilesh`
- **Baseline Invariants:**
  - `apps/rmbuyer_mobile`: Untouched (0 modifications)
  - `apps/rmbroker_mobile`: Untouched (0 modifications)
  - `supabase/migrations`: Untouched (0 modifications, strict schema protection policy)
- **Target Physical Device:** Xiaomi Redmi Note 5 Pro (`e0d9da95`, Android 9.0 API 28)

---

### 3. Pre-Implementation Audit Findings

#### A. Redundant Lab Controls in `post_commodity_screen.dart`
- **Location:** `apps/rmseller_mobile/lib/features/commodities/presentation/post_commodity_screen.dart` lines 1838–1868.
- **Code Inspected:**
  ```dart
  if (!_requestLabTesting) ...[
    const Text('Lab Test / Quality Assay Document *', ...),
    DropdownButtonFormField<String>(
      value: _labReportType,
      items: [
        DropdownMenuItem(value: 'NABL Certified Lab Report Available', ...),
        DropdownMenuItem(value: 'Government Mandi Assay Certificate', ...),
        DropdownMenuItem(value: 'Visual Mandi Inspection (No Report)', ...),
      ],
      ...
    ),
    const SizedBox(height: 14),
    AppTextField(
      controller: _labReportNumberController,
      label: 'Report Reference / Certificate Number',
      hint: 'e.g. AGMARK-RAL-2026-9021',
    ),
  ]
  ```
- **Finding:** When `_requestLabTesting` is false, the form still rendered both the manual dropdown and the text field.
- **Remediation Plan:** Completely remove this block from the UI. Keep backend model fields intact. In `_handleSubmit()`, set `labReportNumber` to the auto-generated reference if an attachment exists, or the certified request reference if requested, or null when skipped.

#### B. Automatic Reference Generation Contract
- **Authoritative Database Schema (`src/server/db/schema.ts`):**
  - Table `lab_tests`:
    - `id: uuid('id').defaultRandom().primaryKey()`
    - `reportNumber: text('report_number').notNull()`
  - Table `availabilities`:
    - Doesn't mandate manual certificate numbers.
  - Model `SellerCommodity` & `CreateCommodityDto`:
    - Holds `labReportNumber: String?` and `labReportFileName: String?`.
- **Implementation Strategy:**
  1. **Certified Lab Testing:** When a testing request is initiated via `_handleInitiateUpiPayment` / `createTestingRequest`, `_currentLabRequest.id` (`LAB-REQ-...`) is the authoritative reference. Display this reference prominently in read-only format inside `_buildLabTestingSection()`.
  2. **Attached Lab Report:** When a file is chosen via gallery, document picker, or camera, generate an authoritative reference `DOC-REF-${lotNumber.isNotEmpty ? lotNumber : "LOT"}-${fileName.hashCode.abs().toString().padLeft(6, '0').substring(0, 6)}`. Attach this reference to `LabReportAttachment.reportReference`. Display it in read-only format directly on the attachment card.
  3. **Idempotency:** The reference is computed once upon file selection and stored in the attachment state object. Reopening modals or refreshing does not regenerate a new reference.

#### C. Section Labeling & Wording Updates
- **Current Section 4 Header:** `'4. Broker Mandate Assignment'` (line 2442).
- **Target Section 4 Header:** `'4. My Trusted Broker'`.
- **Target Supporting Copy:** `“Choose the broker or brokers you trust to handle this commodity.”`
- **Section 5 Review Row:** Rename `'Mandate Routing'` to `'Trusted Broker Routing'`.
- **Commodity Details Card:** Update `'Mandi Broker Desk'` header to `'My Trusted Broker'` for seamless terminology across the application.

#### D. Multi-Broker Backend Contract Audit
- **Authoritative Database Schema (`src/server/db/schema.ts:155-188`):**
  ```typescript
  export const availabilities = pgTable('availabilities', {
    ...
    brokerId: uuid('broker_id').references(() => users.id),
    ...
  });
  ```
- **Finding:** The database table `availabilities` defines a single column `broker_id: uuid('broker_id')`. There is no `availability_brokers` junction table.
- **Contract Rule:** Multi-broker simultaneous assignment is blocked at the backend schema level. Per sprint requirements:
  *"If the backend supports only one Broker, retain the verified single-select behaviour and document the limitation. Do not simulate multi-Broker persistence in local UI state."*
- **Action:** The UI cleanly presents single authoritative broker selection (labeled *"Select Broker(s)"* per specification) and persists the selected broker ID directly into `availabilities.broker_id` without faking client-only multi-selection. The broker change workflow on existing listings with confirmation review is preserved.

---

### 4. Implementation Plan

1. **Model Layer (`lab_testing_model.dart`):**
   - Add `reportReference` field to `LabReportAttachment`.
   - Update `copyWith`, `toMap`, and `fromMap`.
2. **Presentation Layer (`post_commodity_screen.dart`):**
   - Remove `DropdownButtonFormField<String>` for `_labReportType` and `AppTextField` for `_labReportNumberController`.
   - In `_buildLabTestingSection()`, add read-only display for `_currentLabRequest?.id`.
   - In `_buildLabReportAttachmentCard()`, generate `DOC-REF-...` on file pick and display it as a read-only tag: `Reference: <reportReference> (Auto-generated)`.
   - Rename Section 4 header to `'4. My Trusted Broker'`.
   - Update Section 4 supporting copy to `"Choose the broker or brokers you trust to handle this commodity."`.
   - Update Section 5 review summary row to `'Trusted Broker Routing'`.
   - Update `_handleSubmit()` to map auto-generated references into `dto.labReportNumber`.
3. **Presentation Layer (`commodity_details_screen.dart`):**
   - Update card header from `'Mandi Broker Desk'` to `'My Trusted Broker'` for end-to-end consistency.
4. **Verification & Testing:**
   - Create automated test suite `src/server/tests/verify-rmseller-post-ux-02.ts` for all 21 regression tests (SELLER-UX2-01 through SELLER-UX2-21).
   - Run `flutter analyze lib/features/commodities/`.
   - Build debug APK and verify on physical device with screenshots.
