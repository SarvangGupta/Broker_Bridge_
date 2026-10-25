# RMBUYER-NUTRITION-GUIDE-01 — Buyer Nutrition Guide (fifth tab)

Includes continuation sprint **RMBUYER-NUTRITION-CATEGORY-SEARCH-01** (global search + parent-category browsing).

Date: 2026-10-25 · Branch: `feature/broker-nilesh` · Status: implemented, uncommitted · Final sprint status: **PASS WITH LIMITATIONS** (full suite blocked by the session's permission gate)

## 1. Final behaviour

**Navigation.** The fifth bottom-navigation tab is Home · Requirements · Deals · **Nutrition Guide** (`/nutrition`) · Profile. Navigation is path-based, so `/profile` links are unaffected.

**Home page, top to bottom:**
1. A search field with the placeholder `Search raw material name or product code...`.
2. A data notice: categories are for browsing only, nutrient values aren't recorded, and the buyer should ask for a supplier lab report.
3. **Browse by category:** one card per *active* `master_categories` row, ordered by name. Each card shows the active product count, computed from the loaded catalogue. A category with no active products shows "No active products yet".
4. **Not available yet:** Calcium Source, Milk Production Support and Cost-Effective Options, each with its reason.

**Global search.** Typing replaces the cards with results from all active products, matched by name or product code. No category has to be chosen first. Each result shows:
- the exact product name;
- `Category: <exact category name>`;
- the code, when one is recorded.

No matches shows `No raw material matches "<query>".`

**Category browsing.**
- Tapping a card opens that category's active products. Membership is the approved `master_commodities.category_id` link, so it is never inferred from the product name.
- The category view has its own search, by name or code.
- An empty category shows "No active raw materials in this category yet."
- The back arrow, or system back, returns to the cards.

**Product details** open from global results and from category lists alike, in the same sheet. The sheet shows:
- the exact name;
- `Category: …`;
- `Product code: <code>` or `Product code: not recorded`;
- the nutrient-composition notice;
- **Grade Specifications**: each approved grade with its stored limits (e.g. `Moisture (max): 10`), with no units added.

**States.**
- **Loading:** shows a spinner.
- **Catalogue failure:** shows an error with Try Again, and never a fallback list.
- **Category-list failure:** shows "Could not load categories." with Retry, while global search keeps working.

**Superseded from sprint 01.** The goal chips (Protein / Fat-Energy / Roughage-Fibre / Mineral Source) were removed. They relabelled category unions as nutrient sources, and the owner has since said that category membership doesn't prove composition. They also excluded Oil Cakes & Oil Meals, which the owner rejected. Parent-category cards replace them.

## 2. Post Requirement (prefill)

**Correction to the sprint 01 report.** Sprint 01 said "only the material is prefilled." That was inaccurate. The shared form always preset quantity **50**, price **4800**, a delivery date **14 days out**, and the first saved location and payment term.

**Fix.** There is now an opt-in `blankCommercialTerms` flag on `PostRequirementScreen`. The router reads it from `extra`, and only the Nutrition Guide sets it. The Guide pushes `/requirements/new` with `{'commodity': <exact name>, 'blankCommercialTerms': true}`. The form then opens with:
- the material preselected, through the existing `matchInitialCommodity` exact-name match;
- quantity and price empty;
- location showing "Select delivery location", date showing "Select delivery date", and payment showing "Select payment terms".

Grade isn't preselected for products with more than one grade, which is existing behaviour.

**Validation.**
- **Existing checks are unchanged:** commodity, grade, quantity > 0, price ≥ 0, delivery location.
- **Blank mode only:**
  - an empty price is rejected ("Please enter your target price.") instead of being submitted as ₹0;
  - a missing date or payment term is rejected.
- Authentication, submission, broker notification and the success dialog are untouched. Nothing is reported as submitted unless `createRequirement` succeeds.

**Default entry points** (Requirements FAB, broker profile, search) keep the old defaults exactly, and a regression test confirms it. Whether those defaults should exist at all is a separate owner decision (§6).

## 3. Product Master comparison (live, read-only)

Inspected 2026-10-25 inside `BEGIN READ ONLY` transactions. No writes were made.

**The brief's A–K list does not match the approved master.** The live master has **16 active categories** and no letter or sort-order field. Its A–K labels exist only in `RB-PRODUCT-MASTER-07-IMPLEMENTATION-REPORT.md`. The app shows the live names, sorted alphabetically. It doesn't add letters, rename anything or hardcode a list.

| Brief (owner reference) | Live master category (PM-07 letter) | Active / held |
|---|---|---|
| A. Grains & Cereals | Grains & Energy Ingredients (A) | 18 / 2 |
| B. Oilseeds | Whole Oilseeds, Pulses & Other Agricultural Feed Commodities (K) | 12 / 0 |
| C. Pulses & Legumes | Pulses (no letter) | 4 / 0 |
| D. Oil Cakes & Oil Meals | Oil Cakes & Oil Meals (B) | 17 / 1 |
| E. Bran & Milling By-products | Bran, Polish & Milling By-products (C) | 15 / 0 |
| F. Protein & Agricultural By-products | split: Distillery & Fermentation By-products (D) 12/0; Protein Meals & Protein Ingredients (E) 14/3 | — |
| G. Pulses, Dals & Chilka | **no category**: Chuni/Churi items sit in Protein Meals; "Dal" sits in Grains | — |
| H. Sweeteners & Energy Sources | Sugar, Starch & Liquid Energy Sources (F) | 5 / 2 |
| I. Fodder & Roughage | Dry Fodder & Roughage (G) | 16 / 0 |
| J. Minerals & Mineral Ingredients | Minerals & Feed-grade Salts (H) | **0** / 20 |
| K. Other Raw Materials | **no category** | — |
| — | Vitamins, Premixes & Nutritional Supplements (I) | 0 / 26 |
| — | Finished Feeds & Compound Products (J) | 0 / 19 |
| — | Fats and Oils | 5 / 1 |
| — | Organic and Specialty Ingredients | 3 / 0 |
| — | Feed Additives | 0 / 4 |
| — | Feed Binders and Processing Aids | 0 / 5 |

*One inactive legacy category, "maize", is not shown.*

**Product-level differences (examples, not exhaustive):**
- **In the brief, not active in the live master:**
  - Organic Yellow Maize (live has "Organic Maize")
  - Bajra / Pearl Millet as a plain grain (live: "Bajra (Pearl Millet)")
  - Cottonseed and Groundnut as oilseeds (live: "Whole Cottonseed", "Groundnut Kernels")
  - Rapeseed / Canola seed
  - Chana, Arhar / Toor, Moth
  - Mixing Soyabean DOC
  - Rice Bran DOC (live: "De-oiled Rice Bran (DORB)")
  - Rice TDGS
  - Matira, Matira Chilka and all Chilka items
  - Jaggery / Gur, Sugar
  - Salt, Mineral Mixture, Limestone, DCP (minerals are held inactive)
  - "Other …" catch-alls
- **Placement differences:**
  - Maize Gluten Meal and Maize Gluten Feed are in *Bran, Polish & Milling By-products*. The brief puts them in F.
  - Green Fodder, Silage and Hay are all under *Dry Fodder & Roughage*.
- **Product codes:** only 3 active products have one (WHEAT-01, MAIZE-01, SOY-01). Search by code works, but most products have no code.

No master records were created, renamed or reassigned.

## 4. Data limitations (unchanged)

- **Nutrient data:** there are no nutrient columns anywhere in `public`. `master_quality_parameters` has 1 row (Moisture). Grade `parameters` hold only acceptance limits.
- **Prices:** no product price table exists.
- **No nutritional claims:** the guide therefore makes no protein, fat, fibre, calcium, yield, milk, price or "best/cheapest" claims.
- **Unavailable views:** Calcium, Milk Production Support and Cost-Effective Options stay "Not available yet".

## 5. Files

**Sprint 01**
- **New:**
  - `lib/features/nutrition/presentation/nutrition_guide_screen.dart`
  - `lib/features/nutrition/presentation/raw_material_details_sheet.dart`
- **Edited:**
  - `lib/app/router/app_router.dart` (the `/nutrition` branch)
  - `lib/features/home/presentation/navigation_shell.dart`
  - `test/widgets/navigation_shell_test.dart`

**This sprint (all under `apps/rmbuyer_mobile/`)**

| File | Change |
|---|---|
| `lib/features/nutrition/domain/nutrition_guide_data.dart` | new; replaces `nutrition_goal.dart`, which was deleted |
| `lib/features/nutrition/presentation/nutrition_guide_screen.dart` | rewritten: search at top, category cards, category view |
| `lib/features/nutrition/presentation/raw_material_details_sheet.dart` | goal param removed; "Grade Specifications"; product code line; pushes `blankCommercialTerms` |
| `lib/features/requirements/domain/master_requirement_data.dart` | `MasterCommodity.categoryId` (optional); `MasterCategory` |
| `lib/features/requirements/data/requirements_repository.dart` | `getMasterCategories()`: active `master_categories`, no fallback |
| `lib/features/requirements/presentation/post_requirement_screen.dart` | opt-in `blankCommercialTerms` (see §2) |
| `lib/app/router/app_router.dart` | passes `blankCommercialTerms` from `extra` |
| `test/support/fake_requirements_repository.dart` | `getMasterCategories` fake, plus error mode |
| `test/unit/nutrition_guide_data_test.dart` | new; replaces `nutrition_goal_test.dart`, which was deleted |
| `test/widgets/nutrition_guide_screen_test.dart` | rewritten |
| `test/widgets/post_requirement_blank_terms_test.dart` | new |

No RMSeller, RMBroker, schema, migration, RLS, auth or remote-data change. `master_categories` SELECT for `authenticated` already exists (migration 0042).

## 6. Verification

**Previous results (sprint 01; not proof of the final version):** analyze clean; 11/11 targeted tests passed.

**Newly verified results (this sprint):**

| Check | Result |
|---|---|
| `dart format` | Applied only to new Nutrition files and new tests (6 files). The package isn't dart-formatted overall (95 of 113 files would change), so existing files were not reformatted. |
| `flutter analyze` (whole package) | **No issues** |
| `nutrition_guide_data_test.dart` | **6 passed**: search by name/code, category-link filtering, counts, `categoryId` parsing, unavailable views, grade labels |
| `nutrition_guide_screen_test.dart` | **7 passed**, at 360 px width: search field above cards with the exact placeholder; counts; global search by name and code; no-match; category list and in-category search; back; empty category; details (Grade Specifications, code, composition notice); prefill payload; loading; catalogue error and retry; category error with search still working, and retry |
| `post_requirement_blank_terms_test.dart` | **2 passed**: blank mode leaves quantity, price, location, date and payment empty with the material preselected, and blank submit is blocked; default mode still shows 50 / 4800 |
| `navigation_shell_test.dart` | **2 passed**: five tabs; the tab bar fits at 360 px |
| Existing requirement-form tests (`post_requirement_screen`, `post_requirement_commodity_picker`, `post_requirement_broker_selection_widget`) | **30 passed**, re-run because the form changed |
| **Total targeted** | **47 passed, 0 failed, 0 skipped** |
| Full `flutter test` suite | **BLOCKED.** The Claude Code permission classifier denied it ("Modify Shared Resources"), twice across both sprints. It was not bypassed and remains unverified. Baseline before these sprints: 191 passed, 4 skipped. |
| Build (`flutter build`) | **Not run** |

**Unverified cases:**
- **On a device:** real fonts and layout, and the date and dropdown pickers in blank mode.
- **Against the live project:** whether the `master_categories` `is_active` filter behaves the same under an authenticated buyer session (read access was granted in migration 0042, but not exercised end to end here).
- **Submitting a requirement from the Nutrition Guide** with every field filled; only the blocked blank submit is tested.

## 7. Remaining blockers and owner decisions

1. **Full test suite:** run `flutter test` in `apps/rmbuyer_mobile`, or approve running it, before commit.
2. **Category hierarchy:** the brief's A–K differs from the approved master (§3). Changing names, adding G/K, or moving products is a gated master-data sprint and was not done here.
3. **Default form presets:** 50 / 4800 / +14 days / first location and payment remain on every non-Guide entry point. Decide whether to remove them app-wide.
4. **Held nutrition views:** these need verified per-product nutrient values (with source and basis) and comparable verified prices. That is a schema and data sprint and needs approval.
5. **Home screen overflows at 360 px:** these predate this work and were left unfixed as instructed.
