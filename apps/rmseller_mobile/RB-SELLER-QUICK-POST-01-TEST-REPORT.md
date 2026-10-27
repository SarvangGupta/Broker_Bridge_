# RB-SELLER-QUICK-POST-01 — Test Report

All commands were run from `apps/rmseller_mobile` with `D:\flutter_sdk\flutter\bin\flutter.bat`.

## 1. Commands and outcomes
| # | Command | Passed | Failed | Skipped | Notes |
|---|---|---|---|---|---|
| 1 | `flutter test` on the 5 Post Commodity/location suites (first run) | 46 | 8 | 0 | 7 UX-04 tests: timers still pending from the offline readiness storage read (fixed: offline readiness no longer reads storage). 1 UX-05 assertion: the text now also appears on the readiness card (assertion updated) |
| 2 | Same, rerun | **54** | 0 | 0 | |
| 3 | `flutter test test/widgets/quick_post_test.dart` (first run) | 11 | 1 | 0 | Two "Retry" buttons (card + SnackBar); the test now targets the card |
| 4 | Same, rerun | **12** | 0 | 0 | |
| 5 | `flutter test test/unit/listing_readiness_test.dart` | **5** | 0 | 0 | Real repository over the loopback PostgREST |
| 6 | `flutter test --reporter expanded` (**full suite**) | **217** | **15** | 0 | |
| 7 | `flutter analyze lib test` | — | — | — | **0 errors** outside the 3 test files that already fail to compile; `lib/` warnings unchanged (pre-existing `_labReportType`) |
| 8 | `flutter build apk --debug` | — | — | — | **Built** (not installed) |

**Against the previous baseline (200 / 15):**
- +17 new tests (12 + 5), all passing.
- The **same 15 failures by name**: 3 compile-error files; auth ×2, negotiation ×4, invoice ×2, rate-broker ×2, sales-history ×2.
- **0 new failures.** No test was skipped or weakened.

## 2. Scenario coverage (§11)
| # | Scenario | Test | Result |
|---|---|---|---|
| 1 | First-time seller, incomplete profile | `quick_post › incomplete profile: asks only for what is missing` (+ picker shows "Choose your first commodity") | PASS |
| 2 | First-time seller, complete profile | `… complete profile: no blocking step` | PASS |
| 3 | Returning seller, several commodities | `… previous commodities on top, deduplicated, newest first`; unit `history: distinct …` | PASS |
| 4 | Returning seller, no saved location | `… returning seller without a saved location is asked for it` | PASS |
| 5 | Profile lookup fails | `… profile lookup failure: retryable, not treated as first-time, and blocks listing`; unit `server error is "unable to verify"`, `no session …` | PASS |
| 6 | History lookup fails | `… history failure: error with retry, never "first commodity", catalogue still usable` | PASS |
| 7 | Previous selection + dedup | `… picking a previous commodity …`, unit `history: distinct …` | PASS |
| 8 | Category and grade prefill | `… picking a previous commodity prefills product, category and its grade` | PASS |
| 9 | New quantity and price required | `… quick post still requires new quantity and price` | PASS |
| 10 | Old quantity and price never reused | `… never the old quantity or price` (old 40 / ₹3333 absent; fields empty) | PASS |
| 11 | Profile location defaults | `post_commodity_screen › saved profile location fills…`; `quick_post › firm region prefilled from the server` | PASS |
| 12 | Profile completion → return to the lot | `… completing the address keeps the lot and saves the default once` (quantity "12" kept; default saved once) | PASS |
| — | Firm not linked | `… firm not linked: clear blocking message`; unit `incomplete: account not linked`, `firm record … missing` | PASS |
| 13 | Lab testing and report attachment | Existing `post_commodity_screen` tests (cancel / failure attach nothing) | PASS |
| 14 | Broker selection; old broker not carried over | `… quick post …` (`brokerId == null`); existing broker tests | PASS |
| 15 | Server-backed submission | `seller_lot_e2e_test` (REGRESSION-01; real repository over loopback PostgREST); `quick post …` sends the correct DTO | PASS (protocol-level) |
| 16 | Failed submission keeps the form, no false success | `post_commodity_screen › RLS rejection …`, `quick_post › profile lookup failure …` | PASS |
| 17 | New lot appears in My Commodities / Home | `seller_lot_e2e_test › a posted lot replaces the empty state` | PASS (protocol-level) |
| 18 | Price edit persists and refreshes | `seller_lot_e2e_test`, `commodity_details_screen_test` | PASS |
| 19 | Broker reassignment | `seller_lot_e2e_test` | PASS |
| 20 | Narrow screen | `post_commodity_screen › each section opens at 320px` | PASS |
| 20 | Android Back | Code only (standard Navigator; modal sheets pop on Back) | **Not executed on a device** |

## 3. Not executed
- **Real Supabase posting** with an authorized test seller: there is no staging, and production writes are not authorized. Coverage is the real repositories over the PostgREST protocol (loopback) only. No confirmed live server-backed post exists for this sprint.
- **On-device run** (including Back behaviour): the build was produced but not installed.

## Status: **PASS WITH LIMITATIONS**
Limitations:
- No real-database or device verification.
- The warehouse address persists on the device only (no server column).
- Payment terms and quality specs cannot be reused (not persisted).
