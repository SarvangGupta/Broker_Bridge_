# RB-SELLER-PROFILE-INVOICE-01 — Architecture & Dependency Audit Report

**Sprint Identifier:** `RB-SELLER-PROFILE-INVOICE-01`  
**Application Target:** RM Seller Mobile (`apps/rmseller_mobile`)  
**Scope:** Invoice-assisted profile updates, bank details, explicit save confirmation, document storage, and administrator-visible change history.  
**Execution Status:** IN PROGRESS (Phase 1 Complete)  
**Date:** 2026-10-28  

---

## 1. Executive Summary

This architecture and dependency audit investigates the current state of Seller Profile management in `apps/rmseller_mobile` and the associated Supabase backend. The objective is to design and implement an enterprise-grade, invoice-assisted profile update mechanism, bank account support, mandatory explicit save confirmation, and secure administrative audit logging without introducing regression into existing features.

---

## 2. Authoritative Profile Fields & Update APIs

### 2.1 Backend Schema Baseline (`public.users` & `public.companies`)
From `supabase/migrations/0001_init_users_and_companies.sql` and subsequent migrations:
- **`public.users`:**
  - `id` (uuid, PK) — Authenticated user identity
  - `name` (text, NOT NULL) — Seller contact person name
  - `mobile` (text) — Registered phone number
  - `email` (text) — Business/login email
  - `role` (text) — Security role (`seller`, `buyer`, `broker`, `admin`)
  - `status` (boolean) — Account activation state
  - `company_id` (uuid, FK `companies.id`) — Associated corporate firm
- **`public.companies`:**
  - `id` (uuid, PK) — Company entity
  - `name` (text, NOT NULL) — Registered firm name
  - `gst` (text) — 15-character GSTIN
  - `business_type_id` (text) — Enterprise category
  - `state_id` (text) — State code
  - `district_id` (text) — District code
  - `is_verified` (boolean, added in `0015_add_company_trust_scores.sql`)
  - `trust_score` (integer, added in `0015_add_company_trust_scores.sql`)
- **Supabase Auth (`auth.users.raw_user_meta_data`):**
  - `default_warehouse` / `warehouse` / `warehouses`: Registered warehouse locations synchronized by `SellerProfileRepository`.

### 2.2 Client-Side Profile Repository (`SellerProfileRepository`)
**File:** `apps/rmseller_mobile/lib/features/profile/data/seller_profile_repository.dart`
- `getProfile()`: Reads from `public.users` and `public.companies` if authenticated; rehydrates offline and cached values from `SecureStorageService`.
- `updateProfile(SellerProfileModel)`:
  - Updates `name` and `mobile` on `public.users`.
  - Updates `name`, `gst`, `state_id`, `district_id` on `public.companies`.
  - Persists godown metadata to `auth.users.raw_user_meta_data` via `updateUser(UserAttributes(data: ...))`.
  - Encrypts and caches values in `SecureStorageService`.

---

## 3. Bank Detail Storage Audit

### 3.1 Existing State
- **Database:** Neither `public.users` nor `public.companies` contains columns for bank accounts (`account_number`, `ifsc`, `bank_name`, `account_holder_name`, `branch_name`).
- **Client Models:** `SellerProfileModel` does not contain bank fields.
- **Client Security:** `SecureStorageService` does not have bank-specific keys.

### 3.2 Required Capability & Data Model
Bank details must be introduced into `SellerProfileModel` as an embedded domain entity:
- `accountHolderName`: String (2–70 chars)
- `bankName`: String (2–100 chars)
- `accountNumber`: String (9–18 digits)
- `ifscCode`: String (11-character Indian Financial System Code, regex `^[A-Z]{4}0[A-Z0-9]{6}$`)
- `branchName`: String (optional/extracted)
- `isVerified`: boolean (strictly `false` unless validated via banking API)
- `verificationStatus`: String (`unverified`, `pending_review`, `verified`)

### 3.3 Privacy & Security Constraints
- **Masking:** Account numbers must be displayed as masked (e.g., `•••• •••• •••• 1234` or `XXXX-XXXX-1234`) in standard view modes.
- **Zero-Secret Policy:** No UPI PINs, net-banking passwords, debit card PINs, or OTPs can ever be stored, requested, or logged.
- **Audit Masking:** Full account numbers must never appear in plaintext in audit logs or server logs.
- **Non-destructive Migration:** Schema changes for bank details must be isolated in a proposed migration script with complete rollback support.

---

## 4. Invoice & Document Storage Audit

### 4.1 Existing Storage Configuration
From `supabase/migrations/manual_storage_rls.sql` and `manual_lab_storage_rls.sql`:
- Existing private buckets:
  - `brokerbridge_documents`: Deal and dispatch documentation (`deals/{deal_id}/{filename}`).
  - `brokerbridge_lab_evidence`: Laboratory quality test reports (`lab_evidence/{availability_id}/{filename}`).
