# RB-SELLER-POST-UX-01 — Pre-Implementation Audit Report
## Simplify Commodity Posting, Lab Reports & Broker Selection

**Project:** RMBroker  
**Application:** RM Seller App (`apps/rmseller_mobile`)  
**Sprint ID:** `RB-SELLER-POST-UX-01`  
**Date:** October 21, 2026  
**Auditor:** Antigravity AI Coding Agent  
**Audit Status:** **AUDIT COMPLETE — READY FOR IMPLEMENTATION**

---

### 1. Executive Summary

This pre-implementation audit investigates the commodity posting workflow, lab testing, certificate attachment mechanisms, and broker assignment and modification contracts across `rmseller_mobile` and the RMBroker backend services.

The primary goals of this sprint are:
1. **Preserve Certified Lab Testing (UX-01):** Preserve the existing `Request Certified Lab Testing` feature, 16-test rate card, partner laboratory (Riddhi Siddhi Laboratory, Jaipur), 500g sample instructions, UPI-only payment, trusted backend verification, and admin notification pipeline implemented in `RB-SELLER-LAB-01`.
2. **Add Simple Lab Report Attachment (UX-02):** Add an independent, optional **Lab Report (Optional)** attachment feature offering **Choose Image** (device gallery), **Choose Document** (PDF/DOC), **Take Photo** (device camera), and **Cancel** without requiring manual report reference entry. Attaching an existing report must never trigger testing requests or payment.
3. **Simplify Initial Broker Assignment (UX-03):** Remove confusing "Global Broadcast" and "Assign Specific Mandi Broker Desk" choices. Replace with a clean **Select Broker(s)** action that loads verified brokers, shows ratings/specialization tags, and cleanly indicates the selected broker.
4. **Change Existing Broker Assignments (UX-04):** Provide a dedicated **Change Brokers** workflow on active listings, showing current assignments, allowing broker re-assignment with concise review confirmation, preserving previous assignments on failure, and preventing duplicate submissions.
5. **Layout & Overflow Elimination (UX-05):** Fix compact-screen RenderFlex overflows, eliminate unnecessary vertical whitespace, and preserve form state across all modals and pickers.

---

### 2. Workspace & Git Preflight Status

- **Application Directory:** `apps/rmseller_mobile/`
- **Root Repository:** `Broker_Bridge_/`
- **Current Branch:** `feature/broker-nilesh`
- **Baseline Invariants:**
  - `apps/rmbuyer_mobile`: 0 modifications (Untouched)
  - `apps/rmbroker_mobile`: 0 modifications (Untouched)
  - `supabase/migrations`: 0 migrations (Strict Zero-Mutation Policy)
- **Target Device:** Xiaomi Redmi Note 5 Pro (`e0d9da95`, Android 9.0 API 28)

---

### 3. Pre-Implementation Audit Findings

#### A. Certified Lab Testing Flow (`RB-SELLER-LAB-01`)
- **Location:** `apps/rmseller_mobile/lib/features/commodities/presentation/post_commodity_screen.dart` lines 1296–1588.
- **Workflow State:**
  - Switch: `"Request Professional Lab Testing (Optional) — Partner: Riddhi Siddhi Laboratory, Jaipur"`
  - 16 parameters: 15 priced standard tests (₹100 to ₹850) + 1 unpriced "Other (Custom Parameter)".
  - Estimated Total and Final Payable Amount (UPI) calculated accurately with deduplication.
  - Payment initiation strictly via `upi://pay` intent with Android `<queries>` registration.
  - Status lifecycle: `Awaiting payment`, `Payment verification pending`, `Payment failed or cancelled`, `Paid — payment verified`.
  - Admin notification dispatched on `LAB_UPDATE` with idempotency key `LAB-ADMIN-NOTIF-<requestId>-<txnRef>`.
- **Preservation Requirement:** This feature must remain 100% accessible and completely separate from the new attachment feature.

