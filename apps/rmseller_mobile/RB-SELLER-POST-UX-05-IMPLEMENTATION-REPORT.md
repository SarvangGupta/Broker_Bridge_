# RB-SELLER-POST-UX-05 — Implementation Report

## 1. Files changed
| File | Why |
|---|---|
| `lib/features/commodities/presentation/post_commodity_screen.dart` | Compact accordion layout, section summaries, review sheet, and saved-location prefill. Removed the inline review card and old section headers, now unused. |
| `lib/features/profile/data/seller_profile_repository.dart` | **Additive:** `getSavedBusinessLocation()` and `getSavedOfficeAddress()` return `null` unless the seller actually saved a value, so the demo defaults in `getProfile()` are never used. |
| `test/support/fake_profile_repository.dart` (new) | Fake profile source plus a `listViaReview()` helper |
| `test/widgets/post_commodity_screen_test.dart` | Rewritten as the UX-05 suite (13 tests). It replaces 3 tests that already failed at baseline. |
| `test/widgets/post_commodity_ux04_test.dart`, `…_product_picker_test.dart`, `…_quantity_price_test.dart` | Updated section titles and the two-step listing. The field keys and assertions are unchanged. |

**Not changed:**
- `CommoditiesRepository.createCommodity`, the DTO and API payloads
- Validation rules
- Lab testing and payment logic
- Broker picker and rules
- The location editor
- Auth, schema, RLS and migrations
- Buyer and Broker apps, and other Seller screens

The auth files shown in `git status` are from RB-SELLER-POST-CATEGORY-FIX-01.

## 2. Main screen
- Batch / Lot No. badge (generation lifecycle unchanged).
- Four tappable section cards, each with an icon, title and one or two summary lines built from the **current form state**:

| Section | Collapsed summary |
|---|---|
| 1. Commodity & Pricing | `Product · Grade`, `qty unit · ₹price/unit`; or "Add commodity details" / "Enter quantity and price" |
| 2. Warehouse & Loading | `Warehouse · District, State`, "Loading: same as warehouse" or "separate location"; or "Add warehouse location" / "Saved address loaded · choose district" |
| 3. Lab Testing & Reports | "Testing requested" or "not requested"; "Report attached" or "No report attached" |
| 4. My Trusted Broker | Broker name and location, or "No broker selected · open broker pool" |

- Required sections that are incomplete get an amber border and a **To do** chip.
- **Accordion:** one section is open at a time. Commodity & Pricing opens by default while no product is selected. Edited lots start collapsed.
- Entered values live in screen state and controllers, so collapsing a section never loses them (tested).
- One primary action: **Review & List Commodity**.

## 3. Expanded sections
- **Commodity & Pricing:** the existing commodity search with category, grade, quantity, unit, price and payment-terms widgets (same keys and validators). **Additional Details (Optional)**, collapsed by default, holds the Available From / Valid Until dates.
- **Warehouse & Loading:**
  - Warehouse, loading and office summary rows
  - **Edit Location** (or **Add Location**), which opens the *existing* location editor
  - Physical Loading Readiness dropdown
  - A note when the values came from the saved profile
- **Lab Testing & Reports:** the existing `_buildLabTestingSection()` and `_buildLabReportAttachmentCard()`, unchanged. Opening the section does not start a request or payment. Add Lab Report stays separate from testing.
- **My Trusted Broker:** the existing broker section and picker. Its own card chrome was removed so it isn't a card inside a card. Selection and authorisation logic is unchanged.

## 4. Location reuse
- **New lot:** reads the seller's saved profile location and maps it onto the live state/district master lists by ID, then by name.
  - A saved office address is kept as a **separate** office; it is never replaced by the warehouse.
  - If no location is saved: **no state or district is preselected**, the summary prompts "Add warehouse location", and listing is blocked by the existing state/district check. This replaces the old silent first-state default.
  - If the saved district isn't in the current list: the address and state load, and the seller is asked to choose the district. This was found on the device, see the test report.
- **Edited lot:** decoded from the lot as before (RB-SELLER-LOCATION-UX-01).
- **After Edit → Save:** the summary refreshes and the "from profile" note clears.

## 5. Review and listing
- **Review & List Commodity** first checks the required sections. If one is incomplete, it opens that section, shows its field errors and a SnackBar, and stops.
- Otherwise it opens a **review sheet** grouped into Commodity & Pricing, Locations, Lab Testing & Reports and My Trusted Broker, each with an **Edit** link. Edit closes the sheet and opens that section, with no values reset.
- **List Commodity on Desk** in the sheet calls the **existing `_handleSubmit()`**. Its validation, duplicate guard, repository call and error handling are untouched, so a failed save shows the error, not success (tested). There is no second submission path.

## 6. Accessibility and narrow screens
- Section headers expose button semantics, expanded state, a label that includes the summary, and a tap action. A missing tap action was caught on the device and fixed, see the test report.
- Buttons in the new layout have labels that can shrink. At 320px, `AppButton`'s fixed label row overflowed inside the narrower section cards. The shared `AppButton` itself was not changed.

## 7. Limitations
1. **Saved location is device-local:** the profile location lives in local secure storage, not the backend. A different device or a reinstall has no saved location.
2. **Single broker:** broker selection is single-select in the existing model, so the summary shows one broker, not a count.
3. **Confidential minimum price** has no input field (pre-existing), so it was not added to Additional Details.
