# RB-SELLER-INDIVIDUAL-LISTINGS-02 — Implementation Report

## 1. Executive Summary
This implementation fulfills **RB-SELLER-INDIVIDUAL-LISTINGS-02 (Approved Individual Seller Ownership)** in `apps/rmseller_mobile`. It enables sellers without an enterprise firm to list and manage commodity lots under their trusted authenticated database identity (`seller_user_id`), while keeping company-linked sellers on their company-owned workflow (`company_id`).

---

## 2. App Architecture & Code Modifications

### 2.1 Domain Entities & Invariant Enforcement
**File:** [commodity_model.dart](file:///c:/Users/dell/.gemini/antigravity-ide/scratch/Broker_Bridge_/apps/rmseller_mobile/lib/features/commodities/domain/commodity_model.dart)
- Added `companyId` and `sellerUserId` to `SellerCommodity`.
- Added getters `isIndividualOwned` and `isCompanyOwned`.
- Updated `CreateCommodityDto.toSupabaseInsert({String? companyId, String? sellerUserId})`:
  Enforces mutual exclusivity in application logic prior to database submission:
  ```dart
  if (finalCompanyId == null && finalSellerUserId == null) {
    throw ArgumentError('A commodity lot must have either a companyId or a sellerUserId.');
  }
  if (finalCompanyId != null && finalSellerUserId != null) {
    throw ArgumentError('A commodity lot cannot have both companyId and sellerUserId set simultaneously.');
  }
  ```

### 2.2 Profile Readiness Verification
**File:** [seller_profile_repository.dart](file:///c:/Users/dell/.gemini/antigravity-ide/scratch/Broker_Bridge_/apps/rmseller_mobile/lib/features/profile/data/seller_profile_repository.dart)
- Updated `checkListingReadiness()`:
  - Verifies presence in authoritative `public.users` table. If missing, returns `ListingReadiness.incomplete(['Your account is not yet provisioned in the database.'])`.
  - Verifies active seller role (`role == 'seller'` and `status != false`). Self-asserted client metadata is ignored.
  - If `company_id == null`, marks readiness as `ListingReadiness.complete(firmName: individualName)` (or `'Individual Seller'`).
  - If `company_id` is present, queries `companies` table and carries forward regional defaults.
  - Network errors remain strictly classified as `ListingReadinessStatus.unverified`, never "incomplete".

### 2.3 Dual Ownership Resolution & Scoping in Repository
**File:** [commodities_repository.dart](file:///c:/Users/dell/.gemini/antigravity-ide/scratch/Broker_Bridge_/apps/rmseller_mobile/lib/features/commodities/data/commodities_repository.dart)
- Introduced `SellerOwnership` model:
  - `SellerOwnership.company(companyId)`
  - `SellerOwnership.individual(userId)`
  - Provides scoped cache keys to prevent cross-account cache bleed on shared devices.
- `_resolveSellerOwnership(...)`:
  - Authoritatively queries `public.users` for current authenticated session.
  - Returns appropriate ownership type based on `company_id`.
- `createCommodity`:
  - Submits `company_id` for company sellers or `seller_user_id` for individual sellers.
  - Requires server confirmation (`select('id, created_at, status').single()`).
  - Catches duplicate violations (`23505`) and RLS authorization rejections (`42501`) with clear user messages.
- `getCommodities`:
  - Queries `company_id = compId` for company sellers.
  - Queries `company_id IS NULL AND seller_user_id = uid` for individual sellers.
  - Truly empty lists are returned as `[]`, preserving empty states distinctly from server errors.
- `updateCommodityStatus`, `updateCommodityPrice`, `updateCommodityBroker`:
  - Updates scoped by `company_id = compId` or `company_id IS NULL AND seller_user_id = uid`.
  - Requires server confirmation (`rows.isNotEmpty`), preventing unconfirmed local state updates.
  - Validates broker registration and active status.

### 2.4 Removal of Demo Data Fallbacks for Real Online Accounts
**File:** [seller_deals_repository.dart](file:///c:/Users/dell/.gemini/antigravity-ide/scratch/Broker_Bridge_/apps/rmseller_mobile/lib/features/deals/data/seller_deals_repository.dart)
- Updated `getDeals()`: when connected online (`client != null`), returns authoritative server deals (empty `[]` if none). Mock/demo deals are restricted strictly to offline test mode.

### 2.5 Presentation Layer
**File:** [seller_home_screen.dart](file:///c:/Users/dell/.gemini/antigravity-ide/scratch/Broker_Bridge_/apps/rmseller_mobile/lib/features/home/presentation/seller_home_screen.dart)
- Dynamic header: Displays "Individual Seller Desk" when the seller is not linked to a company, rather than showing a generic or fallback corporate title.

---

## 3. Production Approval Checklist

> [!IMPORTANT]
> In accordance with the **Zero-Friction Safety Policy**, zero schema migrations, RLS changes, or database user record modifications have been applied to production. All operations below are prepared and staged as proposed scripts awaiting explicit review and administrative approval.

### 3.1 Migration 0048 (`0048_reconciled_seller_listings_and_broker_check.sql`)
- [ ] **Preflight Validation (Read-Only):**
  - Verify duplicate lots: `SELECT count(*) FROM public.availabilities GROUP BY company_id, lot_number HAVING count(*) > 1;` (must be 0).
  - Verify invalid owners: `SELECT count(*) FROM public.availabilities WHERE (company_id IS NULL AND seller_user_id IS NULL) OR (company_id IS NOT NULL AND seller_user_id IS NOT NULL);` (must be 0).
  - Verify active brokers: `SELECT count(*) FROM public.availabilities a LEFT JOIN public.users u ON a.broker_id = u.id WHERE a.broker_id IS NOT NULL AND (u.id IS NULL OR LOWER(u.role) != 'broker' OR u.status != true);` (must be 0).
- [ ] **Execution:** Apply `supabase/proposed/0048_reconciled_seller_listings_and_broker_check.sql` via Supabase SQL Editor or migration tool.
- [ ] **Post-Application Verification:**
  - Verify column `seller_user_id` exists in `public.availabilities`.
  - Verify `availabilities_owner_check` constraint is active.
  - Verify partial indexes `availabilities_company_lot_number_key` and `availabilities_individual_lot_number_key` are valid.
- [ ] **Rollback Plan:** Stored in `supabase/proposed/rollback_0048.sql`. Aborts automatically if individual-owned lots exist.

### 3.2 Individual Seller Provisioning (`provision_individual_seller_identity.sql`)
- [ ] **Execution:** Run `supabase/proposed/provision_individual_seller_identity.sql` to install the administrative provisioning function.
- [ ] **Account Provisioning:**
  Execute for the two identified seller accounts:
  ```sql
  SELECT public.provision_individual_seller('seller.bikaner@gmail.com', 'Bikaner Kisan Trader');
  SELECT public.provision_individual_seller('seller@demo.com', 'Demo Individual Seller');
  ```
- [ ] **Post-Provisioning Verification:**
  - Verify row in `public.users` with `role = 'seller'`, `status = true`, `company_id IS NULL`.
  - Verify `auth.users.raw_app_meta_data->>'role' = 'seller'`.
