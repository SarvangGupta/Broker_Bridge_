# RB-PRODUCT-MASTER-07 — Complete Catalogue, Searchable Product Selection & Category Labels

**Date:** 2026-10-24 · **Branch:** `feature/broker-nilesh` (uncommitted, not pushed)
**Outcome:**
- **All 216 supplied entries are accounted for** in the shared Product Master.
- **All three apps** now pick products through a searchable selector that shows the authoritative category label.
- **Grades are restricted to the selected product** in all three apps. For RMBroker (KI-43) this is also enforced in the data layer before every insert.
- **No historical data was changed.**

**Owner decisions taken this sprint (2026-10-24):**

| # | Decision |
|---|---|
| 1 | Source list pasted by the owner and implemented verbatim (the original list wasn't stored in the repo) |
| 2 | **Approved:** `SELECT` on `master_categories` for `authenticated` only (D11), so the apps can show category labels |
| 3 | **Approved:** rename the matching live categories to the A–K names, keeping IDs and moving no products. Oilseeds and Pulses are **not merged** |
| 4 | New tradable products are **active without grades**. They are selectable and searchable, but submission is blocked until a grade is defined. FAQ was **not** extended |

---

## 1. Production changes (two guarded transactions)

| Txn | When (UTC) | What | Result |
|---|---|---|---|
| **5175** | 2026-10-24 | Migration [`0042`](../supabase/migrations/0042_allow_authenticated_read_master_categories.sql): `GRANT SELECT ON master_categories TO authenticated` + policy `master_categories_read` (SELECT, `authenticated`, `USING (true)`). Rollback: [`rollback_0042.sql`](../supabase/migrations/rollback_0042.sql) | **COMMITTED.** The in-transaction diff was exactly +1 policy and +1 grant, with nothing removed. A buyer reads 9 categories; `anon` is still denied (42501) |
| **5177** | 2026-10-24 | 7 category renames, 8 new categories, 145 new products (64 active, 81 inactive), **0 grades** | **COMMITTED.** All pre-existing data fingerprints identical; re-run = `ALREADY_APPLIED_NOOP` |

**Note on 0042:** the first apply (txid 5174) **rolled back** with nothing written. The anon-denial check inside the transaction raised an expected error, and postgres.js then failed the commit. I switched the check to `t.savepoint()`, confirmed there was no residue (no policy, original grants), and re-applied as txid 5175.

**Safeguards in 5177:**
- `lock_timeout` 5 s, `statement_timeout` 60 s; `SHARE ROW EXCLUSIVE` lock on the three catalogue tables.
- **Idempotency:** all target IDs present → no-op; partial state → abort.
- **Baseline guard:** 61 / 57 / 9 / 60.
- **Every "existing" entry** must resolve to exactly one live row.
- **Each rename** is guarded by its current name (`WHERE id = … AND name = <old>`).
- **Duplicate guards:** normalized names against all rows, active and inactive.
- **Exact affected-row counts.**
- **Post-conditions:** 206 / 121 / 17 / 60; no active product without an active category; no duplicate names.
- **md5 fingerprints identical before vs after:**
  - other commodities;
  - categories (except names);
  - grades and units;
  - requirements and availabilities (`id + commodity + grade + unit`);
  - counts of deals, quotations, allocations, deal versions and negotiation events.
- A dry run (txid 5176, forced rollback) passed first.

**IDs:** new categories and products use deterministic UUIDv5 under the PM-06 namespace `3d025cc2-…` (keys `category:<name>`, `commodity:<name>`). Existing IDs are untouched.

| | Before | After |
|---|---|---|
| master_commodities (total / active) | 61 / 57 | **206 / 121** |
| master_categories | 9 | **17** |
| master_grades | 60 | 60 (none added) |
| requirements / availabilities / deals | 29 / 3 / 9 | 29 / 3 / 9 (unchanged) |
| quotations / allocations / deal versions / negotiation events | 9 / 5 / 9 / 2 | unchanged |

## 2. Source-list reconciliation: 216 entries

| Outcome | Count | Meaning |
|---|---|---|
| Existing record reused | **59** | Same product already in the master. Mapped by exact name, parenthetical or regional alias (e.g. "Mustard Cake (Sarson Khal)" → *Mustard Cake (Expeller)*), plural or word order ("Lentils", "Silage Maize", "Rice Bran Deoiled (DORB)"), or the established canonical record: Maize (Corn) → *Yellow Maize (Corn)*, Wheat → *Sharbati Wheat*, Soybean → *Soybean Seed*, Chickpea/Gram → *Chana* (stays **inactive**, D6). **No renames** |
| New, active | **64** | Tradable product, searchable/selectable, **no grade yet**, so submission is blocked with an explanation |
| New, inactive (held) | **81** | Created so the catalogue is complete, but **not selectable for trading** (see §4) |
| Same record as another entry | **9** | Listed in two groups (e.g. Soybean Meal in B and E, Broken Rice in A and C, Mineral Mixture in H and J, Maize Germ in C and K, Pulse Chuni/Pulses Chuni). One record, one category |
| Not created | **3** | Not a product: "other approved plant-protein concentrates", "other certified organic feed ingredients" (open-ended descriptors), and "Custom commodity products" (a capability) |

**Distinctions preserved, not merged:**
- Soybean Meal ≠ Soybean DOC;
- Groundnut Meal ≠ Groundnut Cake, and the same for the cottonseed, mustard, linseed and sesame meals vs their cakes;
- Rice/Maize/Wheat DDGS ≠ BDG ≠ Rice Distillers Grain ≠ Distillers Dried Grains with Solubles ≠ Wet Distillers Grains;
- Brewers' Grains ≠ Dried Brewers' Grains;
- Wheat Middlings ≠ Wheat Shorts ≠ Wheat Pollard;
- Limestone Powder ≠ Feed-grade Calcium Carbonate;
- Guar Meal ≠ Guar Korma;
- Bypass Fat ≠ Rumen-Protected Fat ≠ Bypass Fat Supplement;
- Rice Bran Oil Cake ≠ De-oiled Rice Bran (DORB).

The full per-entry table is in the appendix.

## 3. Categories (17)

| Category | ID | Change |
|---|---|---|
| A. Grains & Energy Ingredients | `a3b89ba6` | renamed from *Grains & Cereals* |
| B. Oil Cakes & Oil Meals | `a283c4bd` | renamed from *Oil Cakes & Meals* |
| C. Bran, Polish & Milling By-products | `7ccee785` | renamed from *Bran & Milling By-products* |
| D. Distillery & Fermentation By-products | new | |
| E. Protein Meals & Protein Ingredients | `8e8d1a96` | renamed from *Protein & Agri By-products*; also covers the "specialty protein" entries (no redundant category created) |
| F. Sugar, Starch & Liquid Energy Sources | `da1f9798` | renamed from *Molasses & Liquid Feed Ingredients* |
| G. Dry Fodder & Roughage | `6be050bd` | renamed from *Fodder & Roughage* |
| H. Minerals & Feed-grade Salts | new | |
| I. Vitamins, Premixes & Nutritional Supplements | new | |
| J. Finished Feeds & Compound Products | new | |
| K. Whole Oilseeds, Pulses & Other Agricultural Feed Commodities | `fe59c01d` | renamed from *Oilseeds* |
| Pulses | `10c47ba1` | **unchanged**: not merged into K, per decision 3 |
| Fats and Oils · Feed Binders and Processing Aids · Feed Additives · Organic and Specialty Ingredients | new | |
| maize (inactive, 0 products) | `1dbe45e5` | untouched |

**Category assignment followed the supplied list's grouping**, not word matching. For example, Groundnut/Cottonseed/Mustard/Linseed/Sesame **Meal** are in E as you listed them, while Soybean Meal and Rapeseed Meal (listed in both B and E) are in B. Existing products keep their current category.

## 4. Entries not available for trading, with reasons

All 81 are stored with `status = false`, so RMBuyer, RMSeller and RMBroker (now status-filtered) don't offer them.

| Group | Count | Reason |
|---|---|---|
| H. Minerals & Feed-grade Salts (all) | 20 | Classification review (03 §5, PM-04 §6) |
| I. Vitamins, premixes & supplements | 21 | Compliance + classification review (03 §5) |
| I. Yeast Culture, Live Yeast | 2 | Yeast products: compliance review (03 §5) |
| I. Electrolyte Supplement, Liquid Calcium Supplement, Calcium Bolus | 3 | **Veterinary-type**: D7b regulatory review; excluded from trading |
| J. Finished feeds (all except Mineral Mixture, which is the H record) | 19 | Product-vs-grade decision + classification review |
| E. Brewer's Yeast, Feed-grade Yeast Products; Specialty: Yeast Protein | 3 | Yeast products: compliance review |
| F. Liquid Energy Supplement, Molasses-based Feed Supplement | 2 | Formulated supplements: same review as I |
| Fats and Oils: Feed-grade Fat Powder | 1 | Fat supplement: same review as Bypass Fat |
| Feed Binders and Processing Aids (5), Feed Additives (4) | 9 | Feed additive compliance review |
| B. **Castor Meal** | 1 | **Owner decision needed:** castor meal contains ricin unless detoxified, and it was not previously reviewed. I held it as a precaution |
| Existing **Chana** (Chickpea, Gram) | — | Kept inactive per D6 |

**Schema limitation:** the only flag is `master_commodities.status`, which can't separate "visible in the catalogue" from "eligible for trading". Held items are therefore invisible in the apps' selectors. Showing them as non-tradable would need a schema change (e.g. a `trading_status` column), which needs separate approval. **No HSN codes, product codes, aliases, Hindi names, tax classes or approvals were stored.** In names, "approved" was dropped ("Mold Inhibitors", "Rumen Modifiers", …) so no approval is implied.

## 5. App changes

### RMBuyer
- [requirements_repository.dart](../apps/rmbuyer_mobile/lib/features/requirements/data/requirements_repository.dart):
  - catalogue rows carry `category_id`; category names come from `master_categories` (a failed read → "Category unavailable", never a guess);
  - `getMasterGrades` returns only the product's own grades and **no longer invents** a fallback (`21000000-…0099`) or hardcoded grade;
  - A→Z ordering.
- [master_requirement_data.dart](../apps/rmbuyer_mobile/lib/features/requirements/domain/master_requirement_data.dart): `categoryName` added; hardcoded `verifiedGrades` removed.
- [post_requirement_screen.dart](../apps/rmbuyer_mobile/lib/features/requirements/presentation/post_requirement_screen.dart):
  - category label under the selected product;
  - grade loading, error + retry, and "no grade defined" states;
  - submission blocked when the product has no grade.
- [commodity_picker_sheet.dart](../apps/rmbuyer_mobile/lib/features/requirements/presentation/commodity_picker_sheet.dart): `CategoryLabel` on every result.

### RMSeller
- [commodities_repository.dart](../apps/rmseller_mobile/lib/features/commodities/data/commodities_repository.dart):
  - live catalogue only, with no fallback list (the old fallback product/grade IDs collided with live commodity and state IDs);
  - A→Z ordering; categories joined; grades never invented.
- [master_commodity_data.dart](../apps/rmseller_mobile/lib/features/commodities/domain/master_commodity_data.dart): `categoryName`; hardcoded commodities and grades removed.
- **New** [commodity_picker_sheet.dart](../apps/rmseller_mobile/lib/features/commodities/presentation/commodity_picker_sheet.dart): searchable sheet with category label, refresh, and empty/no-match states.
- [post_commodity_screen.dart](../apps/rmseller_mobile/lib/features/commodities/presentation/post_commodity_screen.dart):
  - the product dropdown is replaced by the searchable field + category label;
  - **no first-product preselection** (only an exact ID from the route or edited lot);
  - the catalogue loads separately, with error + retry;
  - grade loading/error/no-grade states, and the grade is cleared on product change;
  - submit rejects a missing grade or a grade from another product;
  - an injectable repository for tests.

### RMBroker (KI-43 fixed)
- [trade_master_data.dart](../apps/rmbroker_mobile/lib/features/work/domain/trade_master_data.dart): `categoryName`, grade `parentId`, plus `gradesFor()` and `isValidProductGrade()`.
- [work_repository.dart](../apps/rmbroker_mobile/lib/features/work/data/work_repository.dart):
  - master data loads **active products only**, A→Z, with category names and each grade's `commodity_id`;
  - new `validateProductGrade()` checks in the database that the grade belongs to the product and the product is active, and runs **before every requirement and offer create**. An incompatible pair returns an error and nothing is inserted.
- **New** [commodity_picker_field.dart](../apps/rmbroker_mobile/lib/features/work/presentation/widgets/commodity_picker_field.dart) and [product_grade_fields.dart](../apps/rmbroker_mobile/lib/features/work/presentation/widgets/product_grade_fields.dart): searchable product field + category label + product-filtered grade dropdown, no-grade notice, and catalogue-unavailable + retry.
- [create_requirement_sheet.dart](../apps/rmbroker_mobile/lib/features/work/presentation/widgets/create_requirement_sheet.dart), [create_offer_sheet.dart](../apps/rmbroker_mobile/lib/features/work/presentation/widgets/create_offer_sheet.dart):
  - use the above; the **hardcoded fake fallbacks were removed** (`comm-101…`, `grade-101…`);
  - submit validation: product chosen, grade defined, grade belongs to product;
  - the Unit and Loading Readiness dropdowns were made `isExpanded` because they overflowed at phone width (found by the new tests).

### Database
- [0042_allow_authenticated_read_master_categories.sql](../supabase/migrations/0042_allow_authenticated_read_master_categories.sql) + [rollback_0042.sql](../supabase/migrations/rollback_0042.sql).

## 6. Tests, analysis, builds

| App | Analyze | Tests | Notes |
|---|---|---|---|
| RMBuyer | **No issues** | **187 passed, 4 skipped** (live tests opt-in), 0 failed | network guard active; new: Soybean DOC search + category, label follows selection, no-grade block, "Category unavailable", category-read failure, 2-request REST contract |
| RMSeller | 77 issues, **none in code written this sprint**; all pre-existing (e.g. 31 in `route_guard_test.dart`, deprecated `value:` usages) | **97 passed, 26 failed**. The 26 failures are **identical to HEAD** (HEAD: 88 passed, the same 26 failed), so **0 new failures** | checked by running the suite on a `git archive HEAD` snapshot; 9 new tests: search, category, grades per product, no-grade block, submitted product+grade IDs, error/retry, no first-item fallback |
| RMBroker | **No issues** | **304 passed**, 0 failed (baseline 295) | new: KI-43 grade filter, search "DOC"/case-insensitive, label update, no-grade block, "Category unavailable", offer sheet, DB guard request contract + rejection |
| Builds | — | `flutter build apk --debug` ✔ for all three | `apps/<app>/build/app/outputs/flutter-apk/app-debug.apk` |

**Production verification** (`pm07_verify.mjs`, new read-only session, app queries replayed as `authenticated` buyer/seller/broker): **24/24 PASS**.
- Each app's path returns 121 active products, all with a readable category.
- "Soybean DOC" → *Oil Cakes & Oil Meals* in all three paths.
- No held product is selectable.
- Every grade is linked to a commodity.
- Chana is inactive; no duplicate names.
- History is unchanged; `anon` still has no category access.

Search results on live data (`soybean`, `DOC`, `bran`, `MAIZE`, `molasses`) each return the expected products with their categories, e.g. `DOC` → Cottonseed DOC, Mustard De-oiled Cake (DOC), Soybean DOC [Oil Cakes & Oil Meals].

**Not verified:**
- **No manual device testing** was performed in this sprint, and the new builds were **not installed** on the phone.
- No requirements, offers or deals were submitted to production.

## 7. Remaining blockers / decisions

1. **Grades for the 64 new tradable products.** They can be searched and selected, but can't be submitted until each has a grade (FAQ was deliberately not extended). Needs a grade policy decision.
2. **Castor Meal**: confirm it should be tradable (ricin / detoxification) before activating.
3. **Held groups (81)**: activation per the existing reviews (H/I/J classification, yeast/additive compliance, D7b veterinary review).
4. **Catalogue visibility vs trading eligibility**: needs a schema change if held items should be *visible but not tradable*.
5. **Aliases / Hindi names**: synonyms such as "Rice Polishings", "Gram Churi" or "Silage Maize" are mapped to existing records, but **typing those exact synonyms won't find them** until alias storage exists (Batch 2 schema).
6. **"Dry Fodder & Roughage" now also holds silage and green fodder**, as in the supplied list G. Rename the category if "Dry" is unintended.
7. **Custom commodity products**: an admin-controlled product creation flow is a separate capability (not simulated here).
8. **RMBroker pre-existing, out of scope:** the create sheets still submit placeholder `unitId`/`stateId`/`districtId` (`00000000-…`) and fall back to demo buyer/seller companies, so live broker inserts would still fail those FKs. The new product-grade guard runs before that.
9. **RMSeller pre-existing:** 26 failing tests and 77 analyzer issues existed before this sprint.

---

## Appendix: per-entry reconciliation (216 entries, from the committed transaction's record)

**A.**

| Supplied entry | Outcome | Record (ID) | Category / note |
|---|---|---|---|
| Maize (Corn) | existing (reused) | Yellow Maize (Corn) `20000000` |  |
| Bajra (Pearl Millet) | existing (reused) | Bajra (Pearl Millet) `a14c3512` |  |
| Jowar (Sorghum) | existing (reused) | Jowar (Sorghum) `81ae27f3` |  |
| Barley (Jau) | existing (reused) | Barley `9d1f7f52` |  |
| Wheat | existing (reused) | Sharbati Wheat `20000000` |  |
| Paddy | existing (reused) | Paddy `0f22a1cf` |  |
| Broken Rice | existing (reused) | Broken Rice `b2b083b9` |  |
| Rice Grits | new, active (no grade yet) | `07c01923` | Grains & Energy Ingredients |
| Maize Grits | new, active (no grade yet) | `88e8e727` | Grains & Energy Ingredients |
| Maize Daliya | new, active (no grade yet) | `8f0a5dba` | Grains & Energy Ingredients |
| Wheat Daliya | new, active (no grade yet) | `84a38ad4` | Grains & Energy Ingredients |
| Sorghum Daliya | new, active (no grade yet) | `b001ba48` | Grains & Energy Ingredients |
| Oats | existing (reused) | Oats `94f75fe5` |  |
| Rye | new, active (no grade yet) | `cac510ce` | Grains & Energy Ingredients |
| Triticale | new, active (no grade yet) | `cad63979` | Grains & Energy Ingredients |
| Millet Screenings | new, active (no grade yet) | `925cd23e` | Grains & Energy Ingredients |

**B.**

| Supplied entry | Outcome | Record (ID) | Category / note |
|---|---|---|---|
| Mustard Cake (Sarson Khal) | existing (reused) | Mustard Cake (Expeller) `d48fb7a8` |  |
| Mustard DOC | existing (reused) | Mustard De-oiled Cake (DOC) `420fd101` |  |
| Cottonseed Cake (Binola Khal) | existing (reused) | Cottonseed Cake `e285c4fd` |  |
| Cottonseed DOC | existing (reused) | Cottonseed DOC `02a0d52f` |  |
| Groundnut Cake | existing (reused) | Groundnut Cake `bfcf4ea4` |  |
| Soybean Meal | new, active (no grade yet) | `575b3c53` | Oil Cakes & Oil Meals |
| Soybean DOC | new, active (no grade yet) | `8a9a8ec3` | Oil Cakes & Oil Meals |
| Sesame Cake (Til Khal) | existing (reused) | Sesame Cake `269925ea` |  |
| Linseed Cake (Alsi Khal) | existing (reused) | Linseed Cake `dc430eb5` |  |
| Sunflower Meal | existing (reused) | Sunflower Meal `eefc6a52` |  |
| Rapeseed Meal | new, active (no grade yet) | `ddb4db8c` | Oil Cakes & Oil Meals |
| Castor Meal | new, **inactive (held)** | `6fae70fa` | Oil Cakes & Oil Meals — Feed-safety review needed: castor meal contains ricin unless detoxified (not previously reviewed; owner decision) |
| Coconut Cake (Copra Cake) | existing (reused) | Coconut Cake `336f5bd0` |  |
| Palm Kernel Cake | existing (reused) | Palm Kernel Cake `3fcb1902` |  |
| Niger Seed Cake | new, active (no grade yet) | `d10e2c21` | Oil Cakes & Oil Meals |
| Safflower Cake | existing (reused) | Safflower Cake `221de82f` |  |
| Maize Germ Cake | existing (reused) | Maize Germ Cake `7dcc485c` |  |
| Rice Bran Oil Cake | new, active (no grade yet) | `dd728c82` | Oil Cakes & Oil Meals |

**C.**

| Supplied entry | Outcome | Record (ID) | Category / note |
|---|---|---|---|
| Rice Bran | existing (reused) | Rice Bran `f44a2056` |  |
| Rice Polish | existing (reused) | Rice Polish `15cdb14b` |  |
| Rice Polishings | existing (reused) | Rice Polish `15cdb14b` |  |
| Rice Bran Deoiled (DORB) | existing (reused) | De-oiled Rice Bran (DORB) `c5882ee5` |  |
| Wheat Bran (Chokar) | existing (reused) | Wheat Bran `8f58c547` |  |
| Wheat Middlings | new, active (no grade yet) | `f4dc64bd` | Bran, Polish & Milling By-products |
| Wheat Shorts | new, active (no grade yet) | `b02694a4` | Bran, Polish & Milling By-products |
| Wheat Pollard | new, active (no grade yet) | `58bd73b4` | Bran, Polish & Milling By-products |
| Rice Husk | new, active (no grade yet) | `ff02f733` | Bran, Polish & Milling By-products |
| Rice Husk Powder | new, active (no grade yet) | `17c55306` | Bran, Polish & Milling By-products |
| Maize Bran | existing (reused) | Maize Bran `6875a90e` |  |
| Maize Gluten Feed | existing (reused) | Maize Gluten Feed `83edfeda` |  |
| Maize Gluten Meal | existing (reused) | Maize Gluten Meal `516b4225` |  |
| Maize Germ | existing (reused) | Maize Germ `35350428` |  |
| Broken Wheat | new, active (no grade yet) | `ba8a3af2` | Bran, Polish & Milling By-products |
| Broken Rice | same record as | A → Broken Rice |  |
| Flour Mill By-products | new, active (no grade yet) | `d6d7b41f` | Bran, Polish & Milling By-products |

**D.**

| Supplied entry | Outcome | Record (ID) | Category / note |
|---|---|---|---|
| Rice DDGS | new, active (no grade yet) | `28a2d6c3` | Distillery & Fermentation By-products |
| Maize DDGS | new, active (no grade yet) | `ba4cab5b` | Distillery & Fermentation By-products |
| Wheat DDGS | new, active (no grade yet) | `6a696db0` | Distillery & Fermentation By-products |
| Rice BDG | new, active (no grade yet) | `f21f5c44` | Distillery & Fermentation By-products |
| Maize BDG | new, active (no grade yet) | `469c5802` | Distillery & Fermentation By-products |
| Wheat BDG | new, active (no grade yet) | `ba551abd` | Distillery & Fermentation By-products |
| Rice Distillers Grain | new, active (no grade yet) | `54ee2333` | Distillery & Fermentation By-products |
| Distillers Dried Grains with Solubles | new, active (no grade yet) | `c72b3c39` | Distillery & Fermentation By-products |
| Wet Distillers Grains | new, active (no grade yet) | `f4a4d2f3` | Distillery & Fermentation By-products |
| Brewers' Grains | new, active (no grade yet) | `ce6140d3` | Distillery & Fermentation By-products |
| Dried Brewers' Grains | new, active (no grade yet) | `f54437c9` | Distillery & Fermentation By-products |
| Molasses-based Distillery By-products | new, active (no grade yet) | `f796e6fb` | Distillery & Fermentation By-products |

**E.**

| Supplied entry | Outcome | Record (ID) | Category / note |
|---|---|---|---|
| Soybean Meal | same record as | B → Soybean Meal |  |
| Soybean DOC | same record as | B → Soybean DOC |  |
| Groundnut Meal | new, active (no grade yet) | `6bb190a4` | Protein Meals & Protein Ingredients |
| Cottonseed Meal | new, active (no grade yet) | `e1a0157d` | Protein Meals & Protein Ingredients |
| Rapeseed Meal | same record as | B → Rapeseed Meal |  |
| Mustard Meal | new, active (no grade yet) | `c477c4a8` | Protein Meals & Protein Ingredients |
| Sunflower Meal | same record as | B → Sunflower Meal |  |
| Linseed Meal | new, active (no grade yet) | `6a930ca5` | Protein Meals & Protein Ingredients |
| Sesame Meal | new, active (no grade yet) | `46b06eb6` | Protein Meals & Protein Ingredients |
| Maize Gluten Meal | same record as | C → Maize Gluten Meal |  |
| Guar Meal | new, active (no grade yet) | `806c0013` | Protein Meals & Protein Ingredients |
| Guar Korma | new, active (no grade yet) | `33c06a8f` | Protein Meals & Protein Ingredients |
| Guar Churi | existing (reused) | Guar Churi `82f7c2e7` |  |
| Pulses Chuni | new, active (no grade yet) | `f87c86bb` | Protein Meals & Protein Ingredients |
| Gram Churi | existing (reused) | Chana Churi `7a06a685` |  |
| Moong Chuni | existing (reused) | Moong Chuni `b7a8d197` |  |
| Urad Chuni | existing (reused) | Urad Chuni `082f6141` |  |
| Pea Protein Feed | new, active (no grade yet) | `8fb76505` | Protein Meals & Protein Ingredients |
| Brewer's Yeast | new, **inactive (held)** | `4c00c371` | Protein Meals & Protein Ingredients — Yeast product: compliance review (03 §5 lists yeast with feed additives) |
| Feed-grade Yeast Products | new, **inactive (held)** | `dfb8b567` | Protein Meals & Protein Ingredients — Yeast product: compliance review (03 §5 lists yeast with feed additives) |

**F.**

| Supplied entry | Outcome | Record (ID) | Category / note |
|---|---|---|---|
| Sugarcane Molasses | existing (reused) | Sugarcane Molasses `7ee21d3d` |  |
| Beet Molasses | existing (reused) | Beet Molasses `8b813187` |  |
| Liquid Jaggery By-product | new, active (no grade yet) | `aa269e28` | Sugar, Starch & Liquid Energy Sources |
| Feed-grade Glucose Syrup | new, active (no grade yet) | `c396341d` | Sugar, Starch & Liquid Energy Sources |
| Feed-grade Starch | new, active (no grade yet) | `4adb0f82` | Sugar, Starch & Liquid Energy Sources |
| Liquid Energy Supplement | new, **inactive (held)** | `ff664fd3` | Sugar, Starch & Liquid Energy Sources — Formulated supplement: classification review (same basis as I) |
| Molasses-based Feed Supplement | new, **inactive (held)** | `44b73171` | Sugar, Starch & Liquid Energy Sources — Formulated supplement: classification review (same basis as I) |

**G.**

| Supplied entry | Outcome | Record (ID) | Category / note |
|---|---|---|---|
| Wheat Straw (Gehu Bhusa) | existing (reused) | Wheat Straw `2bf008c9` |  |
| Paddy Straw | existing (reused) | Paddy Straw `973c25fd` |  |
| Bajra Kadbi | existing (reused) | Bajra Kadbi `13111deb` |  |
| Jowar Kadbi | existing (reused) | Jowar Kadbi `2c63822a` |  |
| Maize Stover | existing (reused) | Maize Stover `b871f743` |  |
| Barley Straw | new, active (no grade yet) | `feb085b7` | Dry Fodder & Roughage |
| Oat Hay | existing (reused) | Oat Hay `14fec5a3` |  |
| Lucerne Hay (Rijka) | existing (reused) | Lucerne Hay `f9cddcd6` |  |
| Berseem Hay | existing (reused) | Berseem Hay `d6f8225c` |  |
| Grass Hay | new, active (no grade yet) | `10dce1ec` | Dry Fodder & Roughage |
| Dry Fodder Bales | new, active (no grade yet) | `00da121d` | Dry Fodder & Roughage |
| Chopped Straw | new, active (no grade yet) | `c4531ac9` | Dry Fodder & Roughage |
| Silage Maize | existing (reused) | Maize Silage `db5c766e` |  |
| Sorghum Silage | existing (reused) | Sorghum Silage `8332e89e` |  |
| Green Fodder | new, active (no grade yet) | `f4f6ea17` | Dry Fodder & Roughage |
| Fodder Pellets | new, active (no grade yet) | `847e0b90` | Dry Fodder & Roughage |

**H.**

| Supplied entry | Outcome | Record (ID) | Category / note |
|---|---|---|---|
| Feed-grade Calcium Carbonate | new, **inactive (held)** | `92e2cbbd` | Minerals & Feed-grade Salts — Minerals: classification review (03 §5, PM-04 §6) |
| Limestone Powder | new, **inactive (held)** | `f2c2c908` | Minerals & Feed-grade Salts — Minerals: classification review (03 §5, PM-04 §6) |
| Dicalcium Phosphate (DCP) | new, **inactive (held)** | `dc985a73` | Minerals & Feed-grade Salts — Minerals: classification review (03 §5, PM-04 §6) |
| Monocalcium Phosphate (MCP) | new, **inactive (held)** | `9b81059e` | Minerals & Feed-grade Salts — Minerals: classification review (03 §5, PM-04 §6) |
| Feed-grade Diatomaceous Mineral Products | new, **inactive (held)** | `d92c8543` | Minerals & Feed-grade Salts — Minerals: classification review (03 §5, PM-04 §6) |
| Common Salt | new, **inactive (held)** | `8cd0e9da` | Minerals & Feed-grade Salts — Minerals: classification review (03 §5, PM-04 §6) |
| Feed-grade Sodium Bicarbonate | new, **inactive (held)** | `872e0ce0` | Minerals & Feed-grade Salts — Minerals: classification review (03 §5, PM-04 §6) |
| Magnesium Oxide | new, **inactive (held)** | `b4343607` | Minerals & Feed-grade Salts — Minerals: classification review (03 §5, PM-04 §6) |
| Magnesium Sulphate | new, **inactive (held)** | `467cce0f` | Minerals & Feed-grade Salts — Minerals: classification review (03 §5, PM-04 §6) |
| Calcium Sulphate | new, **inactive (held)** | `01998acd` | Minerals & Feed-grade Salts — Minerals: classification review (03 §5, PM-04 §6) |
| Mineral Mixture | new, **inactive (held)** | `474cc216` | Minerals & Feed-grade Salts — Minerals: classification review (03 §5, PM-04 §6) |
| Trace Mineral Premix | new, **inactive (held)** | `2d2192e5` | Minerals & Feed-grade Salts — Minerals: classification review (03 §5, PM-04 §6) |
| Chelated Mineral Premix | new, **inactive (held)** | `e3fc1bb5` | Minerals & Feed-grade Salts — Minerals: classification review (03 §5, PM-04 §6) |
| Zinc Sulphate | new, **inactive (held)** | `d7a4f280` | Minerals & Feed-grade Salts — Minerals: classification review (03 §5, PM-04 §6) |
| Copper Sulphate | new, **inactive (held)** | `8a03eeda` | Minerals & Feed-grade Salts — Minerals: classification review (03 §5, PM-04 §6) |
| Manganese Sulphate | new, **inactive (held)** | `5ae1ae12` | Minerals & Feed-grade Salts — Minerals: classification review (03 §5, PM-04 §6) |
| Ferrous Sulphate | new, **inactive (held)** | `5bc2cae3` | Minerals & Feed-grade Salts — Minerals: classification review (03 §5, PM-04 §6) |
| Cobalt Sulphate | new, **inactive (held)** | `9f59ac54` | Minerals & Feed-grade Salts — Minerals: classification review (03 §5, PM-04 §6) |
| Potassium Iodide | new, **inactive (held)** | `b3a001f6` | Minerals & Feed-grade Salts — Minerals: classification review (03 §5, PM-04 §6) |
| Sodium Selenite | new, **inactive (held)** | `2607f74f` | Minerals & Feed-grade Salts — Minerals: classification review (03 §5, PM-04 §6) |

**I.**

| Supplied entry | Outcome | Record (ID) | Category / note |
|---|---|---|---|
| Vitamin A Premix | new, **inactive (held)** | `d292e734` | Vitamins, Premixes & Nutritional Supplements — Vitamins/supplements/premixes: compliance + classification review (03 §5) |
| Vitamin D3 Premix | new, **inactive (held)** | `cad504e4` | Vitamins, Premixes & Nutritional Supplements — Vitamins/supplements/premixes: compliance + classification review (03 §5) |
| Vitamin E Premix | new, **inactive (held)** | `21418b96` | Vitamins, Premixes & Nutritional Supplements — Vitamins/supplements/premixes: compliance + classification review (03 §5) |
| Vitamin ADE Premix | new, **inactive (held)** | `581ae130` | Vitamins, Premixes & Nutritional Supplements — Vitamins/supplements/premixes: compliance + classification review (03 §5) |
| B-Complex Premix | new, **inactive (held)** | `39152de7` | Vitamins, Premixes & Nutritional Supplements — Vitamins/supplements/premixes: compliance + classification review (03 §5) |
| Vitamin-Mineral Premix | new, **inactive (held)** | `7acc3bbb` | Vitamins, Premixes & Nutritional Supplements — Vitamins/supplements/premixes: compliance + classification review (03 §5) |
| Bypass Protein | new, **inactive (held)** | `92ec142e` | Vitamins, Premixes & Nutritional Supplements — Vitamins/supplements/premixes: compliance + classification review (03 §5) |
| Bypass Fat | new, **inactive (held)** | `c497cf98` | Vitamins, Premixes & Nutritional Supplements — Vitamins/supplements/premixes: compliance + classification review (03 §5) |
| Rumen-Protected Fat | new, **inactive (held)** | `6d0be5d4` | Vitamins, Premixes & Nutritional Supplements — Vitamins/supplements/premixes: compliance + classification review (03 §5) |
| Rumen-Protected Amino Acids | new, **inactive (held)** | `94cb50c8` | Vitamins, Premixes & Nutritional Supplements — Vitamins/supplements/premixes: compliance + classification review (03 §5) |
| Protected Methionine | new, **inactive (held)** | `498d80d0` | Vitamins, Premixes & Nutritional Supplements — Vitamins/supplements/premixes: compliance + classification review (03 §5) |
| Protected Choline | new, **inactive (held)** | `03916409` | Vitamins, Premixes & Nutritional Supplements — Vitamins/supplements/premixes: compliance + classification review (03 §5) |
| Yeast Culture | new, **inactive (held)** | `8731729e` | Vitamins, Premixes & Nutritional Supplements — Yeast product: compliance review (03 §5 lists yeast with feed additives) |
| Live Yeast | new, **inactive (held)** | `831e2ab9` | Vitamins, Premixes & Nutritional Supplements — Yeast product: compliance review (03 §5 lists yeast with feed additives) |
| Probiotics | new, **inactive (held)** | `14737cab` | Vitamins, Premixes & Nutritional Supplements — Vitamins/supplements/premixes: compliance + classification review (03 §5) |
| Prebiotics | new, **inactive (held)** | `708078d7` | Vitamins, Premixes & Nutritional Supplements — Vitamins/supplements/premixes: compliance + classification review (03 §5) |
| Enzymes | new, **inactive (held)** | `dee59502` | Vitamins, Premixes & Nutritional Supplements — Vitamins/supplements/premixes: compliance + classification review (03 §5) |
| Mycotoxin Binder | new, **inactive (held)** | `8c1528a0` | Vitamins, Premixes & Nutritional Supplements — Vitamins/supplements/premixes: compliance + classification review (03 §5) |
| Toxin Binder | new, **inactive (held)** | `0ab43857` | Vitamins, Premixes & Nutritional Supplements — Vitamins/supplements/premixes: compliance + classification review (03 §5) |
| Buffer Mixture | new, **inactive (held)** | `346bd7ad` | Vitamins, Premixes & Nutritional Supplements — Vitamins/supplements/premixes: compliance + classification review (03 §5) |
| Electrolyte Supplement | new, **inactive (held)** | `a3bcaa42` | Vitamins, Premixes & Nutritional Supplements — Veterinary-type product: D7b regulatory review; excluded from trading (03 §5) |
| Feed-grade Urea | new, **inactive (held)** | `ff732d51` | Vitamins, Premixes & Nutritional Supplements — Vitamins/supplements/premixes: compliance + classification review (03 §5) |
| Anionic Salt Premix | new, **inactive (held)** | `0f32b4b2` | Vitamins, Premixes & Nutritional Supplements — Vitamins/supplements/premixes: compliance + classification review (03 §5) |
| Transition-Cow Premix | new, **inactive (held)** | `3e385a5c` | Vitamins, Premixes & Nutritional Supplements — Vitamins/supplements/premixes: compliance + classification review (03 §5) |
| Liquid Calcium Supplement | new, **inactive (held)** | `8fe9feaf` | Vitamins, Premixes & Nutritional Supplements — Veterinary-type product: D7b regulatory review; excluded from trading (03 §5) |
| Calcium Bolus | new, **inactive (held)** | `7fbc0068` | Vitamins, Premixes & Nutritional Supplements — Veterinary-type product: D7b regulatory review; excluded from trading (03 §5) |

**J.**

| Supplied entry | Outcome | Record (ID) | Category / note |
|---|---|---|---|
| Cattle Feed Mash | new, **inactive (held)** | `d3ff8d04` | Finished Feeds & Compound Products — Finished feeds: product-vs-grade decision + classification review (PM-04 §6) |
| Cattle Feed Pellets | new, **inactive (held)** | `0ac92973` | Finished Feeds & Compound Products — Finished feeds: product-vs-grade decision + classification review (PM-04 §6) |
| Cattle Feed Nuggets | new, **inactive (held)** | `cecd57a5` | Finished Feeds & Compound Products — Finished feeds: product-vs-grade decision + classification review (PM-04 §6) |
| Dairy Cattle Feed | new, **inactive (held)** | `c7d03cda` | Finished Feeds & Compound Products — Finished feeds: product-vs-grade decision + classification review (PM-04 §6) |
| High-Yield Dairy Feed | new, **inactive (held)** | `7eb6da0f` | Finished Feeds & Compound Products — Finished feeds: product-vs-grade decision + classification review (PM-04 §6) |
| Calf Starter | new, **inactive (held)** | `1d9336b6` | Finished Feeds & Compound Products — Finished feeds: product-vs-grade decision + classification review (PM-04 §6) |
| Calf Grower Feed | new, **inactive (held)** | `6c439b0a` | Finished Feeds & Compound Products — Finished feeds: product-vs-grade decision + classification review (PM-04 §6) |
| Heifer Feed | new, **inactive (held)** | `404fa085` | Finished Feeds & Compound Products — Finished feeds: product-vs-grade decision + classification review (PM-04 §6) |
| Dry-Cow Feed | new, **inactive (held)** | `846cf45a` | Finished Feeds & Compound Products — Finished feeds: product-vs-grade decision + classification review (PM-04 §6) |
| Transition-Cow Feed | new, **inactive (held)** | `1c750712` | Finished Feeds & Compound Products — Finished feeds: product-vs-grade decision + classification review (PM-04 §6) |
| Buffalo Feed | new, **inactive (held)** | `ccc91d52` | Finished Feeds & Compound Products — Finished feeds: product-vs-grade decision + classification review (PM-04 §6) |
| Bypass Protein Feed | new, **inactive (held)** | `e499c79b` | Finished Feeds & Compound Products — Finished feeds: product-vs-grade decision + classification review (PM-04 §6) |
| Bypass Fat Supplement | new, **inactive (held)** | `ffaa9365` | Finished Feeds & Compound Products — Finished feeds: product-vs-grade decision + classification review (PM-04 §6) |
| Mineral Mixture | same record as | H → Mineral Mixture |  |
| Milk-Fat Supplement | new, **inactive (held)** | `4214cfed` | Finished Feeds & Compound Products — Finished feeds: product-vs-grade decision + classification review (PM-04 §6) |
| Cattle Feed Concentrate | new, **inactive (held)** | `891d75c3` | Finished Feeds & Compound Products — Finished feeds: product-vs-grade decision + classification review (PM-04 §6) |
| Complete Feed | new, **inactive (held)** | `cebcbb0d` | Finished Feeds & Compound Products — Finished feeds: product-vs-grade decision + classification review (PM-04 §6) |
| Total Mixed Ration (TMR) | new, **inactive (held)** | `afdd9878` | Finished Feeds & Compound Products — Finished feeds: product-vs-grade decision + classification review (PM-04 §6) |
| Silage-based TMR | new, **inactive (held)** | `7bed94b1` | Finished Feeds & Compound Products — Finished feeds: product-vs-grade decision + classification review (PM-04 §6) |
| Feed Premix | new, **inactive (held)** | `02fb2a8f` | Finished Feeds & Compound Products — Finished feeds: product-vs-grade decision + classification review (PM-04 §6) |

**K.**

| Supplied entry | Outcome | Record (ID) | Category / note |
|---|---|---|---|
| Whole Cottonseed | existing (reused) | Whole Cottonseed `538f0096` |  |
| Soybean | existing (reused) | Soybean Seed `20000000` |  |
| Groundnut Kernels | existing (reused) | Groundnut Kernels `b99d2d0f` |  |
| Mustard Seed | existing (reused) | Mustard Seed `4f4d9356` |  |
| Sunflower Seed | existing (reused) | Sunflower Seed `bc0f6d5a` |  |
| Sesame Seed | existing (reused) | Sesame Seed `604870ec` |  |
| Linseed | existing (reused) | Linseed `ad5218c7` |  |
| Maize Germ | same record as | C → Maize Germ |  |
| Chickpea | existing, **inactive (held)** | Chana `b19c9beb` | Chana: kept inactive (D6, owner decision) |
| Gram | existing, **inactive (held)** | Chana `b19c9beb` | Chana: kept inactive (D6, owner decision) |
| Peas | existing (reused) | Peas `bb18843a` |  |
| Lentils | existing (reused) | Lentil `9e20108f` |  |
| Moong | existing (reused) | Moong (Green Gram) `220bd16a` |  |
| Urad | existing (reused) | Urad (Black Gram) `05efd180` |  |
| Chana Churi | existing (reused) | Chana Churi `7a06a685` |  |
| Pulse Chuni | same record as | E → Pulses Chuni |  |
| Pulse Screenings | new, active (no grade yet) | `af70a252` | Whole Oilseeds, Pulses & Other Agricultural Feed Commodities |
| Grain Screenings | new, active (no grade yet) | `c2803359` | Whole Oilseeds, Pulses & Other Agricultural Feed Commodities |
| Feed-grade Tapioca | new, active (no grade yet) | `c3220249` | Whole Oilseeds, Pulses & Other Agricultural Feed Commodities |
| Cassava Chips | new, active (no grade yet) | `bf1721dd` | Whole Oilseeds, Pulses & Other Agricultural Feed Commodities |
| Feed-grade Potato By-products | new, active (no grade yet) | `eabb438b` | Whole Oilseeds, Pulses & Other Agricultural Feed Commodities |

**Fats and oils**

| Supplied entry | Outcome | Record (ID) | Category / note |
|---|---|---|---|
| Feed-grade Vegetable Oil | new, active (no grade yet) | `e62d3657` | Fats and Oils |
| Soybean Oil | new, active (no grade yet) | `a7b94c0a` | Fats and Oils |
| Rice Bran Oil | new, active (no grade yet) | `2f60ea61` | Fats and Oils |
| Palm Oil | new, active (no grade yet) | `8917be0b` | Fats and Oils |
| Acid Oil | new, active (no grade yet) | `a36f8605` | Fats and Oils |
| Feed-grade Fat Powder | new, **inactive (held)** | `07dae332` | Fats and Oils — Fat supplement: same review as Bypass Fat (03 §5) |

**Specialty protein ingredients**

| Supplied entry | Outcome | Record (ID) | Category / note |
|---|---|---|---|
| Feed-grade DDGS Protein Concentrate | new, active (no grade yet) | `c0075520` | Protein Meals & Protein Ingredients |
| Yeast Protein | new, **inactive (held)** | `ca524fb4` | Protein Meals & Protein Ingredients — Yeast product: compliance review (03 §5 lists yeast with feed additives) |
| other approved plant-protein concentrates | **not created** |  | Open-ended descriptor, not a specific product; "approved" status cannot be asserted |

**Feed binders and processing aids**

| Supplied entry | Outcome | Record (ID) | Category / note |
|---|---|---|---|
| Feed-grade Pellet Binders | new, **inactive (held)** | `17cfeaae` | Feed Binders and Processing Aids — Feed additive / processing aid: compliance review (03 §5) |
| Anti-caking Agents | new, **inactive (held)** | `282892fc` | Feed Binders and Processing Aids — Feed additive / processing aid: compliance review (03 §5) |
| Antioxidants | new, **inactive (held)** | `9f221bf1` | Feed Binders and Processing Aids — Feed additive / processing aid: compliance review (03 §5) |
| Preservatives | new, **inactive (held)** | `fc109c38` | Feed Binders and Processing Aids — Feed additive / processing aid: compliance review (03 §5) |
| Mold Inhibitors | new, **inactive (held)** | `9de2b299` | Feed Binders and Processing Aids — Feed additive / processing aid: compliance review (03 §5) |

**Feed additives**

| Supplied entry | Outcome | Record (ID) | Category / note |
|---|---|---|---|
| Rumen Modifiers | new, **inactive (held)** | `2580be3d` | Feed Additives — Feed additive / processing aid: compliance review (03 §5) |
| Flavoring Agents | new, **inactive (held)** | `603ee451` | Feed Additives — Feed additive / processing aid: compliance review (03 §5) |
| Palatability Enhancers | new, **inactive (held)** | `a42d54eb` | Feed Additives — Feed additive / processing aid: compliance review (03 §5) |
| Digestive-support Additives | new, **inactive (held)** | `0d223177` | Feed Additives — Feed additive / processing aid: compliance review (03 §5) |

**Organic and specialty ingredients**

| Supplied entry | Outcome | Record (ID) | Category / note |
|---|---|---|---|
| Organic Maize | new, active (no grade yet) | `ac875cc0` | Organic and Specialty Ingredients |
| Organic Soybean Meal | new, active (no grade yet) | `68550144` | Organic and Specialty Ingredients |
| Organic Wheat Bran | new, active (no grade yet) | `91674508` | Organic and Specialty Ingredients |
| other certified organic feed ingredients | **not created** |  | Open-ended descriptor, not a specific product |

**Custom commodity products**

| Supplied entry | Outcome | Record (ID) | Category / note |
|---|---|---|---|
| Controlled administrator-created product option | **not created** |  | A capability (admin product creation), not a product record; not simulated by catalogue writes |

