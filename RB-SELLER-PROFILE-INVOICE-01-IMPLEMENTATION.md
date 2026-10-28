# RB-SELLER-PROFILE-INVOICE-01: Implementation Report & Administrator Guide

**Sprint Identifier:** `RB-SELLER-PROFILE-INVOICE-01`  
**Target Application:** `apps/rmseller_mobile`  
**Execution Policy:** Zero-Friction Execution Policy (no unauthorized production schema mutations, exact migrations/rollbacks prepared in `supabase/proposed/`, zero mock extraction in production paths, zero background autosaves).

---

## 1. Executive Summary

This implementation delivers the end-to-end invoice-assisted Seller profile workflow, secure bank details management, mandatory side-by-side confirmation gating, and immutable administrator audit history in `apps/rmseller_mobile`.

### Core Architectural Principles Implemented:
1. **Zero Database Write Before Confirmation:** No manual edit, camera capture, or invoice OCR result can mutate the database or secure cache without the seller actively reviewing proposed changes side-by-side against authoritative values and tapping **Confirm and Save**.
2. **Draft Preservation on Failure:** Network drops or backend timeouts preserve all entered drafts and extracted suggestions. Retrying an update never duplicates audit logs or corrupts state.
3. **Banking Privacy & Masking:** Bank account numbers are strictly masked (`•••• 1234`) in ordinary view modes and audit summaries. PINs, UPI secrets, passwords, and OTPs are explicitly rejected from model schemas and never logged. Verification status is marked `unverified` unless confirmed via verified banking webhooks.
4. **Honest Document Handling:** If native OCR engines are unavailable on device, the app reports engine status transparently rather than synthesizing mock extraction data in production code paths. Document uploads use private buckets and distinguish local file drafts from server-saved URLs.
5. **Tamper-Evident Audit History:** Every committed profile change records an auditable event with timestamp, actor ID, changed fields, operation source (`MANUAL_EDIT`, `INVOICE_ASSISTED_EDIT`), and safe masked summaries.

---

## 2. Component & Architecture Breakdown