- RLS Policies enforce authenticated write and scoped deal/company read access. Neither bucket is public.

### 4.2 Proposed Invoice Storage Architecture
- **Proposed Bucket:** `brokerbridge_seller_invoices` (private, non-public).
- **Storage Path Hierarchy:** `profile_invoices/{seller_company_id}/{timestamp}_{filename}`.
- **Local Draft vs Server Saved:**
  - Local camera/gallery picks reside temporarily in application sandbox (`localDraftPath`).
  - They are designated `isUploaded: false` and are NOT persisted document URLs.
  - Only upon explicit **Confirm and Save** is the file uploaded to the storage bucket, producing an authoritative storage key / signed URL.

---

## 5. Audit Infrastructure & Administrative History

### 5.1 Existing State
- No profile audit trail table exists in Supabase.
- Changes to `public.users` and `public.companies` are unversioned at the application level.

### 5.2 Required Capability
- **Target Table:** `public.seller_profile_audit_logs`
  - `id`: uuid (Primary Key)
  - `seller_id`: uuid (FK `public.users.id`, NOT NULL)
  - `company_id`: uuid (FK `public.companies.id`, nullable for individual sellers)
  - `actor_id`: uuid (FK `public.users.id`, user making the change)
  - `operation_type`: text (`MANUAL_EDIT`, `INVOICE_ASSISTED_EDIT`)
  - `changed_fields`: text[] (array of field names modified)
  - `change_summary`: text (sanitized, human-readable summary; no sensitive credentials or raw account numbers)
  - `source`: text (`rmseller_mobile`)
  - `request_id`: text (idempotency key / client operation identifier)
  - `created_at`: timestamptz (server-generated timestamp via `now()`)
- **Security & RLS:**
  - Write: Trigger or restricted INSERT policy ensuring sellers can only log changes matching their own authenticated ID.
  - Read: Strictly restricted to users with `role = 'admin'` via RLS. Sellers cannot read or tamper with other sellers' or their own audit records.

---

## 6. Camera, Gallery & OCR Integrations

### 6.1 Available Packages in `apps/rmseller_mobile`
From `pubspec.yaml`:
- `image_picker: ^1.2.4` (Available: Supports Camera capture and Gallery photo selection)
- `file_picker: ^13.1.0` (Available: Supports document picking)

### 6.2 OCR Engine Audit & Constraints
- No on-device OCR native library (such as `google_mlkit_text_recognition`) is bundled in `pubspec.yaml`.
- In accordance with the prompt's Zero-Friction and Honesty policies:
  - Genuine image capture, preview, retake, replace, zoom, and cancel must be fully implemented.
  - A real extraction engine interface with Indian tax document parsing rules (GSTIN, IFSC, PIN, Bank A/C) must be implemented.
  - When raw text or supported documents are fed, it must extract actual patterns without fabricating missing data.
  - If a device or platform lacks bundled native OCR binaries, the system must transparently report the OCR integration status as blocked/unsupported and allow manual review, without relying on fake mock extraction in production paths.

---

## 7. Gap Analysis & Proposed Architectural Blueprint

| Requirement | Current Capability | Gap / Action Needed |
|---|---|---|
| **Scan Business Invoice Option** | More tab lists Profile, Settings, Reports, Help | Add **"Scan Business Invoice"** in Profile overflow menu & More screen |
| **Profile Sections** | Business Info & Godown cards | Add dedicated Bank Details, Invoice Documents, and Review Changes cards |
| **Bank Details Model** | Absent | Add `SellerBankDetails` with validation & masking |
| **Explicit Confirmation Workflow** | Saves directly on "Save" button | Introduce mandatory side-by-side Diff Review modal with explicit "Confirm and Save" |
| **Save Rollback on Cancel/Back** | Partially supported | Ensure Back, Dismissal, or Cancel never persist changes; keep unsaved draft on failure |
| **Profile Audit History** | Absent | Prepare migration `0050_add_seller_bank_details_and_audit_history.sql` & rollback |
| **Document Storage** | Deal & Lab buckets exist | Design private `brokerbridge_seller_invoices` bucket with strict RLS |

---

## 8. Verification Strategy
1. **Unit & Widget Tests:**
   - Bank details validation and account number masking tests.
   - Genuine invoice capture, inspection, replace, and cancel tests.
   - Non-fabrication tests for missing/partial invoice fields.
   - Mandatory confirmation workflow tests (verifying no writes occur before explicit confirmation).
   - Back, Cancel, and Discard tests confirming no database writes.
   - Draft preservation upon simulated network/server failure.
   - Masked audit logging tests ensuring zero leak of credentials or full account numbers.
2. **Automated Verification:**
   - Execute all Flutter widget tests with `& "D:\flutter_sdk\flutter\bin\flutter.bat" test`.
   - Run Dart analyzer with zero errors.
   - Validate on connected physical Android device (`e0d9da95`).
