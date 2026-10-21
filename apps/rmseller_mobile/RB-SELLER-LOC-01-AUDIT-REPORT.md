# RB-SELLER-LOC-01 — Pre-Implementation Audit Report
## Location Forms, Warehouse/Loading Address & Mandi/District Corrections

**Project:** RMBroker  
**Application:** RM Seller App (`apps/rmseller_mobile`)  
**Sprint ID:** `RB-SELLER-LOC-01`  
**Date:** October 21, 2026  
**Auditor:** Antigravity AI Coding Agent  
**Status:** **AUDIT COMPLETE — READY FOR IMPLEMENTATION**

---

### 1. Executive Summary

During testing of the Seller App Commodity Posting workflow, location-related usability and data-correctness defects were identified:
1. **Long Inline Form Clutter:** Location entry was embedded directly into the primary posting form as a long, multi-field section, making the screen cumbersome and prone to scrolling fatigue on mobile devices.
2. **State/District/Mandi Filtering Defect:** When selecting states other than Rajasthan and Madhya Pradesh (such as Gujarat or Maharashtra), the district dropdown fell back to returning all districts from other states due to a fallback bug (`return fallbacks.isNotEmpty ? fallbacks : MasterCommodityData.verifiedDistricts;`), causing cross-state district contamination.
3. **Mandi vs District Confusion:** The form lacked a dedicated Mandi selection hierarchy; districts were labeled "Mandi District" with merged labels (e.g., "Bikaner Mandi Hub"), obscuring the physical APMC Mandi yard from the administrative district.
4. **Physical Loading vs Warehouse Storage vs Enterprise Office:** Sellers need to distinguish between:
   - The registered warehouse storage location (e.g., CWC / Mandi Yard godown),
   - The physical truck loading/dispatch platform (e.g., Gate 2, Shed 4), and
   - The corporate enterprise office HQ (e.g., Corporate Head Office).
   While `RB-SELLER-02` separated `loading_remarks` and `office_location`, the UI lacked a dedicated compact modal popup to configure and review these locations cleanly without elongating the main form.

---

### 2. Workspace & Git Preflight Status

- **Workspace Inspected:** `apps/rmseller_mobile/`
- **Current Git Branch:** `feature/broker-nilesh` (up to date with `vetkind/feature/broker-nilesh`)
- **Untracked / Preserved Files:**
  - `apps/rmseller_mobile/` (full mobile workspace intact)
  - `src/server/tests/verify-rmseller-*.ts` (existing sprint verification runners intact)
- **Sibling App Boundary Invariant:**
  - `apps/rmbuyer_mobile`: 0 modifications
  - `apps/rmbroker_mobile`: 0 modifications
  - `supabase/migrations`: 0 migrations or schema mutations (strictly adhering to Zero-Mutation policy)

---

### 3. Comprehensive Code & Data Contract Trace

#### A. Database Schema (`public.availabilities`)
Inspected `supabase/migrations/meta/0026_snapshot.json` and `src/server/db/schema.ts`:
```typescript
export const availabilities = pgTable('availabilities', {
  id: uuid('id').defaultRandom().primaryKey(),
  companyId: uuid('company_id').references(() => companies.id).notNull(),
  commodityId: uuid('commodity_id').references(() => masterCommodities.id).notNull(),
  gradeId: uuid('grade_id').references(() => masterGrades.id).notNull(),
  quantity: integer('quantity').notNull(),
  unitId: uuid('unit_id').references(() => masterUnits.id).notNull(),
  price: numeric('price').notNull(),
  stateId: uuid('state_id').references(() => masterStates.id).notNull(),
  districtId: uuid('district_id').references(() => masterDistricts.id).notNull(),
  visibility: text('visibility').default('global').notNull(),
  brokerId: uuid('broker_id'),
  status: text('status').default('Open').notNull(),
  lotNumber: text('lot_number'),
  totalQuantity: numeric('total_quantity').notNull(),
  availableQuantity: numeric('available_quantity').notNull(),
  askingPrice: numeric('asking_price').notNull(),
  confidentialMinimumPrice: numeric('confidential_minimum_price'),
  availableFrom: timestamp('available_from').defaultNow().notNull(),
  validUntil: timestamp('valid_until').notNull(),
  loadingStatus: text('loading_status').default('Not Ready').notNull(),
  loadingRemarks: text('loading_remarks'), // Stores actual physical loading/dispatch facility!
  version: integer('version').default(1).notNull(),
});
```

#### B. Master Catalogs
- **`master_states`**: Columns `id` (uuid), `name` (text), `code` (text).
- **`master_districts`**: Columns `id` (uuid), `name` (text), `state_id` (uuid referencing `master_states.id`).
- **`master_mandis`**: **Does not exist in the database schema.** There is no `master_mandis` table or `mandi_id` foreign key on `availabilities`.
- **Authoritative Resolution:** Mandi APMC yards are hierarchically organized under their respective administrative districts in the domain layer (`MasterMandi` catalog), and their selected yard details are persisted alongside the loading facility address in `loading_remarks` without breaking database contracts.

