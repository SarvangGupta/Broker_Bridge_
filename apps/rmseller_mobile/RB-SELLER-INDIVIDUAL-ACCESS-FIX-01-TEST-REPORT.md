# RB-SELLER-INDIVIDUAL-ACCESS-FIX-01 — Test Report

All commands were run from `apps/rmseller_mobile` with `D:\flutter_sdk\flutter\bin\flutter.bat`. No production writes.

## 1. Commands and outcomes
| # | Command | Passed | Failed | Skipped |
|---|---|---|---|---|
| 1 | `flutter test test/unit/auth_unlinked_seller_test.dart test/unit/seller_lot_e2e_test.dart test/unit/seller_lot_integrity_test.dart test/unit/listing_readiness_test.dart` | **32** | 0 | 0 |
| 2 | `flutter test --reporter expanded` (**full suite**) | **229** | **15** | 0 |
| 3 | `flutter analyze lib test` | 0 errors outside the 3 test files that already fail to compile | | |
| 4 | `flutter build apk --debug` | Built (not installed) | | |

**Against the previous baseline (225 / 15):**
- +4 net tests (2 new sign-in tests; the old "seller without a company cannot … list" test was replaced by 3 tests reflecting the new rule).
- The **same 15 failing tests by name** (3 compile-error files; auth ×2, negotiation ×4, invoice ×2, rate-broker ×2, sales-history ×2).
- 0 new failures.

## 2. Coverage of the required cases
| # | Case | Test | Result |
|---|---|---|---|
| 1 | Seller with a company | `seller_lot_e2e_test › full lifecycle …`; `auth_unlinked_seller_test › linked seller keeps the company …` | PASS |
| 2 | Seller without a company | `seller_lot_e2e_test › seller without a company: lists empty, cannot post, never sees others` | PASS |
| 2b | Seller with **no users row** (the device account's state) | `… seller with no users row at all (unprovisioned): lists empty`; `auth_unlinked_seller_test › unprovisioned seller … none invented` | PASS |
| 3 | Unlinked seller with zero listings | Same; `getCommodities()` and `getPostingHistory()` return `[]` with **no `availabilities` request** | PASS |
| 4 | Unlinked seller with own listings | Requires 0047 + provisioning | **BLOCKED (not applied)** |
| 5 | Network or server failure | `… company lookup failure is an error, not an empty list`; `… a failed read is an error, not sample lots` | PASS |
| 6 | Reading another seller's records | The unlinked path issues no `availabilities` query. The linked path filters to own company (`… full lifecycle` asserts `company_id=eq.<own>` and the foreign lot is absent) | PASS |
| 7 | Modifying another company's records | `… another company's lot: zero-row update is an error`; unprovisioned price update rejected, foreign lot unchanged | PASS |
| 8 | Dashboard with no data | Repository returns `[]` (Home renders its empty state from that). **No Home widget test**: `SellerHomeScreen` builds its repositories internally | PARTIAL (repository level) |
| 9 | Posting and reads for unlinked sellers | Posting correctly **refused** with a clear message until 0047 | PASS (refusal) / BLOCKED (allowed path) |
| 10 | Company-linked seller and broker workflows | E2E, integrity and readiness suites (price, broker, status, retry) | PASS |

## 3. Not executed
- **No device run.** The build was not installed; the screenshot scenario was verified at repository level.
- **No database tests for 0047:** not applied. The validation plan is in the SQL file.

## Status: **PASS WITH LIMITATIONS**
- **Fixed:** Seller Desk no longer fails for unlinked or unprovisioned sellers, and no company is fabricated.
- **Blocked:** individual sellers posting lots needs approval of 0047 plus account provisioning.