### 2.1 Domain Models
- [seller_bank_details.dart](file:///c:/Users/dell/.gemini/antigravity-ide/scratch/Broker_Bridge_/apps/rmseller_mobile/lib/features/profile/domain/seller_bank_details.dart):
  - Encapsulates `accountHolderName`, `bankName`, `accountNumber`, `ifscCode`, `branchName`, and `verificationStatus`.
  - Account number validation (9–18 numeric digits).
  - Strict Indian Financial System Code (IFSC) validation (`^[A-Z]{4}0[A-Z0-9]{6}$`).
  - Getter `maskedAccountNumber` (e.g., `•••• •••• •••• 1098`) for safe UI rendering.
  - Getter `safeAuditDisplay` (e.g., `HDFC Bank A/C ending in ...1098 (IFSC: HDFC0001234)`) guaranteeing zero sensitive digit leakage.
- [seller_profile_audit_entry.dart](file:///c:/Users/dell/.gemini/antigravity-ide/scratch/Broker_Bridge_/apps/rmseller_mobile/lib/features/profile/domain/seller_profile_audit_entry.dart):
  - Model representing `seller_profile_audit_logs` records.
  - Captures `sellerId`, `actorId`, `operationType`, `changedFields`, `changeSummary`, `createdAt`, `requestId`, and `metadata`.
- [invoice_extracted_data.dart](file:///c:/Users/dell/.gemini/antigravity-ide/scratch/Broker_Bridge_/apps/rmseller_mobile/lib/features/profile/domain/invoice_extracted_data.dart):
  - Structured extraction container for unverified suggestions: `firmName`, `gstin`, `addressLine`, `stateName`, `districtName`, `pinCode`, `invoiceNumber`, `invoiceDate`, `bankDetails`, and `rawExtractedFields`.
  - Non-fabrication rule: only fields with confidence > 0.0 and positive matches are marked as suggestions.
- [seller_profile_model.dart](file:///c:/Users/dell/.gemini/antigravity-ide/scratch/Broker_Bridge_/apps/rmseller_mobile/lib/features/profile/domain/seller_profile_model.dart):
  - Extended with `bankDetails`, `invoiceDocumentUrl`, and `invoiceDocumentName`.

### 2.2 Data & Extraction Services
- [invoice_ocr_service.dart](file:///c:/Users/dell/.gemini/antigravity-ide/scratch/Broker_Bridge_/apps/rmseller_mobile/lib/features/profile/data/invoice_ocr_service.dart):
  - Production-grade regex engine parsing raw invoice text:
    - GSTIN: `\b\d{2}[A-Z]{5}\d{4}[A-Z]{1}[A-Z0-9]{1}Z[A-Z0-9]{1}\b`
    - IFSC: `\b[A-Z]{4}0[A-Z0-9]{6}\b`
    - Bank Account Number: `\b\d{9,18}\b` adjacent to Account/A/C keywords
    - PIN Code: `\b[1-9][0-9]{5}\b`
    - Firm Name & Address from header blocks
  - Transparent engine availability check: `isEngineAvailable` accurately checks device capabilities; never synthesizes fake mock data in production paths.
- [invoice_document_service.dart](file:///c:/Users/dell/.gemini/antigravity-ide/scratch/Broker_Bridge_/apps/rmseller_mobile/lib/features/profile/data/invoice_document_service.dart):
  - Supports genuine camera capture (`ImageSource.camera`), gallery selection (`ImageSource.gallery`), and PDF file picking.
  - Uploads to private Supabase bucket (`brokerbridge_seller_invoices`, with fallback to `brokerbridge_documents/profile_invoices/{companyId}/`).
  - Distinguishes local draft file paths from persisted URLs.
- [seller_profile_repository.dart](file:///c:/Users/dell/.gemini/antigravity-ide/scratch/Broker_Bridge_/apps/rmseller_mobile/lib/features/profile/data/seller_profile_repository.dart):
  - Handles profile persistence across `users`, `companies`, user metadata, and `SecureStorageService`.
  - Writes bank details safely into company metadata / columns.
  - Implements `logProfileAuditEntry`: logs atomic audit record only after successful profile save.
  - Implements `getProfileAuditHistory`: allows administrative queries while enforcing role checks.

### 2.3 User Interface & Workflow Components
- [seller_profile_screen.dart](file:///c:/Users/dell/.gemini/antigravity-ide/scratch/Broker_Bridge_/apps/rmseller_mobile/lib/features/profile/presentation/seller_profile_screen.dart):
  - Overflow menu item: **Scan Business Invoice** (`profile_menu_scan_invoice`).
  - View Mode:
    - Section 1: Personal & Account Details
    - Section 2: Business / Firm Details
    - Section 3: Registered Office Address
    - Section 4: Shop & Godown Location (Mandi Hub)
    - Section 5: **Bank Details** (Masked account number, IFSC, Bank Name, unverified chip)
    - Section 6: **Verified Business Documents** (Attached invoice preview card)
  - Edit Mode:
    - Dedicated interactive form fields for all 6 sections.
    - **Invoice Scanning Card** with Camera, Gallery, and Document pickers.
    - Invoice preview thumbnail with tap-to-inspect, retake, replace, or remove dialog.
    - Suggestion banner displaying prefilled values with "Prefilled from Invoice" badges.
    - Save button launches the mandatory confirmation sheet instead of immediate saving.
- [profile_review_confirmation_sheet.dart](file:///c:/Users/dell/.gemini/antigravity-ide/scratch/Broker_Bridge_/apps/rmseller_mobile/lib/features/profile/presentation/widgets/profile_review_confirmation_sheet.dart):
  - Modal bottom sheet displaying side-by-side diff table:
    - Field name
    - Current authoritative value
    - Proposed new value
  - Highlights bank account updates with security notice.
  - **Confirm and Save** button executes server save.
  - **Keep Editing** button dismisses sheet and preserves draft without writing to server.
- [invoice_preview_dialog.dart](file:///c:/Users/dell/.gemini/antigravity-ide/scratch/Broker_Bridge_/apps/rmseller_mobile/lib/features/profile/presentation/widgets/invoice_preview_dialog.dart):
  - Full inspection of captured invoice or selected PDF.
  - Quick action buttons: Retake (Camera), Replace (Gallery), Remove Document, or Close.
- [seller_more_screen.dart](file:///c:/Users/dell/.gemini/antigravity-ide/scratch/Broker_Bridge_/apps/rmseller_mobile/lib/features/profile/presentation/seller_more_screen.dart):
  - Added **Scan Business Invoice** tile (`more_menu_scan_invoice`) with camera icon and direct route navigation to `profile?scan=true`.
- [app_router.dart](file:///c:/Users/dell/.gemini/antigravity-ide/scratch/Broker_Bridge_/apps/rmseller_mobile/lib/app/router/app_router.dart):
  - Route `/profile` accepts `scan` query parameter to automatically activate invoice scanning mode.

---

## 3. Database Migrations & Rollback Scripts

In strict accordance with the Zero-Friction Execution Policy, no schema mutations were executed on production. The exact migration scripts have been created and placed in `supabase/proposed/`:

### 3.1 Migration: [0050_add_seller_bank_details_and_audit_history.sql](file:///c:/Users/dell/.gemini/antigravity-ide/scratch/Broker_Bridge_/supabase/proposed/0050_add_seller_bank_details_and_audit_history.sql)
1. **Companies Extension:**
   - Adds `bank_account_holder_name TEXT`
   - Adds `bank_name TEXT`
   - Adds `bank_account_number TEXT` (encrypted / restricted via RLS)
   - Adds `bank_ifsc_code VARCHAR(11)` with uppercase regex constraint
   - Adds `bank_branch_name TEXT`
   - Adds `bank_verification_status VARCHAR(20) DEFAULT 'unverified'`
   - Adds `invoice_document_url TEXT`
   - Adds `invoice_document_name TEXT`
2. **Audit History Table (`seller_profile_audit_logs`):**
   - Columns: `id UUID PRIMARY KEY`, `seller_id UUID NOT NULL REFERENCES users(id)`, `actor_id UUID NOT NULL REFERENCES users(id)`, `operation_type VARCHAR(50)`, `changed_fields TEXT[]`, `change_summary TEXT NOT NULL`, `request_id TEXT`, `metadata JSONB`, `created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()`.
   - Indexes on `seller_id`, `actor_id`, and `created_at DESC`.
   - Strict immutability: Revokes `UPDATE` and `DELETE` on `seller_profile_audit_logs` from all roles.
3. **Row Level Security (RLS) Policies:**
   - `SELECT`: Only users with `role = 'admin'` or `role = 'super_admin'` in `users` table or JWT app metadata can read audit history.
   - `INSERT`: Authenticated users can insert audit records only where `seller_id = auth.uid()` or `actor_id = auth.uid()`.
4. **Private Storage Bucket (`brokerbridge_seller_invoices`):**
   - Private bucket (`public = false`) with 10MB file limit and restricted MIME types (JPEG, PNG, WebP, PDF).
   - RLS policies ensuring sellers can only upload and read files within their company folder (`company_id/*`).

### 3.2 Rollback Script: [rollback_0050.sql](file:///c:/Users/dell/.gemini/antigravity-ide/scratch/Broker_Bridge_/supabase/proposed/rollback_0050.sql)
- Drops storage policies and bucket.
- Drops audit policies, triggers, and `seller_profile_audit_logs` table.
- Drops added columns from `companies` table.

---

## 4. Concise Administrator Guide to Profile-Change History

### 4.1 Overview
The profile change audit system provides compliance, dispute resolution, and security oversight for all Seller profile modifications. Every manual edit and invoice-assisted update generates an immutable audit record.

### 4.2 Audit Record Structure
| Column Name | Type | Description |
|---|---|---|
| `id` | UUID | Unique identifier for the audit event |
| `seller_id` | UUID | Foreign key to `users.id` representing the seller account modified |
| `actor_id` | UUID | Foreign key to `users.id` representing who performed the change |
| `operation_type` | VARCHAR(50) | `MANUAL_EDIT`, `INVOICE_ASSISTED_EDIT`, or `ADMIN_ADJUSTMENT` |
| `changed_fields` | TEXT[] | Array of field names modified (e.g. `['company_name', 'bank_details']`) |
| `change_summary` | TEXT | Safe human-readable summary with masked bank account numbers |
| `request_id` | TEXT | Client or server operation tracing ID |
| `metadata` | JSONB | Additional non-sensitive diagnostic info (e.g., client app version) |
| `created_at` | TIMESTAMPTZ | Authoritative server timestamp (PostgreSQL `NOW()`) |

### 4.3 Administrator SQL Queries

#### Query 1: View Recent Profile Changes Across All Sellers
```sql
SELECT 
    l.created_at,
    l.operation_type,
    u.name AS seller_name,
    u.email AS seller_email,
    c.name AS company_name,
    l.changed_fields,
    l.change_summary,
    l.actor_id
FROM seller_profile_audit_logs l
JOIN users u ON l.seller_id = u.id
LEFT JOIN companies c ON u.company_id = c.id
ORDER BY l.created_at DESC
LIMIT 50;
```

#### Query 2: Trace Audit History for a Specific Seller
```sql
SELECT 
    l.id,
    l.created_at,
    l.operation_type,
    l.changed_fields,
    l.change_summary,
    l.metadata
FROM seller_profile_audit_logs l
WHERE l.seller_id = 'YOUR_SELLER_UUID'
ORDER BY l.created_at DESC;
```

#### Query 3: Inspect Bank Account Updates Specifically
```sql
SELECT 
    l.created_at,
    u.name AS seller_name,
    l.operation_type,
    l.change_summary
FROM seller_profile_audit_logs l
JOIN users u ON l.seller_id = u.id
WHERE 'bank_details' = ANY(l.changed_fields)
ORDER BY l.created_at DESC;
```

### 4.4 Security & Privacy Guarantees
- **No Secret Storage:** Plaintext bank account numbers, PINs, or raw OCR payloads are NEVER written to `change_summary` or `metadata`.
- **Masking Standard:** Account numbers are masked to the last 4 digits (e.g., `...1098`).
- **Zero Fabrication:** Audit records are only created upon verified database commits.
- **Strict Immutability:** No user or administrator can edit or delete rows in `seller_profile_audit_logs`.

---

## 5. ADDENDUM — Seller Commodity Expertise & Posting Priority

### 5.1 Overview & Scope
Extends sprint `RB-SELLER-PROFILE-INVOICE-01` to incorporate seller commodity expertise declaration and posting prioritization. Commodity expertise functions as an intelligent preference and listing accelerator—it **never** acts as a selling restriction or filter. Sellers retain full freedom to list and trade any permitted platform commodity.

### 5.2 Workflows Implemented
1. **Workflow A: Invoice OCR Commodity Suggestions**
   - [invoice_ocr_service.dart](file:///c:/Users/dell/.gemini/antigravity-ide/scratch/Broker_Bridge_/apps/rmseller_mobile/lib/features/profile/data/invoice_ocr_service.dart) extracts item lines and agricultural trading keywords (Wheat, Mustard, Chana, Guar, Soybean, Maize, Barley, etc.).
   - Discovered commodity names are presented as actionable suggestions in `invoice_commodity_suggestions_box`.
   - Suggestions match against authoritative `MasterCommodity` entries via normalized name matching.
   - The seller reviews suggestions individually, adding or dismissing them. No invoice item is automatically added without seller review.
2. **Workflow B: Manual Catalogue Selection**
   - Sellers can open the commodity catalogue picker sheet (`btn_add_expertise_from_catalogue`) to select multiple commodities.
   - Selected commodities render as removable chips (`selected_expertise_chip_${id}`).
   - Existing selections are preserved when entering edit mode.
3. **Workflow C: Add Missing Custom Commodity**
   - In "My Commodity Expertise" section only, an "Add Commodity" action (`btn_add_custom_commodity`) is available.
   - Validates commodity name and category.
   - Normalized duplicate prevention (`matchesNormalized`, `areNamesMatching`) prevents duplicate entries.
   - If the name matches an existing verified catalogue commodity, it automatically links to that authoritative commodity.
   - Otherwise, it is saved as a pending custom commodity (`isApproved: false`) without mutating the global `master_commodities` table.
4. **Workflow D: Explicit Save & Audit Integration**
   - Zero database mutation occurs until the seller explicitly confirms in `ProfileReviewConfirmationSheet`.
   - Cancel/back discards drafts without saving.
   - Saved commodities update the profile and log `['Commodity Expertise']` in the admin audit history.
5. **Workflow E: Priority Commodity Ordering in Posting Flow**
   - In `PostCommodityScreen` and `CommodityPickerSheet`:
     - Saved expertise commodities appear first under **“My Expertise”** (`picker-expertise-header`).
     - All other active commodities appear below under **“All Commodities”** (`picker-all-commodities-header`).
     - Selecting an expertise commodity continues the standard listing creation flow.
     - Search filters across all sections without hiding non-expertise commodities.
     - If no expertise is configured, the complete catalogue renders without empty section clutter.
     - Expertise loading failure is non-blocking and gracefully falls back to the full catalogue.

### 5.3 Database & RLS Schema (Proposed)
- [0051_add_seller_commodity_expertise.sql](file:///c:/Users/dell/.gemini/antigravity-ide/scratch/Broker_Bridge_/supabase/proposed/0051_add_seller_commodity_expertise.sql):
  - Adds `commodity_expertise JSONB NOT NULL DEFAULT '[]'::jsonb` to `public.companies`.
  - Creates `public.seller_commodity_expertise` table with strict RLS policies.
  - Zero modifications to authoritative `public.master_commodities`.
- [rollback_0051.sql](file:///c:/Users/dell/.gemini/antigravity-ide/scratch/Broker_Bridge_/supabase/proposed/rollback_0051.sql):
  - Drops table and removes column safely.

