# RB-SELLER-WAREHOUSE-UI-01 — Warehouse Address + GPS / Set on Map

**Date:** 2026-10-28 · **App:** RMSeller · **Branch:** `feature/broker-nilesh` (uncommitted)

**Production statement:** no database schema, RLS, auth or production-data changes.

## Findings before the change

- **"Use Current Location" was fake.** `BusinessLocationService.getCurrentLocation()` never read the device. It always returned Bikaner `28.0229, 73.3119`, snapped to the nearest of 15 hard-coded mandi centroids, and **overwrote State, District, PIN and locality** with those values.
- **No map support:** there was no map package, no location package and no location permission. Only `url_launcher` was present.
- **Placeholder coordinates:** `BusinessLocationModel` and the repository default missing coordinates to that same Bikaner placeholder.

## What changed

**UI (Edit Profile)**
- **Section renamed:** "Shop & Godown" is now **Warehouse** / **गोदाम**.
- **Removed:**
  - **Mandi Presets** (button, sheet, `_applyPreset`)
  - the fake **Use Current Location**
  - the **Location / Shop Name** field and its *required* validator
  - the **Locality** field
- **One Warehouse Address field:** multiline, wraps, editable, and independent of GPS.
- **GPS row:** a GPS Coordinates field plus a **Set on Map** button on one row when the width is at least 340 px, stacked otherwise.

**Map picker** (`widgets/warehouse_map.dart`, OpenStreetMap tiles via `flutter_map`, no API key)
- **Placing the pin:** tap to place or move it. **Use my current location** uses the real device GPS (`geolocator`).
- **Confirming:** **Confirm location** is disabled until a pin exists; Cancel changes nothing.
- **Permission and location errors:** permission denied, permanently blocked, location off, or unavailable each show a message. No coordinates are invented.

**After confirming:** the coordinates, a **map preview**, **Open in Google Maps** (`https://www.google.com/maps/search/?api=1&query=lat,lng`) and **Clear GPS** are shown. The view mode shows the same items.

**Data rules**
- **No GPS-driven overwrites:** PIN, State and District are never changed by GPS; they still come from manual entry or the PIN/postal logic. The address is never derived from coordinates.
- **What counts as a confirmed pin:** coordinates show only when `isGpsDetected` is true (map-confirmed).
- **Legacy placeholder:** the exact old Bikaner value `28.0229, 73.3119` is kept in data but not presented as a confirmed pin.
- **No schema change:** it reuses `addressLine`, `latitude`, `longitude` and `isGpsDetected`.
- **Hidden values preserved:** `name` and `locality` are no longer shown but are preserved and saved unchanged. `primaryMandi` behaviour is unchanged.

**Android:** `ACCESS_FINE_LOCATION` / `ACCESS_COARSE_LOCATION` were added. They are requested only when the seller taps "Use my current location".

**Dependencies:** `flutter_map ^8.3.2`, `latlong2 ^0.10.1`, `geolocator ^14.0.1`.

## Tests (executed)

| Suite | Result |
|---|---|
| `test/widgets/seller_warehouse_location_test.dart` (new) | **12/12** |

What the new suite covers:
- **Section and fields:** EN/HI titles and labels; no presets, name or locality fields; the address wraps.
- **GPS state:** GPS starts unset.
- **Picker flow:** Set on Map opens the picker → tap → confirm, then the preview and link appear.
- **Cancel** changes nothing.
- **Current location:** sets the pin without changing the PIN or address.
- **Location errors:** permission denied, blocked, service off and unavailable each show a message, and Confirm stays disabled.
- **Persistence:** save → reopen persists the multiline address and GPS; the view shows the coordinates and Google Maps link; re-opening the picker starts at the saved pin; the hidden name and PIN are preserved.
- **Legacy placeholder** is hidden.
- **Google Maps URL** is correct.

| Suite | Result |
|---|---|
| Full RMSeller `test/unit` + `test/widgets` | **540 passed, 16 failed.** Identical to the pre-existing HEAD failures, so **0 new regressions**. |
| `flutter analyze` (changed files) | No issues. All 23 remaining `lib/` issues are in untouched modules; HEAD `lib/` had 40. |

Updated tests:
- **`seller_profile_menu_test.dart`:** assertions on the preset, fake GPS and name field now expect their absence. Its "Use Current Location → Bikaner" test asserted the fake result and was replaced by a "no fake GPS" check. Five tests in this file still fail exactly as at HEAD, because of unrelated stale view-mode text ("Business Info").
- **`seller_commodity_expertise_workflow_test.dart`, `seller_profile_pin_location_test.dart`:** name-field references were removed.

## Build and device

- **Debug APK:** built and installed on the Redmi Note 5 Pro (`lastUpdateTime 2026-10-28 12:40:58`). The location permission is present in the installed package.
- **Before screenshot:** taken passively (`scratchpad/warehouse/before_device_screen.png`). It shows Edit Profile at Commodity Expertise, **not** the old Shop & Godown section.
- **After screenshots and on-device map interaction:** **BLOCKED**. ADB input is still disabled (`persist.security.adbinput = 0`), so the screen can't be scrolled to Warehouse or the picker opened. Nothing visual on the device was verified.

## Limitations

- **OpenStreetMap tiles** (`tile.openstreetmap.org`) are free but governed by the OSM tile usage policy. At production scale, use a commercial or self-hosted tile provider; it's a one-line `urlTemplate` change.
- **Map needs internet:** the picker shows a blank map offline, but "Use my current location" still works.
- **Leftover service:** `BusinessLocationService` (centroids and presets) is no longer used by the profile; it was left in place, not deleted.
