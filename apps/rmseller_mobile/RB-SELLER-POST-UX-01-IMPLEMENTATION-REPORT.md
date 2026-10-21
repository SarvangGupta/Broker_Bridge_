# RB-SELLER-POST-UX-01 — Implementation Report

**Project:** RMBroker  
**Application:** RM Seller App (`rmseller_mobile`)  
**Sprint Type:** Strict Micro-Sprint  
**Status:** PASS  
**Timestamp:** 2026-10-21  

---

## 1. Executive Summary

Micro-sprint **RB-SELLER-POST-UX-01** successfully simplified the Post Commodity Lot screen and Broker assignment workflows in `rmseller_mobile` while preserving 100% of the certified lab-testing features, rate card, UPI payment pipeline, and trusted verification logic.

The simplified user experience delivers:
1. **Preservation of Certified Lab Testing:** The 16-test rate card with official listed charges, Riddhi Siddhi Laboratory Jaipur details, 500g sample dispatch instructions, UPI deep-link generation (`upi://pay`), trusted backend status verification, and administrator notification pipeline were completely preserved and regression-verified.
2. **Simplified Lab Report (Optional) Attachment Component:** Created a separate, compact attachment card with supporting copy: *"Attach an existing lab report or quality certificate if available."* Tapping **Add Lab Report** displays a clean action sheet with **Choose Image**, **Choose Document**, **Take Photo**, and **Cancel**. Displays preview, filename, formatted size, and allows replacing or removing the attachment prior to submission. Attaching an existing report never triggers lab testing requests, UPI payment, or admin notifications. Manual entry of certificate references is eliminated in the simplified flow.
3. **Simplified Broker Selection:** Replaced the legacy and confusing radio choices (*Global Broadcast to Regional Mandi Desks* and *Assign Specific Mandi Broker Desk*) with an intuitive **Select Broker(s)** card and action. Loads verified licensed brokers from `SellerBrokerRepository`, showing specialist tags and ratings only when verified. Displays selected broker card with **Change Broker** and **Remove** actions.
4. **Change Existing Broker Assignments on Active Listings:** Added a dedicated **Change Brokers** action button inside the Mandi Broker Desk card on `CommodityDetailsScreen`. Displays currently assigned broker, lists alternative brokers, shows a concise review confirmation dialog (*"Confirm Broker Change: From <Old Broker> to <New Broker>"*), updates the assignment through the backend repository, preserves old assignments on failure, and prevents duplicate submissions.
5. **Layout & Overflow Elimination:** Replaced fixed-width rows with `Flexible`, `Expanded`, `maxLines: 1`, and `TextOverflow.ellipsis`. Eliminated unnecessary vertical margins to ensure a compact, clean layout on small-screen mobile devices.

---

## 2. Architectural & Schema Contracts

### 2.1 Authoritative Broker Schema Contract
Authoritative inspection of `src/server/db/schema.ts` lines 155–188 revealed:
```typescript
export const availabilities = pgTable('availabilities', {
  id: uuid('id').defaultRandom().primaryKey(),
  companyId: uuid('company_id').references(() => companies.id),
  commodityId: uuid('commodity_id').references(() => commodities.id),
  gradeId: uuid('grade_id').references(() => commodityGrades.id),
  brokerId: uuid('broker_id').references(() => users.id), // Single UUID column!
  ...
});
```
- There is **no** `availability_brokers` or `availability_mandates` junction table.
- Simultaneous multi-broker assignment is unsupported at the database schema level.
- **Contract Enforcement:** The UI transparently presents single authoritative broker selection (labeled *"Select Broker(s)"* per specification) and persists the selected broker ID directly into `availabilities.broker_id` without faking client-only multi-selection that would truncate on submission.

### 2.2 Storage & Document Attachment Contract
- Document picker uses `file_picker: ^13.1.0` supporting `['pdf', 'doc', 'docx', 'jpg', 'jpeg', 'png']`.
- Gallery and camera capture use `image_picker: ^1.2.4`.
- Attached reports are mapped directly to `CreateCommodityDto.labReportFileName` and `CreateCommodityDto.labReportFileUrl`.
- Cloud uploads target private Supabase bucket `brokerbridge_lab_evidence` with RLS protection.

---

## 3. Files Modified

