# RB-SELLER-POST-REGRESSION-01 — E2E Results

## How E2E was executed (and why)
- **Required by the sprint:** "a dedicated authorized seller account and synthetic data **in staging**".
- **Reality:** there is **no staging**. The only project, `imztlkvkxzeaekxvmcfe`, is **production**, and production write tests are not authorized (FIX-02; project rule).
- **Executed instead:** `test/unit/seller_lot_e2e_test.dart`.
  - It runs the **real** `CommoditiesRepository` online code: a real `SupabaseClient` with a signed-in session (`setInitialSession`), real PostgREST HTTP requests, and `RETURNING`.
  - The server is a **loopback PostgREST** (`test/support/fake_postgrest.dart`) seeded with the live column semantics: `numeric` columns are returned as numbers, and FK/RLS outcomes are injected as the real error codes.
- **Live RLS evidence for the same operations** (insert own company, read own restricted lot, update own price, cross-company denials) comes from FIX-01: 10/10 impersonated checks on production, rolled back.

Command: `flutter test test/unit/seller_lot_e2e_test.dart` gave **12 passed, 0 failed, 0 skipped**.

## Core scenario: post → change price → change broker
Test: `full lifecycle converges on the persisted values`. Fixture: seller of company C, plus a lot owned by company D.

| Step | Check | Result |
|---|---|---|
| 1 Post | Server-generated UUID returned; exactly **1** POST | PASS |
| 1 | POST `company_id` = **own company from the `users` row** (storage held a stale `…0101`) | PASS |
| 1 | `visibility = restricted`, `broker_id = A`, `loading_remarks` sent | PASS |
| 1 | Server read path (session cache cleared): lists **only** own lot, filter `company_id=eq.C` | PASS |
| 1 | Read back: asking price 22500, broker A **real name**, loading remarks | PASS |
| 2 Price | Update returns server-confirmed 23750; PATCH targets `id=eq.<lot>` and `company_id=eq.C` | PASS |
| 2 | Server row = 23750; `getCommodityById` = 23750 | PASS |
| 2 | Second update (24000) wins on read-back | PASS |
| 3 Broker | Update returns confirmed `broker_id = B`; server row = B | PASS |
| 3 | Read back: broker B and B's real name (embed) | PASS |
| 4 Integrity | `company_id` unchanged; company D's lot price and broker untouched; no duplicate POST | PASS |

## Failure scenarios
| Test | Result |
|---|---|
| Failed price update (500): exception, no notify, server and app keep the old price | PASS |
| Failed broker change (500): exception, no notify, broker A kept | PASS |
| Another company's lot: zero-row price **and** broker update are errors; foreign lot untouched | PASS |
| Unregistered broker ID: rejected **before** any request; assignment not cleared | PASS |
| Broker FK violation 23503: "not registered" message | PASS |
| RLS insert rejection 42501: `ListingSubmitException(code 42501)`, nothing cached as listed | PASS |
| Seller without a company: cannot post or list; no write sent | PASS |
| Duplicate concurrent submit: one POST | PASS |

## Demo / empty state
| Test | Result |
|---|---|
| Empty server result gives `[]`, **not** sample lots | PASS |
| Failed read gives `CommodityListException`, **not** sample lots | PASS |
| Posted lot replaces the empty state on the server read path | PASS |
| Offline sample lot: price change refused, no notify (`repo`) | PASS |

## Screen-level confirmation (widget tests)
- **Details screen:** an unconfirmed price change shows an error and keeps ₹5,850 (`details`, PASS).
- **Post screen:** an RLS rejection shows a friendly message and keeps the form (`ux05`, PASS).
- **Home and My Commodities:** they re-read through `getCommodities()` when `commoditiesUpdatedNotifier` fires. That notifier now fires **only after** server confirmation (asserted in the failure tests above). Not exercised as a widget test with a fake server, because `testWidgets` stubs `HttpClient`.

## Not executed (BLOCKED)
| Item | Reason |
|---|---|
| Real post, price and broker change against a real database with an authorized test seller | No staging; production writes not authorized |
| On-device run of the same flow | Same reason. The latest build (RB-SELLER-AVAILABILITY-RLS-FIX-01) is installed; this sprint's build was produced but not installed |
| App restart persistence against real data | Depends on the item above |
