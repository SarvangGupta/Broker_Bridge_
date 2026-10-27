# RB-SELLER-LOCATION-UX-01 — Audit Report

**App:** RM Seller (`apps/rmseller_mobile`) · **Date:** 2026-10-27 · **Branch:** `feature/broker-nilesh`

## 1. Where the form lives
- **Route:** Post Commodity / Edit Lot → Section 3 "Warehouse / Loading Location" → "Edit Warehouse / Loading Details".
- **Code before this sprint:** `_openLocationPopup()` in `lib/features/commodities/presentation/post_commodity_screen.dart` (about 670 lines of inline `StatefulBuilder` in a modal sheet).
- `post_commodity_screen.dart` had no uncommitted changes before this sprint.

## 2. What the old form contained
| Element | Notes |
|---|---|
| Supported Mandi Location Presets | 4 `ChoiceChip`s from `MasterCommodityData.verifiedLocationPresets` |
| Warehouse State / District | Cascading dropdowns |
| Mandi Yard / APMC Market Hub * | Required dropdown from `getMasterMandis()`, plus "+ Other / Custom Mandi" text field. **Blocked save if left empty.** |
| Warehouse address * | One free-text field |
| Loading facility * | Free text with a "Same as registered warehouse address" checkbox that **copied** the text. The field stayed visible. |
| Enterprise Office HQ * | Free text only. No state, district or PIN. |
| Hard-coded defaults | `Krishi Upaj Mandi Yard Warehouse A-4`, `Bikaner Commercial Head Office` were pre-filled on every new lot |

## 3. Data model and persistence (source of truth)
| UI concept | DTO field | Reaches server? |
|---|---|---|
| Warehouse state / district | `stateId` / `districtId` → `availabilities.state_id` / `district_id` | **Yes** |
| Loading facility | `loadingRemarks` → `availabilities.loading_remarks` (text) | **Yes, on insert.** `getCommodities()` does not select it back, so a server reload loses it. |
| Warehouse address | `warehouseName` | **No.** Kept only in the session cache. |
| Office HQ | `officeLocation` | **No.** Kept only in the session cache. |
| Mandi | `mandiName` | **No.** Kept only in the session cache. |

The backend has no column for loading or office state/district/PIN, and no shared-or-separate flag. No endpoint exists for these values. This sprint does not change the schema.

## 4. GPS and reverse geocoding
- `pubspec.yaml` has **no** location plugin (no `geolocator`, `location`, `geocoding` or `permission_handler`).
- `BusinessLocationService.getCurrentLocation()` (profile feature) returns **fixed Bikaner coordinates** unless coordinates are passed in. It is not device GPS.
- `BusinessLocationService.reverseGeocode()` is an offline nearest-centroid lookup over 15 districts. It is not a configured geocoding provider.
- **Conclusion:** no real GPS or reverse-geocoding provider is configured.

## 5. State / district master data
`CommoditiesRepository.getMasterStates()` and `getMasterDistricts(stateId)` read Supabase `master_states` / `master_districts`, with a per-state fallback in `MasterCommodityData`. The new form reuses these. It adds no new list.

## 6. Prior sprint reports reviewed
`RB-SELLER-LOC-01-*` (introduced the popup, mandi catalogue and presets), `RB-SELLER-POST-UX-0x`, `RB-SELLER-PROFILE-0x`.

## 7. Test baseline (before changes)
Targeted suite (post_commodity ×4, commodity_details, commodities_repository) on the HEAD version of the screen: **41 passed, 3 failed**. The 3 failures are all in `post_commodity_screen_test.dart` and are pre-existing (stale section titles such as "4. Broker Mandate Assignment").
