# RB-SELLER-LOC-01 — Implementation Report
## Location Forms, Warehouse/Loading Address & Mandi/District Corrections

**Project:** RMBroker  
**Application:** RM Seller App (`apps/rmseller_mobile`)  
**Sprint ID:** `RB-SELLER-LOC-01`  
**Date:** October 21, 2026  
**Status:** **IMPLEMENTATION COMPLETE & VERIFIED**

---

### 1. Executive Summary

Sprint `RB-SELLER-LOC-01` addressed usability and data-correctness defects in the RM Seller App's Commodity Posting workflow. The primary achievements include:

1. **Dedicated Warehouse / Loading Location Modal Popup:**
   Replaced the lengthy inline location section in Section 3 of `PostCommodityScreen` with a clean, high-density summary card and an interactive modal sheet (`showModalBottomSheet` via `DraggableScrollableSheet`). This prevents mobile form clutter, ensures accessibility when the on-screen keyboard is visible, and completely eliminates RenderFlex overflow risks.

2. **Tri-Level Location Distinction:**
   - **Registered Warehouse Storage Facility:** Dedicated address entry for the physical warehouse/godown.
   - **Actual Physical Loading / Dispatch Facility:** Explicit field for transport trucks, weighbridge gates, and loading platforms (with a convenient "Same as registered warehouse address" toggle).
   - **Enterprise Office Location (HQ):** Preserved strictly as independent corporate headquarters, bound to the seller enterprise profile and never overwritten by commodity lot dispatch edits.

3. **Authoritative Cascading Dropdowns (State ➔ District ➔ Mandi Hub):**
   - Corrected the district fallback bug in `CommoditiesRepository` that previously caused cross-state contamination.
   - Expanded authoritative catalogs for Gujarat (`GJ`) and Maharashtra (`MH`) in addition to Rajasthan (`RJ`) and Madhya Pradesh (`MP`).
   - Added a dedicated 23-mandi catalog across major APMC trading yards with custom mandi entry fallback (`isCustomMandi`).
   - Guaranteed cascading reset: selecting a new state instantly clears dependent district and mandi selections to prevent stale data.

4. **Zero Database Schema Mutations:**
   All changes strictly respect existing PostgreSQL table contracts (`public.availabilities`, `public.master_states`, `public.master_districts`). Mandi and loading facility details are persisted through `loading_remarks`, and warehouse addresses map to `warehouseName` in the domain DTO and session state.

---

### 2. Exact Files Changed