#### C. Enterprise Office Location Contract
- Inspected `companies` table and `public.users`:
  - `companies` stores `id`, `name`, `gst`, `state_id`, `district_id`.
  - The seller's enterprise office represents corporate headquarters belonging to the seller company, loaded via `SecureStorageService` / Supabase auth (`companyName`, `companyGst`, `officeLocation`).
  - It is independent of individual commodity lots. Changing a commodity's physical loading address must never overwrite or mutate the enterprise office address.

---

### 4. Confirmed Root Causes of Identified Defects

| Defect ID | Observed Issue | Confirmed Root Cause |
| :--- | :--- | :--- |
| **RC-01** | Cross-State District Pollution | In `commodities_repository.dart` (line 160):<br>`return fallbacks.isNotEmpty ? fallbacks : MasterCommodityData.verifiedDistricts;`<br>When a state with no local fallback districts was chosen (e.g. Gujarat or Maharashtra), it erroneously returned all fallback districts belonging to Rajasthan and MP. |
| **RC-02** | Incomplete State & District Catalogs | `MasterCommodityData.verifiedDistricts` only contained entries for Rajasthan (`RJ`) and Madhya Pradesh (`MP`). Gujarat (`GJ`) and Maharashtra (`MH`) had zero entries in offline/mock catalogs. |
| **RC-03** | Missing Mandi Selection Tier | The UI lacked a separate Mandi dropdown; districts were conflated with Mandi names (`Bikaner Mandi Hub`), preventing users from selecting specific APMC yards within a district. |
| **RC-04** | Stale Dependent Selection Propagation | In `post_commodity_screen.dart`, switching states did not systematically clear both district and mandi selections in a unified atomic transaction. |
| **RC-05** | Form Clutter & Length | Section 3 was rendered inline with 5 bulky inputs, making mobile navigation cumbersome and prone to keyboard overflow. |

---

### 5. Backend Limitations & Approvals Assessment

- **Backend Schema Limitation:**
  The `availabilities` table only has `state_id` and `district_id` as foreign keys, plus `loading_remarks` (text). There is no dedicated `mandi_id`, `warehouse_name`, or `warehouse_address` column in the PostgreSQL table.
- **Contract Preservation Decision (No DB Migration Required):**
  - Store the authoritative `state_id` and `district_id` directly in their respective database columns.
  - Store the full physical loading facility, mandi yard, and warehouse loading site cleanly in `loading_remarks` (e.g., `"Mandi: Bikaner Krishi Upaj Mandi | Warehouse: Shed A-4 | Loading Site: Gate 2, Platform 3"`).
  - Preserve `office_location` as enterprise profile metadata.
  - This avoids any risky database migrations or API contract breaks while fulfilling 100% of the business and UI requirements.

---

### 6. Planned Architecture for `RB-SELLER-LOC-01`

1. **`master_commodity_data.dart`:**
   - Add `MasterMandi` entity (`id`, `districtId`, `stateId`, `name`, `yardType`).
   - Add comprehensive verified districts for Gujarat and Maharashtra.
   - Add authoritative Mandi catalogs mapped to their respective districts.
2. **`commodities_repository.dart`:**
   - Fix `getMasterDistricts` fallback bug: return empty list `[]` when no districts exist for a state, never return unrelated state districts.
   - Add `getMasterMandis(String districtId)` with Supabase query fallback.
3. **`commodity_model.dart`:**
   - Add `warehouseName` and `mandiName` fields to `SellerCommodity` and `CreateCommodityDto`.
4. **`post_commodity_screen.dart`:**
   - Replace inline Section 3 fields with a compact summary card: **"Warehouse / Loading Location"**.
   - Implement `WarehouseLoadingLocationSheet` popup:
     - Supports presets ("Bikaner Mandi Yard", "Kota Mandi Yard", "Jaipur Depot", "Indore Mandi Complex", "Custom Manual Entry").
     - Authoritative dependent dropdowns: State ➔ District ➔ Mandi.
     - Registered Warehouse address input.
     - Actual Physical Loading / Dispatch Facility input (with "Same as Warehouse" toggle).
     - Separate Enterprise Office Location display.
     - Save and Cancel actions with validation and state preservation.
5. **Testing & Verification:**
   - Unit tests covering state/district/mandi filtering and validation.
   - Widget tests validating popup open, save, cancel, summary rendering, and small-screen resilience.
   - Automated TypeScript test runner `verify-rmseller-location-loc01.ts`.

---
*Audit completed and verified by Antigravity AI Coding Agent.*
