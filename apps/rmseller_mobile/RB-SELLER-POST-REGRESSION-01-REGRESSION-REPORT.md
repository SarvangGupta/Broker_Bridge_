# RB-SELLER-POST-REGRESSION-01 — Regression Report

## 1. Commands and exact outcomes
All commands were run from `apps/rmseller_mobile` with `D:\flutter_sdk\flutter\bin\flutter.bat`.

| # | Command | Passed | Failed | Skipped | Notes |
|---|---|---|---|---|---|
| 1 | `flutter test --reporter expanded` (**clean baseline**: this sprint's edits reversed, then restored and hash-verified) | **170** | **17** | 0 | 3 files fail to compile; 14 test failures |
| 2 | `flutter test test/unit/seller_lot_e2e_test.dart` (first run) | 10 | 2 | 0 | The fake echoed numeric strings; fixed by coercing `numeric` columns as PostgREST does (test fixture, not app) |
| 3 | `flutter test test/unit/seller_lot_e2e_test.dart test/widgets/post_commodity_screen_test.dart` | 25 | 2 | 0 | The two above, before the fixture fix |
| 4 | `flutter test test/unit/seller_lot_e2e_test.dart` | **12** | **0** | 0 | |
| 5 | `flutter test --reporter expanded` (after app fixes) | 184 | 17 | 0 | **Same 17 as the baseline** |
| 6 | `flutter test test/widgets/my_commodities_screen_test.dart` (after the timer fix) | 2 | 0 | 0 | Were baseline failures |
| 7 | `flutter test --reporter expanded` (**final**) | **186** | **15** | 0 | All 15 are in the baseline's failure list |
| 8 | `flutter analyze lib` + changed test files | — | — | — | **0 errors**; 7 warnings, all pre-existing in files not touched |
| 9 | `flutter build apk --debug` | — | — | — | **Built** |

A first background baseline that overlapped live edits (it showed "The Dart compiler exited unexpectedly") was **discarded** and replaced by run #1.

## 2. Baseline vs final
- **Fixed in this sprint:** `my_commodities_screen_test` (2): `!timersPending`; the test ended before the repository's 500 ms storage-lookup timer. A cleanup pump was added **after** the unchanged assertions.
- **New tests:** 12 (`seller_lot_e2e_test`) + 2 (lab report picker regressions) = **+14**, all passing.
- **New failures introduced:** **0**.

### Remaining failures (15): all present in the clean baseline, all outside this sprint's area
| File | Count | Cause (from output) |
|---|---|---|
| `counterparty_shield_test.dart` | load | Compile error: missing required `gradeName` |
| `broker_rating_display_test.dart` | load | Compile error: non-constant expression |
| `route_guard_test.dart` | load | Compile error: outdated go_router API |
| `auth_repository_test.dart` | 2 | Offline denial path does not clear the shared in-memory storage (token still set) |
| `negotiation_repository_test.dart` | 4 | Commission status stays "No Proposal" |
| `invoice_details_screen_test.dart` | 2 | Pre-existing UI expectation mismatch |
| `rate_broker_screen_test.dart` | 2 | Pre-existing UI expectation mismatch |
| `sales_history_screen_test.dart` | 2 | Pre-existing UI expectation mismatch |

No test was skipped, weakened or deleted to get a green result.

## 3. Bugs fixed
BUG-01 to BUG-09; see `RB-SELLER-POST-REGRESSION-01-BUGS-AND-FIXES.md`.

## 4. Files changed in this sprint
- `lib/features/commodities/data/commodities_repository.dart`
- `lib/features/commodities/presentation/commodity_details_screen.dart`
- `lib/features/commodities/presentation/post_commodity_screen.dart`
- `test/support/fake_postgrest.dart` (new)
- `test/unit/seller_lot_e2e_test.dart` (new)
- `test/widgets/post_commodity_screen_test.dart`
- `test/widgets/my_commodities_screen_test.dart`

**No** database, schema, migration, RLS or production change. Migration 0044 was not re-applied. The production database was only read: a read-only lot count and trigger check.

## 5. Remaining blockers and approvals needed
1. **Real server-backed E2E:** needs a staging project (or Supabase branch) with a test seller, **or** explicit approval for a production test listing.
2. **OPEN-01:** unique `(company_id, lot_number)` to stop duplicates after an ambiguous retry (DB change).
3. **OPEN-02:** server-side check that `broker_id` is a valid trusted broker (RLS change).
4. **OPEN-04:** persistence for payment terms, warehouse/office text and lab attachment (schema).
5. **0044 production status:** still pending the owner's decision from FIX-02 (keep or roll back).

## Overall status: **PASS WITH LIMITATIONS**
