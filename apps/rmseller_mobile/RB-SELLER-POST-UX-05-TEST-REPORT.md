# RB-SELLER-POST-UX-05 — Test Report

Flutter: `D:\flutter_sdk\flutter\bin\flutter.bat`, run in `apps/rmseller_mobile`. Targeted suites only; the full RMSeller suite was not run.

## 1. Automated tests: 79/79 passed
Command: `flutter test` on these files:
- `post_commodity_screen_test`
- `post_commodity_ux04_test`
- `post_commodity_product_picker_test`
- `post_commodity_quantity_price_test`
- `lot_location_sheet_test`
- `lot_location_test`
- `commodity_details_screen_test`
- `commodities_repository_test`
- `seller_profile_menu_test`

Result: **All tests passed (79)**. The baseline had 3 failures in `post_commodity_screen_test`; that file is now the UX-05 suite.

| # (§13) | Covered by | Result |
|---|---|---|
| 1 | four compact sections, one primary action; old inline review removed | PASS |
| 2, 15 | one section open at a time; collapsing keeps the typed quantity | PASS |
| 3 | collapsed summaries reflect current values (product, `25 MT · ₹2450/MT`, lab state) | PASS |
| 4 | product picker suite: category label, grades per product, grade cleared on change | PASS |
| 5 | quantity/price suite (6 invalid inputs block listing); empty submit shows "Required" | PASS |
| 6 | saved profile location fills the summary; nothing preselected without one; unknown district asks once | PASS |
| 7 | Edit/Add Location opens the editor (`edit_location_button`); editor suite (13 tests) | PASS |
| 8 | saved distinct office stays separate; location codec tests | PASS |
| 9, 10 | lab section code unchanged; summaries show testing and report separately | PASS (code-level) |
| 11 | broker picker code unchanged; summary shows the selection or the open pool | PASS (code-level) |
| 12 | review shows current values; Edit returns to the section without submitting | PASS |
| 13 | confirming the review submits once through the repository with the right IDs and warehouse | PASS |
| 14 | the fake repository rejects the save, and no "listed successfully" appears | PASS |
| 16 | each section opens at 320px wide without overflow | PASS |
| a11y | section header has button, expanded-state and tap semantics | PASS |

## 2. Static analysis
`flutter analyze lib test/widgets test/support`: **0 errors**. The one warning (`_labReportType` unused) is pre-existing. `AppCard` and `_buildSectionHeader` were removed because this redesign made them unused.

## 3. Build and device (Redmi Note 5 Pro, Android 9)
- `flutter build apk --debug` built, and `pm install -r -t` succeeded.
- **Screenshots inspected:**
  - The compact main screen with Section 2 open.
  - Commodity & Pricing expanded, with the Batch/Lot badge and "Additional Details (Optional)".
  - The collapsed Warehouse & Loading summary.
- **Bugs found on the device and fixed:**
  1. **Contradictory location text.** The saved profile location matched the state but not the district, and the screen showed "Filled from your saved profile location" next to "No warehouse location yet". It now shows one message ("…district needs to be chosen again"), and a regression test was added.
  2. **Headers missing a screen-reader tap action.** The device's accessibility dump showed `clickable="false"` on a section header. The tap action is now exposed, and a semantics test was added.
- **Not captured on the device:** the lab section, the broker section and the review sheet. You were using the phone at the time (the summary updated live to "Acid Oil · Average"), so I stopped sending taps. These states are covered by the widget tests only. The build with fix 2 was **not reinstalled** for the same reason.

## 4. Scope check
`git status` for this sprint:
- Modified: `post_commodity_screen.dart`, `seller_profile_repository.dart` (additive), 4 Post Commodity test files
- New: `test/support/fake_profile_repository.dart`, 3 reports

No schema, RLS, migration, repository-submission, lab, payment, broker-rule, auth or other-screen changes. The `auth_repository` changes in the working tree are from RB-SELLER-POST-CATEGORY-FIX-01.

## Status: **PASS WITH LIMITATIONS**
Limitations:
- The saved location is device-local.
- The lab, broker and review states were not visually inspected on the device.
- The final build with the accessibility fix is not installed yet.