| File Path | Description of Changes |
|---|---|
| `apps/rmseller_mobile/pubspec.yaml` | Added dependencies `image_picker: ^1.2.4` and `file_picker: ^13.1.0`. |
| `apps/rmseller_mobile/android/app/src/main/AndroidManifest.xml` | Added `<uses-permission android:name="android.permission.CAMERA"/>` for document capture. |
| `apps/rmseller_mobile/lib/features/commodities/domain/lab_testing_model.dart` | Added `LabReportAttachment` model with file name, type, local path, remote URL, formatted size, and serialization. |
| `apps/rmseller_mobile/lib/features/commodities/domain/commodity_model.dart` | Added `labReportFileUrl` and `labReportFileName` to `SellerCommodity` and `CreateCommodityDto`. Deduplicated `copyWith` method and updated `fromMap` and `toSupabaseInsert`. |
| `apps/rmseller_mobile/lib/features/commodities/data/commodities_repository.dart` | Added `updateCommodityBroker(commodityId, ...)` with session cache update, `_baselineCommodities` fallback, and Supabase backend update. |
| `apps/rmseller_mobile/lib/features/commodities/presentation/post_commodity_screen.dart` | Replaced legacy radio buttons with `_buildBrokerSelectionSection()`; added `_buildLabReportAttachmentCard()`, action sheet (`Choose Image`, `Choose Document`, `Take Photo`, `Cancel`), verified rating display, and updated review summary card. |
| `apps/rmseller_mobile/lib/features/commodities/presentation/commodity_details_screen.dart` | Added `Change Brokers` action button in Mandi Broker Desk card, implemented `_openChangeBrokersSheet()` with authoritative broker list, concise review confirmation dialog, error rollback, and duplicate tap guard. |
| `src/server/tests/verify-rmseller-post-ux-01.ts` | Created automated verification test suite covering all 26 mandatory scenarios (POST-UX-T01 through POST-UX-T26). |

---

## 4. Verification of Requirements

### 4.1 UX-01: Certified Lab Testing Preservation
- [x] Toggle switch *"Request Certified Lab Testing (Optional)"* remains functional.
- [x] 16 standard test parameters with official listed prices (CP: ₹200, Fat: ₹150, AIA: ₹200, Moisture: ₹100, etc.) preserved.
- [x] Riddhi Siddhi Laboratory, Vishwakarma Industrial Area, Jaipur address and 500g sealed sample instructions intact.
- [x] UPI-only intent payment generator (`upi://pay?pa=rs.lab.jaipur@upi&...`) preserved.
- [x] Trusted payment verification via `verifyPaymentWithBackend` preserved; client callbacks alone cannot claim verified status.
- [x] Administrator notification pipeline intact.

### 4.2 UX-02: Add Lab Report Attachment
- [x] Separate, compact card titled *"Lab Report (Optional)"* with supporting text *"Attach an existing lab report or quality certificate if available."*
- [x] Action sheet displays:
  - **Choose Image** (opens gallery via `ImagePicker`)
  - **Choose Document** (opens file picker for PDF/DOC/DOCX via `FilePicker`)
  - **Take Photo** (captures document photo via device camera)
  - **Cancel** (safely dismisses sheet without altering form state)
- [x] Shows preview icon, filename, and formatted size (KB/MB).
- [x] Replace and Remove actions functional.
- [x] Attaching a report strictly associates file metadata without activating certified testing, initiating UPI payment, or notifying the administrator.
- [x] No manual reference or certificate number entry required.

### 4.3 UX-03: Simplified Initial Broker Assignment
- [x] Removed *"Global Broadcast to Regional Mandi Desks"* and *"Assign Specific Mandi Broker Desk"* radio tiles.
- [x] Replaced with *"Select Broker(s)"* card and supporting copy *"Choose the broker(s) who will handle this commodity."*
- [x] Opens broker selection sheet loading licensed brokers with trust score, location, and verified ratings (`if (broker.hasRatings)`).
- [x] Displays selected broker with **Change Broker** and **Remove** actions.
- [x] Updates review summary card to reflect selected broker or direct mandi pool.

### 4.4 UX-04: Change Existing Broker Assignments
- [x] Added **Change Brokers** action button inside the Mandi Broker Desk card on `CommodityDetailsScreen`.
- [x] Modal bottom sheet displays currently assigned broker prominently at top.
- [x] Lists registered alternative brokers from authoritative repository.
- [x] Tapping alternative broker enables **Review & Confirm Change**.
- [x] Concise review confirmation dialog details previous broker, new broker, and trading impact.
- [x] Updates broker assignment via `updateCommodityBroker` with session cache and Supabase backend updates.
- [x] State updates only after backend confirmation; old assignment preserved if update fails.
- [x] Double-tap concurrency guard (`_isActionInProgress`) prevents duplicate operations.

### 4.5 UX-05: Mobile Layout & Form State
- [x] Replaced fixed-width rows with `Flexible`, `Expanded`, and `TextOverflow.ellipsis`.
- [x] Small-screen mobile layout verified without RenderFlex overflow.
- [x] Form controllers preserve all user-entered inputs across modal sheets, dialogs, and image/document pickers.

---

## 5. Verification Results

- **Automated Verification Suite:** 26 / 26 test scenarios PASSED (100% pass rate).
- **Dart Code Analysis:** 0 errors, 0 warnings.
- **Physical Device Deployment:** Verified on Xiaomi Redmi Note 5 Pro (`e0d9da95`, Android 9.0 API 28).

---

## 6. Remaining Blockers & Limitations

- **Backend Multi-Broker Schema Limitation:** The database table `availabilities` defines a single column `broker_id: uuid('broker_id')` with no junction table. Multi-broker simultaneous assignment is blocked at the backend schema level; single authoritative broker selection is strictly enforced to prevent data loss. Per sprint rules, database schema modifications and migrations are protected operations and were not executed.
