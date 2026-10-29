# RB-SELLER-ADDRESS-PIN-FIX-01 — Supplier Address & PIN → State/District

**Date:** 2026-10-28 · **App:** RMSeller · **Branch:** `feature/broker-nilesh` (uncommitted) · **Status:** code complete. Device screenshots are BLOCKED. One production data change is proposed and awaits approval.

## Root causes

| # | Symptom | Cause | Where |
|---|---|---|---|
| 1 | HQ address shows GSTIN / unrelated fragments | The supplier/buyer split assumed reading order, but real ML Kit output puts the buyer block first. Address cleanup did not remove GSTINs. A labelled address also kept reading into the signature line (`For <firm>`). | `invoice_ocr_service.dart`: `_extractAddressDetails`, `_cleanAddressLine`, buyer detection (first two items fixed in the previous sprints; the signature stop is fixed here) |
| 2 | State/District do not match the PIN | `IndiaPinCodeDirectory` was a hand-written **3-digit prefix table** (about 120 prefixes). PINs outside it fell back to a state-level guess. | `india_pincode_directory.dart` |
| 3 | State/District show the wrong values even when the PIN is right | The profile form used a hard-coded fallback list of **4 states / 15 "districts"** (e.g. "Bikaner Mandi Hub") instead of the live master. Every unmatched value fell back to `.first`, which is Rajasthan / Bikaner. `DropdownButtonFormField.initialValue` is read only once, so a later programmatic selection never appeared on screen. | `seller_profile_screen.dart`: `_populateControllers`, `_onStateChanged`, `_applyExtractedSuggestions`, the dropdowns |
| 4 | Address not readable | The Street / Mandi / Area field was single-line. | `seller_profile_screen.dart` |
| 5 | Amounts read as PINs | `योग 336600` and item-row totals matched the "trailing 6 digits" rule. | `_extractPinCode` |

## Changes

- **`lib/features/profile/data/india_pincode_data.dart` (new, generated, 228 KB)**
  - **Source:** India Post *All India Pincode Directory* (data.gov.in, GODL-India licence; attribution is in the file header). It was retrieved 2026-10-28 from the CSV republished at `github.com/dropdevrahul/pincodes-india`.
  - **Contents:** 157,126 post offices → 19,300 PINs, 36 states/UTs.
  - **Spot checks:** 302019→Jaipur, 334001→Bikaner, 452001→Indore, 226001→Lucknow, and *Bharwari SO 212201*→Kaushambi.
- **`india_pincode_directory.dart` (rewritten on the generated data)**
  - **Lookup:** an exact PIN lookup replaces the prefix guess. An unknown PIN returns `null`.
  - **Multiple districts:** a PIN that covers more than one district (1,168 PINs) returns all candidates and sets `isAmbiguous`.
  - **New helpers:** `isKnownPin`, `stateNameHindi` (36 states/UTs) and `sameState`.
  - **Conflict detection:** now covers 21 states, with short codes such as "UP" matched as whole words.
- **`invoice_ocr_service.dart`**
  - **PIN acceptance:** an unlabelled 6-digit number counts as a PIN only if India Post knows it.
  - **Flagging:** an unknown labelled PIN is kept and flagged. An ambiguous PIN uses a district named in the address, otherwise it is flagged. A state conflict is flagged, and the address is never changed.
  - **Address stop list:** address collection stops at `For` / `वास्ते` / `Authorised` / table headers.
- **`seller_profile_screen.dart`**
  - **States list:** loads the live `master_states`, removing duplicate names. Districts come from every row that shares the state name, because the live data has duplicate Rajasthan / Madhya Pradesh rows.
  - **Saved State/District:** matched exactly. An unmatched value is left empty, with no `.first` fallback.
  - **After a scan:** the PIN-derived State/District is applied against the live master. If the district is missing from the master, or can't be established, a review notice is shown (`district_review_notice`, in English or Hindi).
  - **District required:** only when the master lists districts for the selected state.
  - **Display:** state names appear in Hindi when the UI is in Hindi. The dropdowns are re-keyed so programmatic selections are displayed.
  - **Address fields:** both are multiline and wrap.

