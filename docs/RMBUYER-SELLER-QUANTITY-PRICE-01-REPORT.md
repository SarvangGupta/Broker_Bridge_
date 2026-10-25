# RMBUYER-SELLER-QUANTITY-PRICE-01 — Report

Date: 2026-10-25 · Branch: `feature/broker-nilesh` · **Status: PASS WITH LIMITATIONS** · Uncommitted

## 1. Root cause and affected workflows

| Workflow | Finding |
|---|---|
| **RMBuyer: Post Procurement Requirement** (`post_requirement_screen.dart`) | **Real hardcoded defaults:** `TextEditingController(text: '50')` (quantity) and `text: '4800'` (target price). The quantity hint read `e.g. 100`. Only the Nutrition Guide entry (opt-in `blankCommercialTerms`) started blank. **The unit default was `units.first`**, and `master_units` has no ordering, so the live API returns `kg` first. That is why **22 of 29 live requirements are stored in kg** (quantities 40–100). The DTO also silently fell back to the MT unit ID when no unit was selected. |
| **RMBuyer: requirement save** (`requirements_repository.dart`) | With a client but an expired or missing session, the insert error was swallowed and a locally generated ID was returned, so the form showed **false success**. |
| **RMSeller: Post Commodity Lot** (`post_commodity_screen.dart`) | Already fixed in RB-RAW-MATERIAL-QUANTITY-PRICE-01: the `100`/`4800` there were placeholder hints (controllers were already empty); MT is preselected by name; the saved unit is kept on edit; the false-success path was removed. **Re-verified, not changed** in this sprint. |
| Other matches (offer counter dialog, Seller price-update dialog, Seller negotiation) | Only `e.g. …` hint text, no defaults. Unchanged. |

## 2. Verified contracts (live, read-only)

- **Quantity unit (Buyer requirements):** stored per row.
  - `requirements.quantity` is double precision; `requirements.unit_id` is a foreign key to `master_units(id, name, symbol)`.
  - The quantity is the number **in that unit**. No conversion exists anywhere in the app or backend.
  - The list and detail screens display each row's own unit symbol (from the join), so historical kg rows display as `kg`.
- **`master_units` (natural order):** `kg` "Kilograms", `MT` "Tonn" (duplicate), `MT` "Metric Ton" (`22000000-…0001`), `Qtl` "Quintal".
- **Live requirement units:** 22 kg, 6 Metric Ton, 1 Tonn.
- **Price:** `requirements.target_price` is double precision with no currency column. The form labels it **"Target Price (₹/<selected unit>)"**, which makes the existing convention INR per selected unit. That convention is unchanged. `4800` carried no stored meaning; it was only a prefill.
- **Seller (re-verified):** `availabilities.unit_id` per row; `asking_price` labelled "₹ per <unit>"; all 3 live listings are Metric Ton.

## 3. Changes (RMBuyer only)

**`lib/features/requirements/presentation/post_requirement_screen.dart`**
- **Empty fields:** quantity and target price start **empty** for every entry point. The hints are now "Enter quantity" / "Enter target price".
- **`PostRequirementScreen.defaultUnit`:** preselects the "Metric Ton" MT row, then any MT row. If there's no MT row, nothing is preselected and the buyer must choose; the submission now requires a unit instead of falling back to a hardcoded MT ID.
- **`validateQuantity`:** existing rule (required, more than 0), plus non-finite input rejected.
- **`validatePrice`:**
  - required, because the field is marked "*", and an empty field is never sent as ₹0;
  - numeric and finite;
  - not negative. **Explicit ₹0 stays allowed**, as before.
- **Error display:** field-level messages under the inputs, as well as the existing banner.
- **Price label:** shows the selected unit (`₹/MT`), or `₹/unit` before one is chosen.
- **Review summary:** shows "Not entered" instead of a blank " MT @ ₹/MT".
- **Unchanged:** the existing duplicate-submit guards (`_isSubmitting` plus the repository lock), and failed submissions keep the typed values.

