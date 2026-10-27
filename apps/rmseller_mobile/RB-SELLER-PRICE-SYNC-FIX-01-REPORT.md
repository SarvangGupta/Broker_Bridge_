# RB-SELLER-PRICE-SYNC-FIX-01 — Asking Price Update Not Reflecting

**App:** RM Seller (`apps/rmseller_mobile`) · **Date:** 2026-10-27

## 1. Reproduction (evidence)
- **Device (Redmi Note 5 Pro):** Home showed *LOT-CHANA-01 · ₹5850/MT*, *LOT-SOY-04 · ₹4950/MT* and *Mustard Seeds*. These match exactly the hard-coded `_baselineCommodities` in `commodities_repository.dart` (IDs `AVL-2026-001…003`).
- **Same device log session:** creating a real lot failed with `new row violates row-level security policy for table "availabilities"`. So this seller company has **no real lots**; only the demo fallback is displayed.
- **Widget test reproduction:** before the fix, updating such a lot showed "Asking price updated to ₹… successfully!" even though nothing was saved.

## 2. Root cause
1. **`getCommodities()`** returns `_baselineCommodities` (sample lots) whenever the server returns no rows.
2. **`updateCommodityPrice()`** could not persist a price for those lots, and still reported success:
   - The IDs are not UUIDs, so the `availabilities` update errors. The error was **caught and only logged**.
   - Even for real lots, `.update()` had no `.select()`, so an update that matched **zero rows** (wrong company, or blocked by RLS) looked like success.
   - It **always returned `true`** and fired `commoditiesUpdatedNotifier`.
3. **`CommodityDetailsScreen`** ignored the result, patched its local copy with the typed price, and showed the success SnackBar.
4. Home and My Commodities listen to the notifier and re-read the list. For a sample lot that re-read returns the **original** price again, so the screens disagreed and the change was lost on reopening.

There was no field mismatch: the client writes `price` and `asking_price` and reads `asking_price` (falling back to `price`) everywhere.

## 3. Fix (files changed)
| File | Change |
|---|---|
| `lib/features/commodities/data/commodities_repository.dart` | `updateCommodityPrice` now **returns the price the server confirms**, or throws the new `PriceUpdateException`. See the steps below. |
| `lib/features/commodities/presentation/commodity_details_screen.dart` | Uses the returned confirmed price. On `PriceUpdateException` it shows the error, keeps the last confirmed price and shows **no** success message. A non-positive entry now gets a message instead of silently doing nothing. |
| `test/unit/commodities_repository_test.dart` | Existing test updated to the new return type, plus 5 tests. |
| `test/widgets/commodity_details_screen_test.dart` | +1 test: failed update → error, no success, price unchanged. |

How `updateCommodityPrice` now works:
1. Rejects a non-positive price.
2. Rejects an ID that isn't a UUID (sample lots) before sending any request.
3. Sends the update **with `.select('id, asking_price, price')`**. Zero returned rows means *not updated* and throws.
4. Treats network or PostgREST errors as failure (throws), instead of swallowing them.
5. Only after confirmation, writes the confirmed value into the session cache and fires `commoditiesUpdatedNotifier`.
6. Offline/test mode (no client): only lots in this session's cache can change; anything else throws.

### Synchronisation after a successful update
- The **details page** shows the server-confirmed value.
- **Home and My Commodities** already re-read through `getCommodities()` when `commoditiesUpdatedNotifier` fires. Now that the notifier fires only after a confirmed update, they re-read the persisted `asking_price` from the server, or the updated session-cache copy for a lot created this session.
- Reopening the details page re-reads the same source.
- No new cache, no local-only price and no full-page reload were added.

## 4. Verification
| Command | Result |
|---|---|
| `flutter test test/unit/commodities_repository_test.dart test/widgets/commodity_details_screen_test.dart` | **All 17 passed** (after the fix) |
| Same, plus `seller_home_screen_test`, `post_commodity_screen_test`, `post_commodity_quantity_price_test`, `my_commodities_screen_test` | 47 passed, **2 failed**: both in `my_commodities_screen_test`. They **fail identically with the HEAD versions** of the two changed files (swapped in temporarily, then restored and hash-verified), so they are pre-existing. |
| `flutter analyze lib/features/commodities` + changed tests | 0 errors; 1 pre-existing warning (`_labReportType`) |
| `flutter build apk --debug` | Built. **Not installed:** you were using the phone. |

Scenario coverage (§6):

| # | Scenario | How verified |
|---|---|---|
| 1, 3, 5, 7 | Update ₹5000→₹5250, read back via `getCommodityById`; second update to ₹5400 wins | unit test |
| 2, 9 | Success shown only after confirmation; a failed request, a sample lot, or no matching row raises an error, with no notifier and no success message | unit and widget tests |
| 8 | Updating lot A leaves lot B's price unchanged | unit test |
| 10 | Non-positive price rejected | unit test |
| 4, 6 | Home and listing re-read through the notifier | code path. Not run on the device: there were no real lots, and creating lots is blocked by RLS (below). |

**Not tested against Supabase:** a successful update of a real lot on the live database. No real lot exists for this seller, and the sprint forbids changing production prices without approval.

## 5. Remaining limitations / blockers
1. **Sample lots look real.** `getCommodities()` still shows the hard-coded sample lots when a seller has none. Their prices now correctly **cannot** be changed and say so. Removing or labelling that fallback is a separate data-integrity change and was not done here.
2. **Creating lots is blocked by RLS** on `availabilities` INSERT for this seller (device log). This needs a separately approved RLS/account investigation and was not touched.
3. **Same silent-failure pattern elsewhere:** `updateCommodityStatus` and `updateCommodityBroker` still always return `true`. They are out of scope for this price-only fix and are recommended as a follow-up.

## 6. Scope confirmation
Only the price-update method, the details-page price handler and their tests changed. No schema, RLS, migration, auth, payment, deal or invoice changes, and no production data was modified. Other entries in `git status` are from earlier sprints (RB-SELLER-LOCATION-UX-01, RB-SELLER-POST-UX-05, RB-SELLER-POST-CATEGORY-FIX-01).

## Status: **PASS WITH LIMITATIONS**
