# RB-SELLER-LAB-01 — Pre-Implementation Audit Report
## Optional Lab Testing, UPI Payment, Admin Notification & Backend Report Management

**Project:** RMBroker  
**Application:** RM Seller App (`apps/rmseller_mobile`)  
**Sprint ID:** `RB-SELLER-LAB-01`  
**Date:** October 21, 2026  
**Auditor:** Antigravity AI Coding Agent  
**Status:** **AUDIT COMPLETE — READY FOR IMPLEMENTATION**

---

### 1. Executive Summary

This pre-implementation audit inspects the existing architecture of RMBroker and `rmseller_mobile` to establish authoritative boundaries, models, payment mechanisms, notification channels, and report storage workflows for sprint `RB-SELLER-LAB-01`.

The goal is to extend the lab testing workflow into an end-to-end optional service:
1. **Optional Service Selection:** Lab testing is strictly optional. Sellers who do not select lab testing can post commodities directly without obstruction.
2. **Authoritative 16-Test Rate Card:** Sellers review official listed prices from the rate card. "Other" has no assigned or invented price.
3. **UPI-Only Payment Workflow:** Deep-link / Intent payment via standard UPI (`upi://pay`). No cards, net banking, cash, or wallets.
4. **Trusted Backend Verification:** Client callbacks, UPI app returns, or seller-provided transaction IDs alone never mark payment successful. Only authoritative backend verification transitions the request to `Paid`.
5. **Post-Payment Admin Notification:** Idempotent notification dispatched to authorized administrators only after confirmed payment.
6. **Backend-Managed Lab Reports:** Authorized admin or lab uploads report to private storage; sellers access their own verified reports via time-limited signed URLs with strict tenant isolation.

---

### 2. Workspace & Git Preflight Status

- **Workspace Inspected:** `apps/rmseller_mobile/`
- **Root Repository:** `Broker_Bridge_/`
- **Current Branch:** `feature/broker-nilesh`
- **Sibling App Boundary Invariant:**
  - `apps/rmbuyer_mobile`: 0 modifications (Untouched)
  - `apps/rmbroker_mobile`: 0 modifications (Untouched)
  - `supabase/migrations`: 0 migrations or schema mutations (Strict Zero-Mutation Policy)
- **Target Device:** Connected Xiaomi Redmi Note 5 Pro (`e0d9da95`) via ADB, Flutter SDK at `D:\flutter_sdk\flutter\bin\flutter.bat`.

---

### 3. Pre-Implementation Audit Findings

#### A. Current Lab Testing & Certificate Workflow
- **Mobile (`apps/rmseller_mobile`):**
  - In `post_commodity_screen.dart`, Section 3 contained a static dropdown for `_labReportType` (`NABL Certified Lab Report Available`, `Govt Mandi Assay Certificate`, `Visual Mandi Inspection (No Report)`) and a manual text field `_labReportNumberController`.
  - In `commodity_details_screen.dart`, line 318 displays `_buildInfoRow('Lab Certificate', lot.labReportNumber)`.
  - The mobile app had no support for selecting individual chemical/physical parameters, reviewing listed charges, initiating UPI payments, checking live verification status, or downloading admin-uploaded reports.
