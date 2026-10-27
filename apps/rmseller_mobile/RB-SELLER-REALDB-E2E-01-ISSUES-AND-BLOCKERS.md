# RB-SELLER-REALDB-E2E-01 — Issues and Blockers

## 1. Overview
This document records all architectural limitations, environmental blockers, security gaps, and verified edge cases identified during the real-database execution of **RB-SELLER-REALDB-E2E-01**.

---

## 2. Issues & Limitations

### 2.1 Absence of a Dedicated Staging Environment
- **Status:** **Operational Limitation** (Documented in prior sprints, re-verified in Phase 1).
- **Finding:** No separate staging Supabase project or staging database branch exists. All environment configurations point to the production project `imztlkvkxzeaekxvmcfe.supabase.co`.
- **Mitigation Executed:** Real-database testing was conducted strictly under the verified, authorized test seller account **Priya Singh** (`priya@gmail.com`) and firm **Priya123** (`b543d6c6-85a7-4f13-a048-1967c05bb71e`), which has zero commercial listings. All test lots were tagged with unique prefixes and cleaned up post-test.
- **Recommendation:** Provision a dedicated Supabase staging project for continuous automated integration and end-to-end testing before broader commercial deployment.

### 2.2 Unprovisioned Auth Accounts (`seller.bikaner@gmail.com` and `seller@demo.com`)
- **Status:** **Known Account Issue** (Audited in RB-SELLER-INDIVIDUAL-LISTINGS-02, verified in Phase 2).
- **Finding:** Both accounts have active credentials in `auth.users`, but lack corresponding rows in `public.users`. Consequently, their `app_metadata` lacks a trusted server role, and they are not linked to a company.
- **App Behavior:** Verified that `SellerProfileRepository.checkListingReadiness()` cleanly detects the missing `public.users` record and returns `ListingReadinessStatus.incomplete` with the clear explanation: *"Your account is not yet provisioned in the database. Please contact support."*
- **Resolution Staged:** The administrative provisioning script `supabase/proposed/provision_individual_seller_identity.sql` is ready to safely provision these accounts with `role = 'seller'` and `company_id = NULL` once approved by platform administrators.

### 2.3 Lab Report Real Storage Upload
- **Status:** **Deferred / Feature Limitation** (Documented in Phase 9).
- **Finding:** The Supabase Storage buckets (`brokerbridge_lab_evidence`, `brokerbridge_documents`) are private and lack server-side MIME type or file size constraints. Complete client-to-storage upload pipeline for PDF certificates is not fully integrated in `apps/rmseller_mobile`.
- **Safety Verification:** Verified that `CreateCommodityDto.toSupabaseInsert()` safely handles local phone file paths by excluding local file paths from `lab_report_file_url` when no server upload has occurred, preventing local device paths from being saved to the database. Ordinary commodity posting does not require lab reports and functions fully without them.

### 2.4 Payment Verification Simulation
- **Status:** **Security & Payment Safety Rule** (Strictly observed).
- **Finding:** There is no live UPI payment gateway integration on the mobile client. Payment verification in lab testing flows relies on client-entered reference strings.
- **Safety Policy Compliance:** Zero real payments, mock transactions, or financial commitments were executed during this sprint. Ordinary supply lot posting does not require payments.

### 2.5 Android Physical Device Initial Session State
- **Status:** **Expected Behavior Verified**.
- **Finding:** When freshly installed on the physical Xiaomi Redmi Note 5 Pro (`e0d9da95`), the application launches on `My Commodities` and displays:
  *"Something went wrong. Failed to load commodity inventory. Your session has expired. Please sign in again."* with a **Try Again** button.
- **Root Cause:** A fresh installation on a clean device has no cached Gotrue session token in secure storage. The route guard correctly permits the user to navigate to sign in or retry.

---

## 3. Blockers Summary
- **Critical Blockers Encountered:** **0**
- **Safe Execution Workarounds:**
  - Used authorized test account `priya@gmail.com` for company-owned flow.
  - Used authorized test account `neha@gmail.com` for cross-company isolation check.
  - Used active broker `b354958e-779a-41f2-b7a3-5899eca32e32` for broker assignment checks.
- **All 16 real-database test scenarios passed without blocking errors.**