## Tests

`flutter test` on 18 OCR/profile files: **149 passed, 5 failed**.

The 5 failures are the pre-existing `seller_profile_menu_test.dart` failures, which fail identically on unmodified HEAD (verified earlier in this session by stashing the changes). `flutter analyze` reports no issues. The debug APK builds and installs.

New tests:
- **`test/unit/address_pin_mapping_test.dart` (12)**
  - PIN→district/state, ambiguous PIN, unknown/invalid PIN, Hindi state names.
  - English multi-line address with PIN.
  - Hindi address with the buyer block first and GSTIN/phone next to the address (buyer PIN 302013 is not taken).
  - Unknown PIN flagged, conflict flagged with the address intact, ambiguous PIN resolved by the address or flagged.
  - Totals not taken as a PIN.
  - Save → reopen round trip with Hindi text intact.
- **`test/widgets/seller_profile_pin_location_test.dart` (3)**, with a fake master shaped like the live data:
  - PIN 302019 selects Rajasthan / Jaipur.
  - A UP PIN selects Uttar Pradesh and shows the district review notice.
  - A long Hindi address wraps in both address fields.
- **Updated:** `seller_profile_menu_test` "Changing State…" now expects no auto-selected district, because a guessed district is what this sprint removes.

## Siyaram reference invoice

The supplier address is `मलिकपुर महेवा, भरवारी, कौशाम्बी`, verified against the verbatim on-device ML Kit output in `siyaram_real_ocr_supplier_test.dart`. No supplier PIN is printed, so **PIN, State and District stay empty**; nothing is guessed. The buyer's details are not used.

## Screenshots / device verification — BLOCKED

- **Input blocked:** ADB input injection is still blocked on the Redmi Note 5 Pro (MIUI *USB debugging (Security settings)* is off).
- **Phone in use:** the phone was also in active use during this sprint, so no UI was driven.
- **Not captured:** no review-form or saved-profile screenshots were taken, and no save/reopen was done on the device. Save/reopen is covered only by the unit round-trip test.

## Proposed production data change (NOT applied — needs approval)

The live `master_districts` has **54 rows: 53 Rajasthan, 1 Madhya Pradesh, none for any other state**. A supplier in Uttar Pradesh (or any non-Rajasthan state) therefore cannot get a District, even with a valid PIN; the app flags it for review. `master_states` also has duplicate Rajasthan and Madhya Pradesh rows.

Proposal:
1. **Seed districts:** insert the districts from the India Post dataset (about 750) into `master_districts`. Use deterministic UUIDv5 IDs under a fixed namespace and `state_id` matched by state name to the canonical `master_states` row. Do not touch existing rows.
2. **Leave duplicates alone:** keep the duplicate state rows as they are; the app already merges them. De-duplicating them would need an FK audit of `companies`, `availabilities` and `requirements` first.
3. **Rollback:** `DELETE FROM master_districts WHERE id IN (<generated id list>)`. The IDs are deterministic, so the list can be regenerated.

## Remaining limitations

- **Hindi districts:** district names are English only. Hindi state names are supplied, but there is no reliable Devanagari district reference.
- **Dataset freshness:** the PIN data is a snapshot (2026-10-28) of a third-party republication of the government file. Refresh it by regenerating `india_pincode_data.dart`.
- **Cross-state PINs:** a PIN that spans states reports its first state, and its districts flag review.
- **Not changed:** GPS detection and the trading-hub presets still use the fallback catalogue (out of scope).
- **Old data:** profiles saved before these fixes keep their stored values (e.g. a business name of `GSTIN : …`) until the seller re-scans or edits and saves.
