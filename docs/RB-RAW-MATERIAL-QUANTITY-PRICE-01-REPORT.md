# RB-RAW-MATERIAL-QUANTITY-PRICE-01 — Report

Date: 2026-10-25 · Branch: `feature/broker-nilesh` · **Status: PASS WITH LIMITATIONS** · Uncommitted

## 1. Root cause

In RMSeller's Post Commodity Lot form (`post_commodity_screen.dart`):

1. **"Defaults" 100 and 4800.** The quantity and price controllers already started empty. The `100` and `4800` were **placeholder hint texts** (`hintText: '100'`, `'4800'`), which look like pre-filled values.
2. **Unit was taken from list position, which is the real relabel risk.** `_selectedUnit = units.first` applied to both new and **edited** lots:
   - **Edit:** a lot saved in KG or Quintal reopened showing the first unit (e.g. MT) beside its unchanged number. Saving would have relabelled the quantity without converting it.
   - **New lot:** the default depended on database row order. Live `master_units` has no ordering and contains a duplicate MT row.
3. **The review card fabricated values.** It showed `0 MT` / `₹0 per MT` when the fields were empty, and assumed `MT` when no unit was selected.
4. **A failed save could look like success.** With a client present but no valid session, `CommoditiesRepository.createCommodity` swallowed the insert error and returned a locally made listing ID. The form then showed "listed successfully".

## 2. Confirmed contracts (live, read-only)

- **Unit.** It is stored **per listing**: `availabilities.unit_id` is a foreign key to `master_units(id, name, symbol)`. `total_quantity`, `available_quantity` and `quantity` hold numbers *in that unit*. Nothing in the system converts between units.
- **`master_units` rows:**
  - `kg` "Kilograms" (`bfefee25…`)
  - `MT` "Tonn" (`afd6b4a9…`): a **duplicate MT**
  - `MT` "Metric Ton" (`22000000-…0001`)
  - `Qtl` "Quintal" (`22000000-…0002`)
- **Existing listings:** all 3 use `22000000-…0001` "Metric Ton". **No listing is stored in KG**, so nothing historical needs converting.
- **Price.** `asking_price` and `price` are numeric with no column comment. The form labels them as ₹ per selected unit, and that convention is kept (INR, per the listing's unit). `4800` had no stored meaning; it was only a hint.

## 3. Changes

**`apps/rmseller_mobile/lib/features/commodities/presentation/post_commodity_screen.dart`**
- **Hints:** `100` → `Enter quantity`, `4800` → `Enter price`. Both fields still start empty.
- **`PostCommodityScreen.defaultUnit` (new lots):** prefers the MT row named "Metric Ton", then any MT row. If there's no MT row, nothing is preselected and the seller must choose (existing "Please select … unit" validation).
- **`PostCommodityScreen.unitForLot` (edit):** keeps the lot's saved unit, matched by `unitId` and then by symbol. If no match is found, it selects nothing rather than substituting another unit. Saved quantity and price are shown unchanged.
- **Price label:** now names the unit: `Asking Price (₹ per MT) *`, or `(₹ per KG)` etc.
- **Review card:** shows `Not entered` for empty fields, and `(select unit)` instead of assuming MT.
- **Submit validation:** now also rejects non-finite numbers (e.g. `1e999`). Missing, nonnumeric, zero and negative values were already rejected, and still are.

**`apps/rmseller_mobile/lib/features/commodities/data/commodities_repository.dart`**
- With a client but no valid session, `createCommodity` now throws ("Your session has expired…") instead of swallowing the error. The form's existing catch shows "Failed to submit commodity listing", so there's no false success.
- The test path with no client (`client == null`) is unchanged.

**Tests**
- New: `test/widgets/post_commodity_quantity_price_test.dart`, with 11 tests.
- Updated: one label assertion in `test/widgets/post_commodity_ux04_test.dart`, to the new unit-explicit label.

**No changes** to schema, migrations, RLS, auth, live data, RMBuyer or RMBroker.

## 4. Conversion and historical data

- **No conversion is applied, and none is needed.** Quantity is entered and stored in the listing's own unit.
- **MT is only preselected** for new lots. Editing keeps the saved unit, so no KG value is ever relabelled as MT.
- The verified factor (1 MT = 1,000 KG) has no boundary to apply at today. Adding conversion would require a single canonical storage unit, which doesn't exist; that's a separate, approval-gated design or migration decision.

## 5. Verification

| Check | Result |
|---|---|
| Formatter | New test file formatted. Existing files are not dart-formatted repo-wide, so they were not reformatted. |
| `flutter analyze` (commodities feature + new test) | 21 issues: 20 info + 1 warning (unused `_labReportType`, line 121). **Identical count at HEAD**, checked in a temporary worktree; none come from my changes. |
| Focused tests: new, `post_commodity_product_picker`, `post_commodity_ux04`, `commodities_repository_test` | **36 passed, 0 failed** |
| Full RMSeller suite | **110 passed, 26 failed**. The 26 failures are **identical by name** to HEAD (pre-existing). Baseline was 99 + 26; the +11 are the new tests. |

**Covered by tests:**
1. New quantity and price start empty, with no 100/4800 shown.
2. MT preselected, and the duplicate MT row is not chosen.
3. Price label shows the unit.
4. Review card shows `Not entered`.
5. Editing a KG lot keeps KG, `2500.0` and `23.5`.
6. An unknown saved unit is not substituted.
7. Missing, zero and nonnumeric quantity, and missing, negative and nonnumeric price, each block submission (6 tests).
8. Valid entry submits exactly 25 MT at ₹22,500.
9. A rejected save shows "Failed to submit…" with no success message.

**Not verified:**
- The no-session throw path in the repository. It needs a real Supabase client without a session; it was verified by code review only.
- On-device behaviour.
- Buyer listing display: none exists (see RMBUYER-SELLER-LISTING-VISIBILITY-01, BLOCKED).

## 6. Open dependencies (not done)

1. **Seller inserts are still rejected by RLS.** `availabilities_insert_policy` allows only brokers and admins, so a signed-in Seller's valid submission fails with an honest error. Fixing it needs an approved RLS change.
2. **Edit creates a new listing.** Editing a lot submits through `createCommodity` (an insert), not an update. Out of scope; needs a product decision.
3. **Duplicate MT unit row.** "Tonn" (`afd6b4a9…`) duplicates "Metric Ton"; 1 requirement uses it. Consolidating is a master-data change.
4. **Offline fallback unit IDs don't exist live.** RMSeller's fallback IDs (`30000000-…`) aren't in `master_units`, so an offline submission would fail the foreign key. It would fail honestly, not save bad data.
5. **`quantity` is an integer column.** `toSupabaseInsert` writes `totalQuantity.toInt()`, so 12.5 MT is stored as 12 there, while `total_quantity` keeps 12.5. Pre-existing; a schema question.
