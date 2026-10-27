# RB-SELLER-POST-UX-05 — Audit Report

**App:** RM Seller (`apps/rmseller_mobile`) · **Date:** 2026-10-27

## 1. Screen and files
- **Entry points:** Home "Post Commodity" button and Commodities → `PostCommodityScreen` (`lib/features/commodities/presentation/post_commodity_screen.dart`, about 3,200 lines before this sprint).
- **Supporting files:**
  - `commodity_picker_sheet.dart` (product search and category label)
  - `lot_location_sheet.dart` and `domain/lot_location.dart` (from RB-SELLER-LOCATION-UX-01)
  - `lab_testing_repository.dart`
  - `seller_broker_repository.dart`
  - `commodities_repository.dart` (`createCommodity`)

## 2. Layout before this sprint (one long scroll)
1. Section 1: Commodity & Specification, plus a lot badge
2. Section 2: Quantity & Commercial Pricing
3. Section 3: Warehouse location card, loading readiness, availability dates, **plus** the whole certified lab testing workflow and Add Lab Report
4. Section 4: My Trusted Broker
5. Section 5: an always-visible review card
6. "List Commodity on Desk"

Everything was visible at once, and lab testing sat inside the location section.

## 3. Behaviour verified in source (not taken from reports)
- **Validation:** `_handleSubmit()` runs the form validators *and* re-checks every mandatory value in code: commodity, grade belongs to the product, unit, state, district, quantity > 0 and price > 0. It also has an in-flight duplicate guard, and on failure it shows `_errorMessage` (never a false success).
- **Category:** comes from `MasterCommodity.categoryName`, resolved from `master_categories` (RB-SELLER-POST-CATEGORY-FIX-01).
- **Grades:** load per product, and the grade selection is cleared when the product changes.
- **Broker:** single selection (`_selectedBroker`) chosen through `_openBrokerPicker`. There is no multi-select model.
- **Lab testing:** an opt-in toggle, a UPI payment card and verification (`LabTestingRepository`). It is separate from `_labAttachment` (Add Lab Report).
- **Location:** the editor from RB-SELLER-LOCATION-UX-01.
  - **Finding A:** a new lot auto-selected **the first state and district** in the master list. On the device this showed "District, West Bengal", a fabricated location.
  - **Finding B:** the profile's `getProfile()` fills **demo Bikaner defaults** when nothing has been saved, so it can't be used as the "saved location" source as-is.
  - **Finding C:** the profile location is stored in device-local secure-storage preferences (`business_location_*`, `office_address`). It is not in the database.

## 4. Test baseline
Post Commodity suites before this sprint: **3 failing** (`post_commodity_screen_test.dart`, stale titles), all others passing (see RB-SELLER-LOCATION-UX-01 / CATEGORY-FIX-01 reports).
