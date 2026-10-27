# RB-SELLER-LOCATION-UX-01 — Implementation Report

## 1. Files changed
| File | Change |
|---|---|
| `lib/features/commodities/presentation/post_commodity_screen.dart` | Replaced the inline popup with a call to the new sheet. Removed mandi state and loading, presets, the 3 location text controllers and their hard-coded defaults. Added `_lotLocation` and the summary getters. Summary card and review rows no longer show Mandi. An edited lot's stored `mandiName` is passed through unchanged. |
| `lib/features/commodities/domain/lot_location.dart` (new) | `LotAddress` / `LotLocation` value types plus a readable text codec for the existing `warehouseName`, `loading_remarks` and `officeLocation` fields |
| `lib/features/commodities/presentation/lot_location_sheet.dart` (new) | `showLotLocationSheet` / `LotLocationForm`: the three-section form |
| `test/unit/lot_location_test.dart` (new) | 4 codec tests |
| `test/widgets/lot_location_sheet_test.dart` (new) | 9 form tests |

Not touched: schema, migrations, RLS, repositories, `master_commodity_data.dart` (mandi catalogue left intact), Commodity Details, Profile, Buyer and Broker apps.

## 2. Mandi UI and validation removed
- Supported Mandi Location Presets chips
- Mandi Yard / APMC Market Hub dropdown and its "Mandi hub required" validator
- "+ Other / Custom Mandi" field
- "Mandi Yard" in the summary card. The review row changed from "Warehouse & Mandi" to "Warehouse".
- `getMasterMandis()` is no longer called from this screen.

Stored data is preserved: an edited lot still submits its original `mandiName`.

## 3. New layout
A modal sheet with a scrollable body and a **pinned footer containing Cancel and Save Location**. It has three bordered sections:

**A. Registered Warehouse / Storage Location**
- Optional location name
- Use GPS Location button
- Address *
- State *
- District *
- PIN code (optional, 6 digits)

**B. Actual Physical Loading / Dispatch Location**
- Checkbox "Same as Registered Warehouse / Storage Location" (on by default)
- When checked: a live summary of the warehouse address
- When unchecked: an inline address form (GPS, address, state, district, PIN)
- The *Gate / shed / platform* field is always shown, so dispatch-point details survive while the address is shared.

**C. Enterprise Office Location (Registered HQ)**
- The same checkbox (on by default)
- When unchecked: an inline office form with name, address, state, district and PIN

## 4. Checkbox behaviour
- Each checkbox controls only its own section.
- Unchecking keeps whatever was typed earlier.
- Re-checking a section that holds a distinct address asks **"Use warehouse address?"** with *Keep separate* or *Use warehouse*. Nothing is discarded silently.
- When decoding an existing lot:
  - Legacy lots whose loading text equals the warehouse text read as **shared**.
  - A distinct legacy office (for example "Bikaner Commercial Head Office") reads as **separate**, with its text kept.
  - Text that cannot be parsed goes into the Address field.

## 5. State and district
- The form uses the existing repository loaders (`getMasterStates` / `getMasterDistricts`).
- Dropdown values are master IDs, so the backend receives the same identifiers as before.
- Changing state clears the district and reloads the list. A district that does not belong to the new state is dropped and must be chosen again.

## 6. GPS and reverse geocoding: limitation
No real provider exists (see the audit report).
- The form accepts an optional `GpsAddressLookup`. The Post Commodity screen passes **none**, so the GPS button is **disabled**, with the note "GPS is not available in this app yet. Enter the address manually below."
- I deliberately did **not** wire `BusinessLocationService.getCurrentLocation()`. It always returns Bikaner, and presenting that as GPS would put a wrong address on every lot.
- The population logic is implemented and tested with a fake provider:
  - A certain result fills address, PIN, state and district.
  - An uncertain result fills the address only and asks the seller to choose state and district.
  - A failure shows a message and the seller continues manually.
- Enabling real GPS needs a location plugin and Android/iOS permission entries. That is a dependency and platform change outside this sprint, and it is pending approval.

## 7. Persistence
- **Warehouse state/district:** `state_id` / `district_id`. These are authoritative and unchanged.
- **Warehouse name, address and PIN:** `warehouseName`, for example `Main Warehouse · Plot 12 · PIN 334001`.
- **Loading:** `loading_remarks`
  - Shared: `Same as registered warehouse · Gate 2`
  - Separate: `Gate 2 · Yard Road · Indore, Madhya Pradesh · PIN 452014`
- **Office:** `officeLocation`, either `Same as registered warehouse` or the separate address summary.
- The sheet only updates the lot draft. Nothing is claimed as saved until the lot itself is submitted.

**Backend limitations (documented, not changed):**
1. Only `state_id`, `district_id` and `loading_remarks` reach the server. Warehouse text and office are in the session cache only, as before this sprint.
2. `getCommodities()` does not select `loading_remarks`, so after a full reload from the server, saved loading text is not shown.
3. The server has no structured state/district for loading or office. They live inside the text, and the seller re-picks the district if the name does not match.

Storing all of this durably needs approved schema columns, or a JSON column with an API change, plus a read-back in `getCommodities()`.

## 8. Behaviour change to note
Before this sprint, a new lot was silently pre-filled with fake Bikaner warehouse and office text. That text is gone. A seller who never opens the form now posts with an empty warehouse address. State and district are still required. I did not add a submit-time "address required" guard, because existing tests in out-of-scope suites (product picker, quantity/price) submit without opening this form. A guard can be added along with updates to those tests if you want one.