| File Path | Description of Modifications |
| :--- | :--- |
| [`apps/rmseller_mobile/lib/features/commodities/domain/master_commodity_data.dart`](file:///c:/Users/dell/.gemini/antigravity-ide/scratch/Broker_Bridge_/apps/rmseller_mobile/lib/features/commodities/domain/master_commodity_data.dart) | Added `MasterMandi` class; expanded `verifiedDistricts` with Gujarat and Maharashtra districts; added 23 authoritative mandis across 10 trade districts; added `verifiedLocationPresets` (Bikaner, Kota, Jaipur, Indore). |
| [`apps/rmseller_mobile/lib/features/commodities/domain/commodity_model.dart`](file:///c:/Users/dell/.gemini/antigravity-ide/scratch/Broker_Bridge_/apps/rmseller_mobile/lib/features/commodities/domain/commodity_model.dart) | Extended `SellerCommodity` and `CreateCommodityDto` with `warehouseName` and `mandiName`; updated `copyWith`, `fromMap`, and `toMap` for lossless serialization. |
| [`apps/rmseller_mobile/lib/features/commodities/data/commodities_repository.dart`](file:///c:/Users/dell/.gemini/antigravity-ide/scratch/Broker_Bridge_/apps/rmseller_mobile/lib/features/commodities/data/commodities_repository.dart) | Fixed district fallback defect in `getMasterDistricts` (`return fallbacks;`); added `getMasterMandis(districtId)` with Supabase query and fallback; updated `createCommodity` to store `warehouseName` and `mandiName`. |
| [`apps/rmseller_mobile/lib/features/commodities/presentation/post_commodity_screen.dart`](file:///c:/Users/dell/.gemini/antigravity-ide/scratch/Broker_Bridge_/apps/rmseller_mobile/lib/features/commodities/presentation/post_commodity_screen.dart) | Added `initialLot` parameter; added `_openLocationPopup()` modal bottom sheet; replaced inline Section 3 with compact summary card and edit action; passed `warehouseName` and `mandiName` to `CreateCommodityDto`; added Warehouse & Mandi row to Section 5 review summary. |
| [`apps/rmseller_mobile/lib/features/commodities/presentation/commodity_details_screen.dart`](file:///c:/Users/dell/.gemini/antigravity-ide/scratch/Broker_Bridge_/apps/rmseller_mobile/lib/features/commodities/presentation/commodity_details_screen.dart) | Updated Dispatch & Warehouse Location card to display `warehouseName` and `mandiName` alongside loading facility and registered office HQ. |
| [`src/server/tests/verify-rmseller-location-loc01.ts`](file:///c:/Users/dell/.gemini/antigravity-ide/scratch/Broker_Bridge_/src/server/tests/verify-rmseller-location-loc01.ts) | Created comprehensive automated verification test suite covering all 16 sprint test cases (LOC-T01 through LOC-T16). |

---

### 3. Popup / Form Behaviour Implemented

#### A. Entry Point & Summary Card
- **Entry Label:** "Warehouse / Loading Location" with status badge ("Configured" or "Required *").
- **Summary Preview:** Shows configured Mandi Hub, District, State, Registered Warehouse Address, Physical Loading Platform, and Enterprise Office HQ.
- **Trigger Button:** "Edit Warehouse / Loading Details" opens the modal bottom sheet. Tapping the summary card directly also opens the modal.

#### B. Modal Sheet Architecture (`_openLocationPopup`)
- Implemented using `showModalBottomSheet` with `isScrollControlled: true` and wrapped in `DraggableScrollableSheet` (`initialChildSize: 0.85`, `maxChildSize: 0.95`, `minChildSize: 0.5`).
- **Keyboard Resilience:** Uses `MediaQuery.of(context).viewInsets.bottom` padding and `SingleChildScrollView(controller: scrollController)`. When the virtual keyboard appears, inputs automatically scroll smoothly without clipping.
- **Location Presets:** Renders quick-select `ChoiceChip` widgets for prominent trading hubs:
  - Bikaner Krishi Upaj Mandi Yard
  - Kota Bhamashah Mandi Complex
  - Jaipur Surajpole Mandi Depot
  - Indore Choithram Mandi Hub
  Tapping any preset populates state, district, mandi, warehouse address, and physical loading platform in a single tap.
- **Independent Form State:** Uses temporary local variables (`tempState`, `tempDistrict`, `tempMandi`, `tempWarehouseController`, `tempDispatchController`, `tempOfficeController`).
- **Cancel Safety:** Pressing Cancel simply closes the modal (`Navigator.pop(context)`). The parent form state remains completely untouched, preventing accidental data loss.
- **Save Validation:** Pressing "Save Location" validates all mandatory fields using `popupFormKey.currentState!.validate()`. If valid, it commits the changes to parent state and displays a confirmation SnackBar.

---

### 4. Handling of Warehouse, Loading, and Office Locations

| Business Concept | UI Representation | Storage / Persistence Mapping | Separation Guarantee |
| :--- | :--- | :--- | :--- |
| **Registered Warehouse** | `Registered Warehouse / Storage Facility Address *` | Mapped to `warehouseName` in `CreateCommodityDto` & `SellerCommodity` | User can specify warehouse storage address (e.g. CWC godown). Does not mutate office address. |
| **Physical Loading / Dispatch Facility** | `Actual Physical Loading / Dispatch Facility *` | Mapped to `loadingRemarks` in `availabilities` table | "Same as registered warehouse address" checkbox copies address when enabled, but unchecking permits distinct gate/shed details. |
| **Enterprise Office Location** | `Enterprise Office Location (Registered HQ)` | Belongs to Seller Profile / Company record; mapped to `officeLocation` in lot DTO | Displayed in grayed container to clearly indicate it represents corporate HQ. Changing loading details never overwrites office HQ. |

---

### 5. Dropdown and Validation Fixes

1. **State ➔ District Cascading Fix:**
   - In `commodities_repository.dart`:
     ```dart
     // Before (Defect):
     return fallbacks.isNotEmpty ? fallbacks : MasterCommodityData.verifiedDistricts;
     // After (Corrected):
     return fallbacks;
     ```
     This prevents districts from Rajasthan/MP from bleeding into Gujarat/Maharashtra.
2. **State Selection Clearing:**
   - When a new state is selected:
     ```dart
     tempState = newState;
     tempDistrict = null;
     tempMandi = null;
     tempDistricts = [];
     tempMandis = [];
     ```
     Guarantees that stale district or mandi selections are wiped atomically.
3. **Mandi Selection & Custom Mandi Toggle:**
   - Users can choose from verified APMC Mandis or tap "Enter Custom Mandi" to specify private trade yards or unlisted sub-mandis.
4. **Mandatory Field Guards:**
   - State, District, Mandi, Warehouse Address, Loading Facility, and Enterprise Office all have strict non-empty validators. Incomplete submissions display immediate inline validation errors.

---

### 6. Issues Deliberately Left Unresolved & Out-of-Scope Items

1. **Database Schema Foreign Keys for Mandis:**
   - In accordance with the sprint objective and Zero-Mutation Policy, no `master_mandis` table or `mandi_id` foreign key was added to PostgreSQL (`supabase/migrations` left 100% clean).
2. **Sibling Mobile Apps:**
   - No modifications made to `apps/rmbuyer_mobile` or `apps/rmbroker_mobile`.
3. **Out of Scope Features:**
   - Commodity master options, quality grades, lab report cameras, and broker mandate flows were preserved untouched as verified by regression suite `verify-rmseller-posting-rb02.ts`.