- **Backend (`src/server/actions/lab-actions.ts`):**
  - Full backend infrastructure already exists:
    - `saveLabTestRecordAction`: Saves or updates `lab_tests` and `lab_test_results` with tenant ownership verification.
    - `attachLabDocumentAction`: Links evidence URL to `lab_tests`.
    - `uploadLabEvidenceAction`: Uploads physical COA / certificate to Supabase Storage bucket `brokerbridge_lab_evidence`.
    - `getLabEvidenceSignedUrlAction`: Generates 60-minute time-limited signed URL with directory traversal guards (`..`, `\`, `\0`) and seller company authorization.
    - `getSellerGlobalLabReportsAction`: Retrieves all lab reports belonging to the authenticated seller's company.
    - `getLabTestByAvailabilityAction`: Fetches structured lab results and computed freshness.

#### B. Database Schema & Status Fields
- **Table `lab_tests` (`supabase/migrations/0022_add_lab_test_records.sql`, `0023_add_file_url_to_lab_tests.sql`):**
  - Columns: `id`, `availability_id`, `company_id`, `laboratory_name`, `laboratory_location`, `sample_id`, `sample_date`, `test_date`, `report_number`, `report_date`, `valid_until`, `file_url`, `status`, `verified_by`, `verified_at`, `verification_notes`, `created_at`, `updated_at`.
  - Valid Status Values: `'Sample Pending'`, `'Testing In Progress'`, `'Report Uploaded'`, `'Under Review'`, `'Verified'`, `'Correction Required'`, `'Rejected'`, `'Expired'`.
- **Table `lab_test_results`:**
  - Columns: `id`, `lab_test_id`, `parameter_id`, `measured_value`, `is_within_bounds`, `created_at`, `updated_at`.
- **Table `master_laboratories` (`supabase/migrations/0031_add_master_laboratories.sql`):**
  - Columns: `id`, `name`, `location`, `is_active`, `created_at`.
  - Confirmed Partner Laboratory: **Riddhi Siddhi Laboratory**, F-772 B, Road Number 6, Vishwakarma Industrial Area, Jaipur, Rajasthan.
- **Table `availabilities`:**
  - Statuses: `'Open'`, `'Active'`, `'Reserved'`, `'Fulfilled'`, `'Expired'`, `'Cancelled'`.

#### C. Payment Gateway & UPI Infrastructure
- **Existing `payments` Table (`0013_add_payments_and_disputes.sql`):**
  - Columns: `id`, `deal_id`, `amount`, `reference_number`, `status`, `created_at`.
  - Note: This table has a hard foreign key constraint referencing `deals(id)` for deal settlements. It is **not** schema-compatible with standalone lab testing requests prior to deal creation.
- **Payment Method Permitted:** UPI is the **only** permitted payment method for this lab testing service. No credit cards, debit cards, net banking, or cash on delivery.
- **UPI Deep Link Format:**
  - Scheme: `upi://pay`
  - Parameters:
    - `pa`: `rs.lab.jaipur@upi` (Authoritative laboratory UPI VPA)
    - `pn`: `Riddhi Siddhi Laboratory`
    - `am`: Verified final payable amount (e.g. `200.00`)
    - `cu`: `INR`
    - `tn`: `Lab Testing Lot ${lotNumber} - RMBroker`
    - `tr`: Unique Idempotent Transaction Reference `LAB-TXN-${availabilityId}-${timestamp}`
- **Security & Trusted Backend Verification:**
  - A client-side callback, app return, or seller-provided transaction ID alone **never** marks payment successful.
  - Payment verification must transition through authoritative status states:
    1. `Awaiting payment`
    2. `Payment verification pending`
    3. `Payment failed or cancelled`
    4. `Paid — payment verified`
    5. `Testing request submitted`
    6. `Report available`
  - Only confirmed verification from the trusted backend ledger transitions the request to `Paid`.

#### D. Admin Notification Pipeline
- **Table `notifications` (`0017_add_notifications_table.sql`, `0030_add_seller_action_center_notifications.sql`):**
  - Columns: `id`, `user_id`, `company_id`, `channel`, `event_type`, `title`, `message`, `context_reason`, `action_label`, `action_url`, `idempotency_key`, `payload`, `delivery_status`, `is_read`, `read_at`, `attempt_count`, `max_attempts`, `error_message`, `provider_message_id`, `sent_at`, `failed_at`, `created_at`.
  - Key Constraint: `uniqueIndex` on `idempotency_key` ensures strict deduplication.
- **Event Type:** `LAB_UPDATE` is already registered in `NotificationEventType` (`src/server/notifications/types.ts`).
- **Trigger Rule:** Admin notification is dispatched **strictly after** backend verification of successful payment.
- **Notification Payload:**
  - Title: `Paid Lab Testing Request: Lot <lotNumber>`
  - Context Reason: `Seller requested <count> tests for ₹<amount> verified via UPI.`
  - Action Label: `Coordinate Lab Testing`
  - Action URL: `/admin/lab-tests/<id>`
  - Idempotency Key: `LAB-NOTIF-ADMIN-<requestId>-<txnRef>`

#### E. Storage & Report Privacy
- **Bucket:** `brokerbridge_lab_evidence` (Private Supabase Storage Bucket).
- **Storage RLS (`manual_lab_storage_rls.sql`):**
  - Path structure: `{availability_id}/{filename}`
  - SELECT policy restricts download to:
    1. Users with role `'admin'` or `'broker'`, OR
    2. Sellers whose `company_id` matches the availability lot's `company_id`.
  - Result: Strict tenant isolation. Seller A cannot view Seller B's lab report by manipulating file paths or request IDs.

---

### 4. Architectural Gap Analysis & Sprint Scope

| Component | Existing State | Gap / Required Implementation |
|---|---|---|
| **Optional Lab Selection** | Dropdown with static certificate options | Add optional toggle/card in posting form; if off, standard posting proceeds unimpeded. |
| **Rate Card & Test Selection** | No parameter selection | Multi-select parameter card showing all 16 tests with exact listed charges; non-double-counting estimate. |
| **UPI Payment Flow** | None in mobile | Deep-link UPI intent generator (`upi://pay`), UPI launcher, verification state machine. |
| **Backend Verification** | Web actions exist for lab records | Mobile client repository for backend payment verification, status polling, and idempotent state persistence. |
| **Admin Notification** | `LAB_UPDATE` event type exists | Hook post-payment notification dispatch to admin users with unique idempotency keys. |
| **Report Access** | Web action `getLabEvidenceSignedUrlAction` exists | Mobile report status card, pending status indicators, and secure signed report launcher in `commodity_details_screen.dart`. |

---

### 5. Audit Conclusion

The system infrastructure (database tables `lab_tests`, `master_laboratories`, `notifications`, storage bucket `brokerbridge_lab_evidence`, and server actions) is mature and ready. The implementation will seamlessly wire `rmseller_mobile` into this backend while strictly honoring the rate card, UPI payment constraints, admin notification trigger rules, and privacy invariants.