#### B. Lab Report Attachment & Storage Audit
- **Current State in Form:**
  - Section 3 displayed a static dropdown (`_labReportType`) and manual text field (`_labReportNumberController`).
  - Mobile app lacked direct gallery, document, or camera attachment integration.
- **Backend & Storage Vault:**
  - Supabase Storage bucket `brokerbridge_lab_evidence` is configured with RLS policies restricting read access to the owning company and authorized administrators.
  - `lab_tests` table contains `file_url`, `report_number`, and `status`.
- **Package Audit:**
  - `image_picker` (1.2.4) and `file_picker` (13.1.0) were resolved and installed via `pubspec.yaml`.
  - Android permissions: Added `CAMERA` permission in `AndroidManifest.xml` to support photo capture.
- **Separation Rule:** Attaching an existing report must not trigger a payment request, create a `lab_tests` testing order, or notify the partner lab administrator.

#### C. Broker Assignment & Multi-Broker Capability Audit
- **Database Schema (`src/server/db/schema.ts:155-188`):**
  - Table: `availabilities`
  - Column: `brokerId: uuid('broker_id')`
  - Foreign Key: References single `users(id)` where `role = 'broker'`.
  - **Crucial Finding:** The database schema has a single `broker_id` column. There is no `availability_brokers` or `availability_mandates` junction table.
  - Therefore, the authoritative backend currently supports **single broker assignment** per availability listing.
- **Client Implementation Contract:**
  - Initial selection in `post_commodity_screen.dart` will support selecting 1 dedicated broker desk, matching the backend capability.
  - Changing brokers in `commodity_details_screen.dart` will allow selecting and confirming a replacement broker desk.
  - The audit documents this limitation transparently: Multi-broker simultaneous assignment is blocked at the backend schema level because `availabilities.broker_id` is a scalar column.

#### D. Mobile Layout & Overflow Investigation
- **Identified Issue:** On compact devices (e.g. 1080x2160 screen), rows containing unconstrained `Text` widgets can cause horizontal RenderFlex overflows.
- **Solution:**
  - Ensure all titles, subtitles, and detail rows wrap text using `Expanded` or `Flexible`.
  - Consolidate Section 3 and Section 4 into compact, well-structured cards without redundant vertical margins.

---

### 4. Implementation Strategy

1. **Update Domain & Repository:**
   - Add `copyWith` to `SellerCommodity` in `commodity_model.dart`.
   - Add `updateCommodityBroker` to `CommoditiesRepository` in `commodities_repository.dart`.
   - Create `LabReportAttachment` model in `lab_testing_model.dart`.
2. **Refactor Section 3 in `post_commodity_screen.dart`:**
   - Preserve existing `Request Certified Lab Testing` switch and workflow.
   - Add **Lab Report (Optional)** attachment card below certified testing.
   - Action sheet with **Choose Image**, **Choose Document**, **Take Photo**, and **Cancel**.
   - Show preview, file name, size, Replace, and Remove actions.
   - Skip both lab options if the seller wants to post without testing/reports.
3. **Refactor Section 4 in `post_commodity_screen.dart`:**
   - Remove "Global Broadcast to Regional Mandi Desks" and "Assign Specific Mandi Broker Desk" radio tiles.
   - Add **Select Broker(s)** card with supporting text: *"Choose the broker(s) who will handle this commodity."*
   - Tap opens broker picker sheet showing specialist tags, trust scores, and ratings (if verified).
   - Card displays selected broker with "Change" and "Remove" options.
4. **Implement "Change Brokers" in `commodity_details_screen.dart`:**
   - Add **Change Brokers** action button to `Assigned Mandi Broker Card`.
   - Opens selection modal showing currently assigned broker and list of alternative brokers.
   - Shows confirmation dialog before updating: *"Confirm Broker Change: From <Old> to <New>"*.
   - Debounced update with backend persistence and error recovery.
5. **Verification & Regression Testing:**
   - Create automated test suite `src/server/tests/verify-rmseller-post-ux-01.ts` covering all 26 tests (POST-UX-T01 through POST-UX-T26).
   - Execute Flutter analysis and build APK.
