# RB-SELLER-POST-INTEGRITY-02 — Test Report

All commands were run from `apps/rmseller_mobile` with `D:\flutter_sdk\flutter\bin\flutter.bat`.

## 1. Commands and outcomes
| # | Command | Passed | Failed | Skipped | Notes |
|---|---|---|---|---|---|
| 1 | `flutter test test/unit/seller_lot_integrity_test.dart` (first run) | 9 | 2 | 0 | Fixture listed only 4 numeric columns, so `reserved/sold_quantity` came back as strings. Fixed in the fixture (real Postgres returns numbers) |
| 2 | `flutter test test/unit/seller_lot_integrity_test.dart test/unit/seller_lot_e2e_test.dart test/unit/commodities_repository_test.dart` | **36** | 0 | 0 | |
| 3 | `flutter test test/widgets/commodity_details_screen_test.dart test/widgets/post_commodity_quantity_price_test.dart` | **20** | 0 | 0 | |
| 4 | `flutter test --reporter expanded` (**full suite**) | **200** | **15** | 0 | |
| 5 | `flutter analyze lib test` | — | — | — | 34 errors, **all** in the 3 test files that already failed to compile (`route_guard_test`, `counterparty_shield_test`, `broker_rating_display_test`); 0 in `lib/` or in any file changed here |
| 6 | `flutter build apk --debug` | — | — | — | **Built** (not installed) |

## 2. Comparison with the previous baseline (186 passed / 15 failed)
- **Passed:** 186 → **200** (+14 new tests, all passing).
- **Failed:** 15 → **15**. The failing test names are **identical** to REGRESSION-01's final list (same 3 compile-error files; auth ×2, negotiation ×4, invoice ×2, rate-broker ×2, sales-history ×2). Evidence: name-by-name comparison of the two full-run outputs. Those tests already failed in the clean pre-REGRESSION-01 baseline (170/17).
- **New failures:** **0**. No test was skipped, weakened or deleted.

## 3. New tests (14)
**`test/unit/seller_lot_integrity_test.dart`** (11): real repository, loopback PostgREST, signed-in session.

| Test | Covers |
|---|---|
| Fulfilled: confirmed by the server, then visible on re-read | success; PATCH targets the lot ID and own company; notify once; server read-back |
| Cancelled: confirmed … (Withdraw) | success |
| request failure: error, status unchanged, no notify | failure |
| authorization error (42501) gets a clear message | auth |
| zero-row update (another company's lot) is an error | no-op / tenant isolation |
| invalid lot id is rejected before any request | invalid ID |
| server stores a different status (no-op): treated as failure | no-op |
| today (no constraint): a retry after a lost response duplicates the lot | **documents the current production gap** |
| with proposed unique (company_id, lot_number): retry is refused clearly, one row | proposed 0045 + app 23505 mapping |
| constraint scope is per company | the same lot number in another company is allowed |
| valid, same-day and reversed windows | date rule |

**`commodity_details_screen_test.dart`** (2): an *unconfirmed Fulfill* and an *unconfirmed Cancel* show the error **with Retry**, never "Lot status updated", and the lot stays active.

**`post_commodity_quantity_price_test.dart`** (1): an edited lot with reversed dates shows the **field error** under Additional Details; the review does not open; nothing is submitted.

## 4. Lab attachment coverage
| Case | Status |
|---|---|
| Cancellation leaves the attachment unchanged | PASS (`post_commodity_screen_test › lab report picker cancel attaches nothing`, REGRESSION-01, re-run here) |
| Picker failure → message, nothing attached | PASS (`… picker failure attaches nothing`) |
| Upload failure / confirmed upload | **Not testable: there is no upload implementation.** Not faked; the minimum design is in the implementation report §4 |
| Device path not reported as a URL | CODE (`labReportFileUrl: remoteStorageUrl` only) |

## 5. Missing dates
The availability dates are non-nullable `DateTime`s, defaulting to today and today + 7 days. There is no empty state to test, so this is N/A.

## 6. Not executed
- **Real Supabase end-to-end** (status, price, broker and retry on a real database): no staging; production writes are not authorized. Coverage is the real repository over the PostgREST protocol (loopback) only.
- **On-device run** of this build: built, not installed.
