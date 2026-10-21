# RB-SELLER-LAB-01 — Implementation Report
## Optional Lab Testing, UPI Payment, Admin Notification & Backend Report Management

**Project:** RMBroker  
**Application:** RM Seller App (`apps/rmseller_mobile`)  
**Sprint ID:** `RB-SELLER-LAB-01`  
**Date:** October 21, 2026  
**Auditor:** Antigravity AI Coding Agent  
**Status:** **IMPLEMENTATION COMPLETE & VERIFIED**

---

### 1. Executive Summary

Sprint `RB-SELLER-LAB-01` extends the existing laboratory testing architecture to support a complete, optional, end-to-end testing workflow for Sellers:
1. **Optional Selection:** Sellers can choose whether to request certified lab testing. Declining lab testing leaves standard commodity posting unblocked.
2. **Authoritative 16-Test Rate Card:** Displays exact listed charges for 15 standard proximate, mineral, and caloric parameters. "Other" has zero invented price and requires a custom lab quote.
3. **UPI-Only Payment Integration:** Initiates deep-link payment via `upi://pay` intent with strict client-side safety (app returns or callbacks alone never mark payment as paid).
4. **Trusted Backend Verification:** Transitions payment to `Paid — payment verified` strictly upon confirmation from the backend ledger.
5. **Post-Payment Admin Notification:** Idempotently dispatches `LAB_UPDATE` notifications to authorized administrators (`role = 'admin'`) only after verified payment.
6. **Backend-Managed Lab Reports:** Authorized admin or laboratory attaches verified reports to `lab_tests`; sellers access reports via time-limited signed URLs with tenant isolation.

---

### 2. File & Component Inventory

| File Path | Action | Description |
|---|---|---|
| `lib/features/commodities/domain/lab_testing_model.dart` | **Created** | Domain entities: `LabTestParameter`, `LabTestRateCard`, `LabPaymentStatus`, `LabTestingRequest`. |
| `lib/features/commodities/data/lab_testing_repository.dart` | **Created** | Data layer: rate card provider, UPI intent generator, backend verification adapter, admin notification dispatcher, signed report downloader. |
| `lib/features/commodities/presentation/post_commodity_screen.dart` | **Modified** | Added optional lab testing toggle, 16-parameter chip selector, charges breakdown, Riddhi Siddhi Laboratory details, UPI payment launcher, and verification action. |
| `lib/features/commodities/presentation/commodity_details_screen.dart` | **Modified** | Added dedicated Laboratory Testing & Report card, status badge, verified report download button, and sample submission instructions. |
| `android/app/src/main/AndroidManifest.xml` | **Modified** | Added `<intent><action android:name="android.intent.action.VIEW"/><data android:scheme="upi"/></intent>` to `<queries>` block for Android 11+ visibility. |
| `src/server/tests/verify-rmseller-lab-testing-lab01.ts` | **Created** | Automated test suite verifying all 18 mandatory sprint test cases. |

---

### 3. Detailed Implementation Highlights

#### A. Domain Layer (`lab_testing_model.dart`)
- **Official Rate Card:**
  - Standard Parameters: Crude Protein (₹200), Fat / Oil (₹150), Crude Fiber (₹200), AIA (₹200), Moisture (₹100), Calcium (₹450), Salt (₹480), Urea (₹550), Starch (₹500), Phosphorus (₹500), Total Energy (₹850), Metabolic Energy (₹850), Total Digestive Nutrients (₹750), Total Ash (₹150), FFA (₹100).
  - Unpriced Parameter: `Other (Custom Parameter)` with `listedCharge: null`. Zero invented price.
  - Deduplication: `calculateTotal` ensures selecting tests cannot double count.
- **Payment Lifecycle States:**
  - `awaitingPayment`: Initial state upon test selection.
  - `paymentPending`: Active state upon UPI app launch.
  - `paymentFailed`: Returned if bank confirms transaction failure.
  - `paidVerified`: Set strictly upon trusted backend ledger verification.
  - `requestSubmitted`: Synchronized to `lab_tests` table.
  - `reportAvailable`: Final state when verified report file is attached.

#### B. Data Layer (`lab_testing_repository.dart`)
- **UPI Deep Link Generation:**
  - Generates standard `upi://pay?pa=...&pn=...&am=...&cu=INR&tn=...&tr=...` URI.
  - Launches external UPI application via `url_launcher`.
  - Sets request status to `paymentPending`. Does **not** mark as paid.
- **Trusted Backend Verification:**
  - `verifyPaymentWithBackend`: Validates transaction reference against authoritative backend confirmation ledger.
  - Idempotent: Skips re-processing if already marked `isPaid`.
  - Database Synchronization: Automatically creates/updates record in `lab_tests` table with status `'Testing In Progress'`.
  - Post-Payment Admin Alert: Automatically invokes `notifyAdministratorAfterPayment`.
- **Admin Notification Pipeline:**
  - Dispatches `LAB_UPDATE` event targeting users with `role = 'admin'`.
  - Deduplication: Computes unique `idempotencyKey = 'LAB-ADMIN-NOTIF-${request.id}-${request.transactionReference}'`.
  - Suppresses duplicate notifications if identical key was already dispatched.
  - Fault Tolerance: Notification failures are safely caught without rolling back verified payments.
- **Tenant-Isolated Report Retrieval:**
  - `getLabReportDetails`: Checks `user.company_id == lab_tests.company_id`.
  - Rejects cross-company report access with `status: 'Access Denied'`.
  - Generates time-limited signed URL (3600 seconds) from private Supabase bucket `brokerbridge_lab_evidence`.

#### C. Presentation Layer
- **Posting Form (`post_commodity_screen.dart`):**
  - Section 3 features a prominent optional switch: *"Request Certified Lab Testing (Optional) — Partner: Riddhi Siddhi Laboratory, Jaipur"*.
  - When switched OFF: Renders standard existing dropdown and certificate number input. Sellers proceed to post commodities without friction.
  - When switched ON: Renders interactive filter chips for all 16 tests, live charge calculation, Riddhi Siddhi Laboratory address, and the **"Pay via UPI — ₹<amount>"** action.
  - State feedback: Displays orange banner with **"Check Status"** and **"Re-open UPI"** when pending, and green verified banner once confirmed.
- **Listing Details Screen (`commodity_details_screen.dart`):**
  - Displays dedicated **Laboratory Testing & Report** card.
  - When report is available: Displays report number and **"View / Download Official Lab Report"** button which opens the signed URL in external viewer.
  - When testing in progress: Displays pending status and physical sample submission protocol (500g sealed bag to Jaipur address).

---

### 4. Boundary Invariants & Zero-Mutation Policy

- **Database Migrations:** 0 migrations added or modified in `supabase/migrations`. Fully utilized existing tables (`lab_tests`, `lab_test_results`, `master_laboratories`, `notifications`) and existing storage bucket (`brokerbridge_lab_evidence`).
- **Sibling Applications:** `apps/rmbuyer_mobile` and `apps/rmbroker_mobile` remain 100% untouched.
- **Counterparty Shield:** All buyer negotiations remain strictly broker-mediated; zero buyer PII exposed to seller.
