# RB-SELLER-LOCATION-UX-01 — Test Report

Flutter: `D:\flutter_sdk\flutter\bin\flutter.bat`, run from `apps/rmseller_mobile`. The full RMSeller suite was **not** run. Only the targeted suites below were run.

## 1. New tests: 13/13 passed
`flutter test test/unit/lot_location_test.dart test/widgets/lot_location_sheet_test.dart` → **All tests passed (13)**

| # | Check (sprint §11) | Test | Result |
|---|---|---|---|
| 1 | No Mandi presets or APMC selection | shows three sections and no Mandi fields | PASS |
| 2, 5 | Saves without Mandi; manual entry works | save is blocked until warehouse address is entered, then returns shared | PASS |
| 3 | GPS works when a provider exists | GPS is disabled with a manual-entry note when no provider | PASS (disabled path) |
| 4 | State/district populate from a reliable geocode | certain GPS result fills address, state and district (fake provider) | PASS |
| 6, 7 | Loading defaults to warehouse; redundant fields hidden | loading and office default to shared, one address form | PASS |
| 8, 9 | Unchecking opens the form inline; office is independent | unchecking loading opens its form without touching office | PASS |
| 10 | Distinct address not silently overwritten | re-checking a distinct address asks before replacing it | PASS |
| 11, 12 | Gate details kept; values round-trip | codec: shared loading keeps gate details and round-trips; separate addresses round-trip | PASS |
| 10 | Legacy data preserved | codec: legacy identical text reads as shared, distinct office kept; unparseable text kept | PASS |
| 13 | Validation | save blocked; changing state clears incompatible district | PASS |
| 14 | Narrow layout | fits a 320px-wide screen without overflow (unchecked state, no exceptions) | PASS |

## 2. Regression: unchanged from baseline
Targeted suites: `post_commodity_screen`, `post_commodity_ux04`, `post_commodity_product_picker`, `post_commodity_quantity_price`, `commodity_details_screen`, `commodities_repository`, plus the new tests.

| | Passed | Failed |
|---|---|---|
| Baseline (HEAD screen, swapped in temporarily, then restored and hash-verified) | 41 | 3 |
| After this sprint | 41 + 13 new = 54 | 3 |

The same 3 tests in `post_commodity_screen_test.dart` fail in both runs. They are pre-existing and expect titles such as "4. Broker Mandate Assignment" that are no longer in the screen. They are not caused by this sprint and were not changed.

An intermediate version with a submit-time "warehouse address required" guard caused 4 extra failures in the product-picker and quantity/price suites. The guard was removed (see implementation report §8).

## 3. Static analysis
- `flutter analyze lib/features/commodities` plus the new tests: **0 errors**. One warning is pre-existing (`_labReportType` unused). The remaining infos are pre-existing deprecations.
- Full `flutter analyze`: errors only in pre-existing, untouched test files (`route_guard_test.dart`, `counterparty_shield_test.dart`, `broker_rating_display_test.dart`).

## 4. Not done
- No APK build and no device or emulator run.
- No before/after screenshots. The rendered UI was **not** visually inspected; layout was checked only through widget tests at 400px and 320px.
- Real GPS was not tested because no provider exists.
- Persistence after reopening was verified only at the codec and draft level. It was not tested against Supabase, because the server does not return `loading_remarks` or store warehouse or office text.

## 5. Git diff scope
`git status` for `apps/rmseller_mobile`:
- `M` post_commodity_screen.dart (+99 / −715)
- New: `lot_location.dart`, `lot_location_sheet.dart`, 2 test files, 3 reports

No changes to `supabase/`, schema, RLS, repositories, other Seller screens, or the Buyer and Broker apps. The Buyer and Broker changes in `git status` were already there before this sprint.

## Status: **PASS WITH LIMITATIONS**
Limitations:
- GPS is disabled because no provider is configured.
- Loading and office state/district, warehouse text and office text cannot be durably stored or read back by the current backend.
- No device or visual verification.
- 3 pre-existing test failures remain.