**`lib/features/requirements/data/requirements_repository.dart`**
- **No-session branch:** now throws "Your session has expired…" instead of returning a fake ID. The client-null path used by tests is unchanged.

**Tests**
- **New:** `test/widgets/post_requirement_quantity_price_test.dart` (17 tests).
- **Updated, because they relied on the hidden `50`/`4800` defaults:** `post_requirement_commodity_picker_test.dart` (its `_submit` helper now types a quantity and price), `post_requirement_screen_test.dart`, `post_requirement_broker_selection_widget_test.dart`, and `post_requirement_blank_terms_test.dart` (the "default entry" test now expects empty fields).
- **Test fake:** `test/support/fake_requirements_repository.dart` gains optional `units`, `submitError` and `submitGate`.

**Not changed:** RMSeller and RMBroker code, the database, schema, RLS, API contract and historical rows.

## 4. Conversion

**None is applied, and none is needed.** Each record stores its own unit, so quantity is entered and saved in the selected unit with no transformation. That rules out double conversion (a test asserts that `quantity`, `target_price` and `unit_id` reach the insert payload unchanged). `1 MT = 1,000 KG` has no boundary to apply at today. Historical kg rows are neither relabelled nor converted.

## 5. Verification

| Check | Result |
|---|---|
| `dart format` (new test) | applied |
| `flutter analyze` (RMBuyer, whole package) | **No issues found** |
| New tests (`post_requirement_quantity_price_test`) | **17 passed** |
| **Full RMBuyer suite** (`test/widget_test.dart`, `test/widgets`, `test/unit`) | **280 passed, 4 skipped** (opt-in live tests), 0 failed |
| RMSeller listing regression (`post_commodity_quantity_price`, `post_commodity_product_picker`, `post_commodity_ux04`, `commodities_repository_test`) | **36 passed** |
| `flutter build apk --debug` (RMBuyer) | **Built** |

**What the new tests cover:**
1. The unit default with the live row order, where `kg` comes first, picks Metric Ton. With no MT row, nothing is preselected.
2. Validator rules, including non-finite input.
3. A new form starts with empty quantity and price, MT preselected and a `₹/MT` label.
4. Seven invalid-input cases block submission: empty, 0, nonnumeric or non-finite quantity; empty, negative or nonnumeric price.
5. Empty fields show field-level messages.
6. A valid entry submits exactly 25.5 at ₹4,850.50 with the Metric Ton ID, and the insert payload is unconverted.
7. An explicit ₹0 is accepted.
8. With no MT unit, the form asks for a unit.
9. A failed save keeps the input and shows no success dialog.
10. A rapid double tap produces one submission.

**Not verified:**
- The repository's no-session throw (it needs a real signed-out Supabase client; checked by code review).
- On-device behaviour.
- No live-database tests were run.

## 6. Limitations and items for the owner

1. **Historical kg requirements (data question, needs a decision):** 22 live requirements are stored in `kg` with quantities of 40–100, most likely entered as tonnes because of the old `units.first` default. They display honestly as kg. Whether they should be corrected (multiplied by 1,000 or relabelled) is a **data decision and a bulk update**, which this sprint doesn't allow. No change was made.
2. **Duplicate MT unit:** "Tonn" (`afd6b4a9…`) duplicates "Metric Ton". 1 requirement uses it. Consolidation is a master-data change.
3. **Price rules unchanged:** an explicit ₹0 target price is still accepted (existing rule); whether a zero target should be allowed is a product decision.
4. **Other prefills left as they were:** the form's existing delivery-location, date (+14 days) and payment-term prefills are outside this sprint and unchanged. The Nutrition Guide entry still blanks them.

## 7. Preservation statement

All existing uncommitted work was preserved; the git status comparison shows only the files listed in §3 as new changes, with nothing removed. `post_requirement_screen.dart` and `requirements_screen.dart` already carried earlier-sprint changes. No database, schema, RLS, auth or API changes; no bulk or historical updates; no production writes; no commits, pushes or deployments.
