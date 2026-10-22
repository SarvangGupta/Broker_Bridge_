# RB-SELLER-PROFILE-02 — Pre-Change Audit Report
**Sprint:** Business Location Selection & Profile UI Simplification  
**Application:** RM Seller Mobile (`apps/rmseller_mobile`)  
**Sprint Type:** Implementation Sprint (Audit → Implement → Test → Report → Stop)  
**Status:** PASS  
**Date:** 2026-10-22  

---

## 1. Executive Summary

This pre-change audit evaluates the existing implementation of the Seller Profile in `apps/rmseller_mobile` to guide sprint **RB-SELLER-PROFILE-02**.

The two primary objectives of this sprint are:
1. **Profile UI Simplification:** Removing technical, cryptographic, and Supabase-generated authentication details (UUIDs, internal provider text, RLS self-promotion disclaimers) that create clutter for non-technical agricultural traders, while retaining clean, business-focused seller information (Seller Name, Business Name, Mobile, Business Email, GSTIN, Verification Status).
2. **Business Location Selection & Reverse-Geocoding:** Introducing a dedicated **Business Location** section for the seller's shop, warehouse, or godown facility, supporting:
   - Automatic detection via device coordinates and offline/online reverse geocoding to State and District.
   - Manual state and district selection using existing authoritative catalogs (`MasterCommodityData.verifiedStates` and `MasterCommodityData.verifiedDistricts`).
   - Clean cascading state-to-district filtering with automatic stale selection clearing.
   - Distinct preservation of Corporate Office HQ versus Shop/Godown facility address.

---

## 2. Pre-Implementation Audit Checkpoints

### 2.1 Existing Profile Route & Files
- **Screen:** `apps/rmseller_mobile/lib/features/profile/presentation/seller_profile_screen.dart`
- **Domain Model:** `apps/rmseller_mobile/lib/features/profile/domain/seller_profile_model.dart`
- **Data Repository:** `apps/rmseller_mobile/lib/features/profile/data/seller_profile_repository.dart`
- **Routes in `app_router.dart`:**
  - `/profile` -> `SellerProfileScreen()`
  - `/profile/edit` -> `SellerProfileScreen(isInitialEdit: true)`
  - `/settings` -> `SellerSettingsScreen()`
  - `/help` -> `SellerHelpSupportScreen()`

### 2.2 Technical Information Currently Exposed in the UI
In `seller_profile_screen.dart`, the following developer/technical details are currently displayed to non-technical business users:
1. **Account ID (UUID):** Displays raw UUID `49534f2f-ec4e-445f-84e8-7d09c7056b6a` with note *"Cryptographic account key immutable under platform security rules."*
2. **Registered Login Email:** Annotated with *"Primary authentication credential managed by Supabase Auth."*
3. **Enterprise Role:** Displays `SELLER` with note *"Assigned platform role (self-promotion strictly prohibited by RLS)."*
4. **Verification Status Notes:** Technical disclaimers regarding database-level audits.
5. **View Mode Info Rows:** Shows `Enterprise Role: SELLER` under Business & Tax Registration.

**Audit Recommendation:**
Remove the entire "Protected Account Identifiers (Read-Only)" technical card from the visible UI in Edit Mode, and remove internal role lines from the View Mode. Keep all underlying IDs (`id`, `companyId`, `role`) intact in `SellerProfileModel` for secure Supabase RLS synchronization.

### 2.3 Authoritative State & District Sources
- Master data already resides in `apps/rmseller_mobile/lib/features/commodities/domain/master_commodity_data.dart`:
  - `MasterCommodityData.verifiedStates`: Rajasthan (`RJ`), Madhya Pradesh (`MP`), Gujarat (`GJ`), Maharashtra (`MH`).
  - `MasterCommodityData.verifiedDistricts`: 15 verified trade districts partitioned by `stateId`.
  - `MasterCommodityData.verifiedLocationPresets`: Verified mandi warehouse presets for Bikaner, Kota, Jaipur, and Indore.
- In `CommoditiesRepository`, `getMasterStates()` and `getMasterDistricts(stateId)` already provide Supabase queries with verified fallback catalogs.

### 2.4 Geolocation & Reverse-Geocoding Status
- Inspection of `pubspec.yaml` confirms that neither `geolocator` nor `geocoding` nor `google_maps_flutter` is currently installed.
- There is no external paid mapping dependency configured in the repository.
- **Audit Decision:**
  1. Build a robust `BusinessLocationService` that handles:
     - Geolocation coordinate acquisition with permission handling (GPS / Network).
     - Reverse-geocoding engine mapping latitude/longitude coordinates to the nearest matching state and district in `MasterCommodityData`.
     - Optional HTTP reverse-geocoding via OpenStreetMap Nominatim with offline fallback to regional trade coordinate bounds.
  2. Implement an intuitive 3-way location flow:
     - **Use Current Location:** Requests permission, captures coordinates, reverse-geocodes state/district, and populates form.
     - **Trading Hub Presets:** Instant 1-tap configuration for prominent regional mandi godowns.
     - **Enter Address Manually:** Direct manual entry with cascading State & District dropdowns (no GPS needed).
  3. Never claim location detection succeeded if coordinates or geocoding failed.

### 2.5 Data Persistence & Separation of Addresses
- In `src/server/db/schema.ts`, table `public.companies` stores `state_id`, `district_id`, `name`, `gst`.
- `SecureStorageService` safely persists:
  - `business_location_name` (Shop/Godown label)
  - `business_location_address` (Physical godown address)
  - `business_location_locality` (Mandi/Industrial locality)
  - `business_location_state_id` / `business_location_state`
  - `business_location_district_id` / `business_location_district`
  - `business_location_pincode`
  - `business_location_lat` / `business_location_lng`
  - `registered_office_address` (Corporate HQ — maintained completely separate from warehouse/godown address).
- No database schema migrations or RLS mutations are required or authorized.

---

## 3. Pre-Change Invariants & Non-Destructive Plan

1. **Zero Database Migrations:** All business location fields persist cleanly through existing `companies` table columns (`state_id`, `district_id`) and encrypted local preferences (`SecureStorageService`).
2. **UI Simplification:** Technical UUIDs, Supabase references, and cryptographic disclaimers are removed from the visible UI while remaining in code and network payloads.
3. **Office vs Godown Distinction:** Corporate HQ address and Shop/Godown facility address remain strictly separate.
4. **Cascading Dropdowns:** Changing State immediately resets District to prevent cross-state contamination.
5. **No Fake Maps:** Clean, responsive form with coordinates preview and manual/preset fallbacks.
