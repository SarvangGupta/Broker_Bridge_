# BUYER-PRODUCT-MASTER-02 — Live Catalogue Inspection & Canonical Catalogue Proposal

**Sprint:** BUYER-PRODUCT-MASTER-02 (read-only inspection + proposal) · **Follows:** [BUYER-PRODUCT-MASTER-01-AUDIT.md](BUYER-PRODUCT-MASTER-01-AUDIT.md)
**Date:** 2026-10-24 · **Branch / HEAD:** `feature/broker-nilesh` @ `390fd84`
**Status:** **Proposal only — awaiting owner approval.** No code, schema, data, policy or seed changes were made.

Evidence labels: **[Observed]** read from the live DB or repo · **[Proposed]** recommendation · **[Unverified]** not confirmed · **[Requires approval]** owner decision needed.

---

## 1. Executive summary

- **[Observed]** The live shared product master is small and inconsistent: 2 industries, 2 categories, **9 commodities (7 active)**, **8 grades**, 4 units. Live data holds 29 requirements, 3 availabilities and 9 deals linked through requirements.
- **[Observed]** There are 3 duplicate product pairs:
  - maize: `Yellow Maize (Corn)` and `maize`
  - wheat: `Sharbati Wheat` and `Wheat`
  - soybean: `Soybean Seed` and `Soyabean` (inactive)
- **[Observed]** There is 1 duplicate unit: `Tonn` (MT) duplicates `Metric Ton` (MT).
- **[Observed]** 4 of the 8 "grades" are actually quality parameters (`Moisture`, `Moisture : 14`, `Moisture <12%`, `Whiteness and Translucency`).
- **[Observed]** 5 of the 9 commodities have **no category**, including the 3 most-used ones.
- **[Observed]** The buyer's access path (`authenticated` role) **cannot read `master_categories`, `master_industries` or `master_quality_parameters`** (`42501 permission denied`: no GRANT and no policy). It can read commodities, grades and units. **Category grouping in RMBuyer is impossible until access is granted.**
- **[Observed]** There are no HSN columns anywhere. The only tax-related column in `public` is `companies.gst`.
- **[Observed]** Every live requirement references a valid commodity, grade and unit (0 orphans, 0 grade/commodity mismatches). **Requirements store IDs**, which confirms the Phase 1 finding.
- **[Observed]** 22 of 29 requirements use `Dal` + grade `Moisture` + unit `kg`. `Dal` is the first active commodity by name, and RMBuyer preselects the first commodity and its first grade. **[Unverified]** whether the default preselection caused this or these are test records.
- **[Proposed]** Keep the hierarchy `Industry → Category → Commodity → Grade` with no subcategory schema. Make the 3 seeded, used records canonical. Deactivate (never delete) their duplicates. Treat Sharbati as a wheat grade. Add 11 categories and roughly 110 candidate catalogue rows (existing, new and review items), all with HSN `Pending verification`. Do this through additive schema changes and an idempotent seed in later, approved sprints.

## 2. Inspection date and access limitations

| Item | Detail |
|---|---|
| Date/time | 2026-10-24 |
| Access method | Project-configured `DATABASE_URL` (the same path used by `test-db.ts` / `scripts/inspect-*.ts`). Credential not printed or stored |
| Connected role | `postgres` (not superuser; **BYPASSRLS = true**). Server PostgreSQL 17.6 |
| Write protection | Every query ran in `BEGIN READ ONLY` (`transaction_read_only = on` confirmed). Scripts kept in the session scratchpad, outside the repo |
| Buyer-path simulation | Read-only transactions with `SET LOCAL ROLE authenticated` + `request.jwt.claims.sub` = an existing buyer (identity anonymised), and `SET LOCAL ROLE anon` |
| Limitations | Data counts were read with an RLS-bypassing role, so they are true totals, not what a buyer sees. The simulation covers DB permissions, not the PostgREST HTTP layer. Remote migration history (`supabase_migrations`) was not inspected. No buyer PII was read beyond role counts |

## 3. Repository/schema evidence versus live database evidence

| Topic | Repository says | Live DB shows |
|---|---|---|
| Master table columns | 0002/0018/Drizzle: commodities `id, name, code, status, category_id` | **[Observed] identical**; no extra columns |
| HSN | PRD v4 planned `HSNCode`; not in schema | **[Observed]** none; only `companies.gst` |
| Unique constraints on names/codes | none | **[Observed]** none (PK indexes only) |
| RLS/policies on commodities, grades, units (0038) | SELECT `true` for anon+authenticated | **[Observed]** present exactly as written |
| Categories/industries/quality-params access | not defined in repo | **[Observed]** RLS on, **no policy, no SELECT grant** |
| Seed (`seed_broker_demo_dataset.sql`) | 3 commodities `2000…01–03`, 4 grades `2100…01–04`, 2 units | **[Observed]** all present, so the seed (or equivalent) was applied |
| RMBuyer fallback list | adds `2000…04` Mustard Seeds, `2000…05` Desi Chana | **[Observed] these IDs don't exist live**; a different, inactive `Chana` exists |
| `requirements` columns | Drizzle has `broker_id` | **[Observed]** `broker_id` exists; **no** `payment_terms`/`packaging`/`notes` columns |
| RB-DB-SEC-01 (10-19) "6 commodities, 4 grades" | — | **[Observed]** now 9 / 8, so records were added since (likely via web admin) |

## 4. Current hierarchy and record counts [Observed]

| Level | Total | Active | Notes |
|---|---|---|---|
| Industries | 2 | 1 | `Agriculture` (active), `Agro` (inactive) |
| Categories | 2 | 1 | `Grains & Cereals` → Agriculture (active); `maize` → Agro (inactive, 0 commodities) |
| Commodities | 9 | 7 | 5 without category |
| Grades | 8 | n/a (no status column) | all linked to a commodity |
| Units | 4 | n/a (no status column) | — |
| Quality parameters | 1 | 1 | on `maize` (`97ec…`) |
| Packaging types | 0 | — | table empty |

## 5. Current products, grades, units and usage

### 5.1 Commodities [Observed]
Usage: `requirements.commodity_id`, `availabilities.commodity_id`, deals counted via `deals.requirement_id → requirements.commodity_id`.

| ID (short) | Name | Code | Active | Category | Reqs | Avail | Deals | Grades | QP |
|---|---|---|---|---|---|---|---|---|---|
| `2000…0001` | Yellow Maize (Corn) | MAIZE-01 | ✔ | — | 4 | 2 | 7 | 2 | 0 |
| `97eccc57` | maize | — | ✔ | Grains & Cereals | 0 | 0 | 0 | 1 | 1 |
| `2000…0002` | Sharbati Wheat | WHEAT-01 | ✔ | — | 2 | 1 | 2 | 1 | 0 |
| `13a5208a` | Wheat | — | ✔ | Grains & Cereals | 0 | 0 | 0 | 0 | 0 |
| `2000…0003` | Soybean Seed | SOY-01 | ✔ | — | 1 | 0 | 0 | 1 | 0 |
| `efbc3e5e` | Soyabean | — | ✘ | — | 0 | 0 | 0 | 0 | 0 |
| `b19c9beb` | Chana | — | ✘ | — | 0 | 0 | 0 | 0 | 0 |
| `a732266b` | Dal | — | ✔ | Grains & Cereals | **22** | 0 | 0 | 1 | 0 |
| `56809459` | Rice | — | ✔ | Grains & Cereals | 0 | 0 | 0 | 2 | 0 |

All 29 requirements are on active commodities, so 0 reference an inactive product.

### 5.2 Grades [Observed]

| ID (short) | Commodity | Grade name | Has `parameters` | Reqs | Avail | Assessment |
|---|---|---|---|---|---|---|
| `2100…0001` | Yellow Maize (Corn) | Grade A Milling | ✔ | 3 | 2 | genuine grade |
| `2100…0002` | Yellow Maize (Corn) | Feed Grade Premium | ✔ | 1 | 0 | genuine grade |
| `2100…0003` | Sharbati Wheat | Premium Sharbati | ✔ | 2 | 1 | variety + grade |
| `2100…0004` | Soybean Seed | Standard Mandi Grade | ✔ | 1 | 0 | genuine grade |
| `0c90ef99` | maize | Moisture : 14 | ✘ | 0 | 0 | **quality parameter stored as grade** |
| `1f13a047` | Dal | Moisture | ✘ | **22** | 0 | **quality parameter stored as grade** |
| `eab13ce7` | Rice | Moisture <12% | ✘ | 0 | 0 | spec threshold, not a grade |
| `5a7a048d` | Rice | Whiteness and Translucency | ✘ | 0 | 0 | **quality attribute stored as grade** |

No duplicate grade names within a commodity.

### 5.3 Units [Observed]

| ID (short) | Name | Symbol | Reqs | Avail | Allocations | Assessment |
|---|---|---|---|---|---|---|
| `2200…0001` | Metric Ton | MT | 6 | 3 | 5 | canonical MT |
| `afd6b4a9` | Tonn | MT | 1 | 0 | 0 | **duplicate of Metric Ton** (misspelt) |
| `2200…0002` | Quintal | Qtl | 0 | 0 | 0 | canonical |
| `bfefee25` | Kilograms | kg | 22 | 0 | 0 | canonical (all 22 Dal reqs) |

Missing: bag, litre, bale (and possibly tonne-equivalent display rules). `master_units` has no status column, so a duplicate can't be hidden without a schema change.

## 6. Category-by-category coverage against the candidate catalogue

| Group | Live coverage [Observed] | Gap |
|---|---|---|
| A Grains & energy | Maize ×2 (dup), Wheat ×2 (dup), Rice | Bajra, Jowar, Barley, Oats, Paddy, Broken Rice, Rice Grits, daliya products |
| B Oil cakes & meals | none | all |
| C Bran & milling by-products | none | all |
| D Distillery/fermentation | none | all |
| E Protein ingredients / by-products | none | all |
| F Molasses & liquids | none | all |
| G Fodder & roughage | none | all |
| H Minerals | none | all |
| I Vitamins/supplements/premixes | none | all |
| J Finished cattle feeds | none | all |
| K Whole oilseeds & pulses | Soybean ×2 (1 inactive), Chana (inactive), Dal (generic) | Mustard seed, cottonseed, groundnut, sunflower, sesame, linseed, peas, lentil, moong, urad, tapioca |
| Veterinary-type nutrition | none | boluses, oral calcium, electrolytes: scope decision |

## 7. Canonical product catalogue proposal [Proposed]

### 7.1 Industries and categories [Proposed — Requires approval]
The hierarchy is retained. No subcategory schema is introduced.

| Industry | Category (proposed) | Existing ID |
|---|---|---|
| Agriculture (`d82dbe9c`, existing) | **Grains & Cereals** | `a3b89ba6` (existing; reuse) |
| Agriculture | Whole Oilseeds | new |
| Agriculture | Pulses | new |
| Animal Nutrition & Feed (new industry) | Oil Cakes & Meals | new |
| Animal Nutrition & Feed | Bran & Milling By-products | new |
| Animal Nutrition & Feed | Distillery & Fermentation By-products | new |
| Animal Nutrition & Feed | Protein Ingredients & Agri By-products | new |
| Animal Nutrition & Feed | Molasses & Liquid Feed Ingredients | new |
| Animal Nutrition & Feed | Fodder & Roughage | new |
| Animal Nutrition & Feed | Minerals & Mineral Ingredients | new |
| Animal Nutrition & Feed | Vitamins, Supplements & Premixes | new |
| Animal Nutrition & Feed | Finished Cattle Feeds | new |
| Animal Nutrition & Feed | Veterinary-type Nutritional Products | new (**scope approval**) |

Existing `Agro` industry and `maize` category stay inactive and untouched.

**Product type** (`commodity_type`, proposed column): `raw_material` (grains, whole oilseeds, pulses), `by_product` (cakes, brans, DDGS, churi/chuni, molasses), `fodder`, `mineral`, `supplement` (vitamins, premixes, additives), `finished_feed`, `veterinary_type`.

### 7.2 Catalogue table

Column conventions:
- **Status:** E = existing record (ID shown); N = new; R = requires review.
- **Units:** MT, Qtl, kg, bag (bag weight defined per lot/listing), L, bale (weight per lot).
- **Hindi (Devanagari):** **pending verification** for every row. Regional aliases listed are those supplied in the owner's candidate list, not independently verified.
- **HSN:** every row is **Pending verification**. Rows marked † are additionally **Requires classification review** (classification may depend on form, composition or intended use).
- **Lot-level, not master:** quality specs and lab reports belong to the lot/listing, not this table.

**A. Grains & Cereals (type raw_material)**

| Canonical name | Status | Aliases (candidate) | Grades / variants (proposed) | Units |
|---|---|---|---|---|
| Maize (Corn) | E `2000…0001` | Yellow Maize, Makka, Corn | Grade A Milling (E), Feed Grade Premium (E), Yellow (variety) | MT, Qtl, bag |
| Wheat | E `2000…0002` (rename from "Sharbati Wheat", **approval**) | Gehu | Premium Sharbati (E), Sharbati, Lokwan, Mill Quality | MT, Qtl, bag |
| Rice | E `56809459` (R) | Chawal | grades TBD (existing "grades" are quality attributes) | MT, Qtl, bag |
| Paddy | N | Dhan | — | MT, Qtl |
| Broken Rice | N | Rice Brokens, Khanda | — | MT, Qtl, bag |
| Rice Grits | N (R: vs Broken Rice) | — | — | MT, Qtl, bag |
| Bajra (Pearl Millet) | N | Pearl Millet | — | MT, Qtl, bag |
| Jowar (Sorghum) | N | Sorghum | — | MT, Qtl, bag |
| Barley | N | Jau | — | MT, Qtl, bag |
| Oats | N | Jai | — | MT, Qtl, bag |
| Maize Daliya | N (R: product vs Maize grade/form) | Makka Daliya | — | MT, Qtl, bag |
| Wheat Daliya | N (R) | Gehu Daliya | — | MT, Qtl, bag |
| Broken Wheat | N (R: vs Wheat Daliya) | — | — | MT, Qtl, bag |

**K1. Whole Oilseeds (raw_material)**

| Canonical name | Status | Aliases | Notes | Units |
|---|---|---|---|---|
| Soybean | E `2000…0003` (display rename from "Soybean Seed", **approval**) | Soyabean, Soya, Yellow Soybean | `efbc3e5e` "Soyabean" stays inactive as duplicate | MT, Qtl, bag |
| Mustard Seed | N | Sarson, Rai, Mustard Seeds | — | MT, Qtl, bag |
| Whole Cottonseed | N | Binola | — | MT, Qtl, bag |
| Groundnut Kernels | N | Moongphali, Peanut | in-shell vs kernel as grade | MT, Qtl, bag |
| Sunflower Seed | N | — | — | MT, Qtl, bag |
| Sesame Seed | N | Til | — | MT, Qtl, bag |
| Linseed | N | Alsi, Flaxseed | — | MT, Qtl, bag |

**K2. Pulses (raw_material)**

| Canonical name | Status | Aliases | Notes | Units |
|---|---|---|---|---|
| Chickpea (Chana) | E `b19c9beb` (reactivate, **approval**) | Chana, Desi Chana, Gram | Desi/Kabuli as grades | MT, Qtl, bag |
| Dal (generic) | E `a732266b` (**R**) | — | Generic "split pulse", not a single commodity; 22 reqs. Keep for history; propose deactivating after owner review | kg (observed) |
| Peas | N | Matar | — | MT, Qtl, bag |
| Lentil | N | Masoor | — | MT, Qtl, bag |
| Moong (Green Gram) | N | Mung | — | MT, Qtl, bag |
| Urad (Black Gram) | N | — | — | MT, Qtl, bag |
| Feed-grade Tapioca | N (R: category; it isn't a pulse) | Cassava | likely Grains/energy | MT, bag |

**B. Oil Cakes & Meals (by_product)**

| Canonical name | Status | Aliases | Grade/variant notes | Units |
|---|---|---|---|---|
| Mustard Cake (Expeller) | N | Sarson Khal | — | MT, Qtl, bag |
| Mustard De-oiled Cake (DOC) | N | Mustard DOC | distinct from expeller cake (solvent-extracted) | MT, bag |
| Cottonseed Cake | N | Binola Khal | — | MT, Qtl, bag |
| Cottonseed DOC | N | — | distinct | MT, bag |
| Groundnut Cake | N | Moongphali Khal | expeller vs DOC as grade (R) | MT, bag |
| Soybean Meal (DOC) | N | Soybean DOC, SBM, Soya DOC | "Soybean Meal" and "Soybean DOC" proposed as **one product** (R) | MT, bag |
| Sesame Cake | N | Til Khal | — | MT, bag |
| Linseed Cake | N | Alsi Khal | — | MT, bag |
| Sunflower Meal | N | Sunflower DOC | — | MT, bag |
| Rapeseed Meal | N (R: overlaps Mustard DOC in Indian trade) | — | — | MT, bag |
| Coconut Cake | N | Copra Cake | — | MT, bag |
| Palm Kernel Cake | N | PKC | — | MT, bag |
| Safflower Cake | N | — | — | MT, bag |
| Maize Germ Cake | N | — | distinct from Maize Germ | MT, bag |

**C. Bran & Milling By-products (by_product)**

| Canonical name | Status | Aliases | Notes | Units |
|---|---|---|---|---|
| Rice Bran | N | Chawal Bhusi | — | MT, bag |
| Rice Polish | N | Rice Polishings | "Rice Polish" and "Rice Polishings" proposed as **one product** | MT, bag |
| De-oiled Rice Bran (DORB) | N | DORB, Rice Bran Deoiled | — | MT, bag |
| Wheat Bran | N | Chokar | — | MT, Qtl, bag |
| Wheat Middlings | N (R) | Wheat Pollard? | Middlings vs Pollard: possible synonyms; **review** | MT, bag |
| Wheat Pollard | R | — | see above | MT, bag |
| Maize Bran | N | — | — | MT, bag |
| Maize Gluten Feed | N | MGF | distinct from MGM | MT, bag |
| Maize Gluten Meal | N | MGM | — | MT, bag |
| Maize Germ | N | — | — | MT, bag |

**D. Distillery & Fermentation By-products (by_product)**

| Canonical name | Status | Notes | Units |
|---|---|---|---|
| Rice DDGS | N | **kept separate**: source materially changes protein/fibre specs and price (R to confirm) | MT, bag |
| Maize DDGS | N | separate (R) | MT, bag |
| Wheat DDGS | N | separate (R) | MT, bag |
| Brewers' Dried Grains (BDG) | N | aliases Brewers' Grains; source (rice/maize/wheat/barley) as **grade** (R) | MT, bag |

**E. Protein Ingredients & Agri By-products (by_product)**

| Canonical name | Status | Aliases | Notes | Units |
|---|---|---|---|---|
| Guar Meal (Korma) | N (R) | Guar Korma | Meal vs Korma possibly same; **review** | MT, bag |
| Guar Churi | N | — | distinct fraction | MT, bag |
| Chana Churi | N | Gram Churi | "Gram Churi" and "Chana Churi" proposed as **one product** | MT, Qtl, bag |
| Moong Chuni | N | — | — | MT, Qtl, bag |
| Urad Chuni | N | — | — | MT, Qtl, bag |
| Pulse Chuni (mixed) | R | — | generic: keep only if traded as mixed lots | MT, bag |
| Yeast products (feed-grade) | R | — | placeholder; see Yeast Culture in I | kg, bag |

**F. Molasses & Liquid Feed Ingredients (by_product)**

| Canonical name | Status | Notes | Units |
|---|---|---|---|
| Sugarcane Molasses | N | — | MT, L |
| Beet Molasses | N | — | MT, L |
| "Approved feed-grade liquid ingredients" | **Out of scope as a product** | generic placeholder; add specific products when identified | — |

**G. Fodder & Roughage (fodder)**

| Canonical name | Status | Aliases | Notes | Units |
|---|---|---|---|---|
| Wheat Straw | N | Gehu Bhusa, Bhusa | chopped vs whole as **grade/form** (covers "Chopped Straw") | MT, Qtl, bale |
| Paddy Straw | N | Parali | — | MT, Qtl, bale |
| Bajra Kadbi | N | — | — | MT, Qtl, bale |
| Jowar Kadbi | N | — | — | MT, Qtl, bale |
| Maize Stover | N | — | — | MT, bale |
| Lucerne Hay | N | Rijka, Alfalfa | — | MT, bale |
| Berseem Hay | N | — | — | MT, bale |
| Oat Hay | N | — | — | MT, bale |
| Maize Silage | N | Silage Maize | — | MT, bag |
| Sorghum Silage | N | — | — | MT, bag |
| "Green Fodder", "Dry Fodder Bales", "Chopped Straw" | **Not products** | generic/form descriptors; map to specific products or grades | — |

**H. Minerals & Mineral Ingredients (mineral)** †

| Canonical name | Status | Aliases | Units |
|---|---|---|---|
| Limestone Powder (Feed-grade Calcium Carbonate) | N † | Calcite | kg, bag, MT |
| Dicalcium Phosphate (DCP) | N † | DCP | kg, bag, MT |
| Monocalcium Phosphate (MCP) | N † | MCP | kg, bag, MT |
| Common Salt (feed-grade) | N † | Namak | kg, bag, MT |
| Sodium Bicarbonate (feed-grade) | N † | — | kg, bag |
| Magnesium Oxide (feed-grade) | N † | — | kg, bag |
| Magnesium Sulphate (feed-grade) | N † | — | kg, bag |
| Mineral Mixture | N † | — | kg, bag |
| Trace Mineral Premix | N † (R: vs Mineral Mixture) | — | kg, bag |
| Chelated Mineral Premix | N † | — | kg, bag |

**I. Vitamins, Supplements & Premixes (supplement)** †

| Canonical name | Status | Notes | Units |
|---|---|---|---|
| Vitamin AD3E Premix | N † | Vitamin A, D3, E and ADE premixes proposed as **grades/variants** of one product (R) | kg, bag |
| Vitamin B-Complex Premix | N † | — | kg, bag |
| Vitamin-Mineral Premix | N † | "Feed Premix" (J) proposed as an alias here (R) | kg, bag |
| Bypass Protein | N † | — | kg, bag, MT |
| Bypass Fat (Rumen-Protected Fat) | N † | "Bypass Fat" and "Rumen-Protected Fat" proposed as one product (R) | kg, bag |
| Yeast Culture | N † | — | kg, bag |
| Probiotics | N † | — | kg |
| Prebiotics | N † | — | kg |
| Feed Enzymes | N † | — | kg |
| Mycotoxin Binder | N † | — | kg, bag |
| Buffer Mixture | N † | — | kg, bag |
| Anionic Salt Premix | N † | — | kg, bag |
| Transition-Cow Premix | N † | — | kg, bag |

**Veterinary-type Nutritional Products (veterinary_type) — Requires approval (scope)** †

| Candidate | Notes |
|---|---|
| Calcium Bolus | dosage-form product; may fall under veterinary/regulatory classification |
| Liquid (Oral) Calcium Supplement | same |
| Electrolyte Supplement | same |

**J. Finished Cattle Feeds (finished_feed)** †

| Canonical name | Status | Grade/variant proposal | Units |
|---|---|---|---|
| Cattle Feed | N † | forms **Mash / Pellets / Nuggets** as grades; use-segments below (R) | bag, MT |
| Dairy Cattle Feed (High-Yield) | N † (R: separate product vs Cattle Feed grade) | — | bag, MT |
| Buffalo Feed | N † | — | bag, MT |
| Calf Starter | N † | — | bag, kg |
| Calf Grower Feed | N † | — | bag |
| Heifer Feed | N † | — | bag |
| Dry-Cow Feed | N † | — | bag |
| Transition-Cow Feed | N † | — | bag |
| Cattle Feed Concentrate | N † | — | bag, MT |
| Complete Feed / Total Mixed Ration (TMR) | N † | "Complete Feed" and "TMR" proposed as one product with aliases (R) | MT, bag |

## 8. Duplicate, alias, grade and variant mapping register (existing records)

| Current ID | Current name | Proposed canonical | Action proposed | Reason | Usage (req/avail/deals) | Confidence | Approval |
|---|---|---|---|---|---|---|---|
| `2000…0001` | Yellow Maize (Corn) | **Maize (Corn)** | keep as canonical; display rename; add category Grains & Cereals | most-used maize record; seeded ID referenced by deals | 4/2/7 | High | **Requires approval** (rename) |
| `97eccc57` | maize | → Maize (Corn) | set `status=false`; keep row (has 1 grade + 1 quality parameter FK) | duplicate, 0 transactional usage | 0/0/0 | High | **Requires approval** |
| `2000…0002` | Sharbati Wheat | **Wheat** | keep as canonical; display rename; Sharbati remains via grade "Premium Sharbati" | Sharbati is a variety; preserves historical refs without moving requirement IDs | 2/1/2 | Medium (rename changes historical display in all apps) | **Requires approval** |
| `13a5208a` | Wheat | → Wheat (`2000…0002`) | `status=false`; keep row | duplicate, 0 usage | 0/0/0 | High | **Requires approval** |
| `2000…0003` | Soybean Seed | **Soybean** | keep; display rename; aliases Soyabean, Yellow Soybean | most-used soybean record | 1/0/0 | High | **Requires approval** |
| `efbc3e5e` | Soyabean (inactive) | → Soybean | no change (already inactive) | duplicate spelling | 0/0/0 | High | Info |
| `b19c9beb` | Chana (inactive) | **Chickpea (Chana)** | reactivate as canonical instead of creating a new ID | only chana record; avoids a third ID | 0/0/0 | Medium | **Requires approval** |
| `a732266b` | Dal | Requires review | keep active for now; candidate for deactivation | generic term; 22 reqs, all grade "Moisture" + kg, possibly test or default-preselection data | 22/0/0 | Low | **Requires approval** |
| `56809459` | Rice | Rice | keep; assign real grades | valid commodity; its grades are quality attributes | 0/0/0 | Medium | **Requires approval** |
| grade `1f13a047` | Moisture (Dal) | — | keep row (22 reqs); stop offering for new requirements once real grades exist; express moisture as a quality parameter | quality parameter stored as grade | 22 reqs | High | **Requires approval** |
| grade `0c90ef99` | Moisture : 14 (maize) | — | retire with `97ec…` | parameter, 0 usage | 0 | High | **Requires approval** |
| grades `eab13ce7`, `5a7a048d` | Moisture <12%, Whiteness and Translucency (Rice) | — | replace with real rice grades; keep rows | quality attributes, 0 usage | 0 | High | **Requires approval** |
| grade `2100…0003` | Premium Sharbati | Wheat → "Premium Sharbati" | keep unchanged | becomes the variety carrier after the wheat rename | 2/1 | High | Info |
| unit `afd6b4a9` | Tonn (MT) | → Metric Ton | keep row (1 req); hide from selectors (needs a unit status column) | duplicate + misspelling | 1/0/0 | High | **Requires approval** |
| category `1dbe45e5` | maize (inactive, under Agro) | — | leave inactive | a commodity name was created as a category | 0 commodities | High | Info |
| industry `a455dc28` | Agro (inactive) | — | leave inactive | superseded by Agriculture | — | High | Info |

**No merges, ID changes or deletes are proposed.** Historical requirements keep their current `commodity_id`/`grade_id`/`unit_id`.

## 9. Missing products and ambiguous cases

- **Missing:** everything in groups B–J, and most of A and K (see §6, §7).
- **Ambiguous (Requires approval):**
  - Soybean Meal = Soybean DOC?
  - Wheat Middlings = Wheat Pollard?
  - Guar Meal = Guar Korma?
  - Rice Grits vs Broken Rice; Broken Wheat vs Wheat Daliya.
  - Rapeseed Meal vs Mustard DOC.
  - DDGS sources: separate products or grades?
  - High-yield/buffalo/heifer feeds: products or grades of Cattle Feed?
  - Tapioca category.
  - Generic `Dal`.
  - Veterinary-type scope.
  - Placeholder entries: liquid ingredients, yeast products, green/dry fodder, feed premix, pulse chuni.
- **Out of scope as products:** generic placeholders and form descriptors (§7 F/G notes).

## 10. HSN verification requirements and status

- **[Observed]** No HSN fields exist; **0 of 9** existing products have HSN data. **[Proposed]** All ~110 candidate rows start as `Pending verification`; † rows are also `Requires classification review`.
- **No HSN codes are proposed in this document.** None will be shown as approved until verified.
- **Required verification process:**
  1. Classify each product from its exact commercial description and form, against the official CBIC Customs Tariff (First Schedule) and the applicable GST rate notifications, including amendments.
  2. Record the code, the source document or notification number, its effective date, the verification date and the reviewer.
  3. Second reviewer sign-off for † rows.
  4. Re-verify when notifications change.
- **Display rule for the later Buyer UI:** show the code only when status is `verified`; otherwise show "HSN pending verification". Never show a placeholder code.

## 11. Category-read permissions and buyer access findings [Observed]

| Table | RLS | Policies | `anon` grants | `authenticated` grants | Buyer read result | `anon` read result |
|---|---|---|---|---|---|---|
| master_commodities | on | `master_commodities_read` SELECT `true` | SELECT | SELECT (+REFERENCES, TRIGGER, TRUNCATE) | **9 rows (7 active)** | 9 |
| master_grades | on | `master_grades_read` | SELECT | SELECT (+R/T/T) | **8** | 8 |
| master_units | on | `master_units_read` | SELECT | SELECT (+R/T/T) | **4** | 4 |
| master_categories | on | **none** | none | REFERENCES, TRIGGER, TRUNCATE only | **42501 permission denied** | 42501 |
| master_industries | on | **none** | none | REFERENCES, TRIGGER, TRUNCATE only | **42501** | 42501 |
| master_quality_parameters | on | **none** | none | REFERENCES, TRIGGER, TRUNCATE only | **42501** | 42501 |
| Embed commodity→category | — | — | — | — | **42501** | 42501 |

Implications:
- RMBuyer can't group by category, and can't embed `master_categories(name)` without breaking the whole query.
- **[Observed]** The RMBuyer selector live shows 7 active commodities, including both duplicate pairs (maize/Yellow Maize, Wheat/Sharbati Wheat) and generic `Dal`.
- **[Observed, hygiene]** `anon`/`authenticated` hold `TRUNCATE`, `TRIGGER` and `REFERENCES` on master tables (default grants never revoked). PostgREST doesn't expose TRUNCATE, so this isn't reachable through the app API. **[Proposed]** Revoke in a security sprint.
- **[Proposed — Requires approval]** Add `GRANT SELECT` + a SELECT policy (`USING (is_active)` or `true`) on `master_categories` and `master_industries` for `authenticated` (and `anon` if a public catalogue is intended). Writes stay admin-only through the server actions.

## 12. Risks to existing IDs, historical requirements and shared consumers

| Risk | Detail | Mitigation |
|---|---|---|
| Display renames | Renaming `2000…0001/02/03` changes the name shown for historical requirements and deals in RMBroker, RMSeller, RMBuyer and web (all join `master_commodities.name`) | Owner approval; preserve the old name as an alias; announce the change |
| Deactivation | `status=false` hides products from RMBuyer selection (`eq('status', true)`) and from web admin lists; joins for history still resolve | Only deactivate records with 0 transactional usage (`97ec…`, `13a5…`); `Dal` only after review |
| RMBroker master-data | `work_repository.getMasterData()` selects `id, name` **without a status filter**, so the broker form would still offer inactive products | Note for RMBroker owner; no change in this sprint |
| FK-bound rows | Grades, quality parameters, requirements, availabilities and allocations reference commodities, grades and units | Never delete; never move transactional references |
| Duplicate unit | `Tonn` used by 1 requirement | Hide (needs a status column); keep the row |
| Drizzle drift | New columns must be added to `src/server/db/schema.ts` as well | Same change set |
| Name uniqueness | A unique index would fail today (maize/Maize style conflicts depending on normalisation) | Create only after deactivation; scope it to active rows |
| RMBuyer fallbacks | Hardcoded IDs `2000…04/05` don't exist live | Replace in the implementation sprint (not now) |

## 13. Proposed schema additions (not implemented) [Proposed — Requires approval]

| Table | Addition | Purpose |
|---|---|---|
| master_commodities | `name_hi text`, `aliases text[] not null default '{}'`, `commodity_type text` (check list §7.1), `description text`, `default_unit_id uuid → master_units` | names, search, type, units |
| master_commodities | `hsn_code text null`, `hsn_status text not null default 'pending_verification'` (check: `pending_verification`, `requires_review`, `verified`, `not_applicable`), `hsn_source text`, `hsn_effective_date date`, `hsn_verified_at timestamptz`, `hsn_verified_by uuid → users` | auditable HSN classification; CHECK: `hsn_code` required when `verified` |
| master_commodities | `created_at`, `updated_at timestamptz default now()` | conventions |
| master_commodities | partial unique index on `lower(btrim(name)) where status` (after cleanup) | prevent new duplicates |
| master_units | `status boolean not null default true`, `kind text` (mass/volume/count/package), `kg_factor numeric null` (null for bag/bale) | hide duplicates; bag/bale weight stays lot-level |
| new `master_commodity_units` | `(commodity_id, unit_id)` PK + `is_default` | supported units per product |
| master_grades | optional `status boolean default true` | retire parameter-like grades without deleting |
| master_categories / master_industries | GRANT SELECT + SELECT policy | buyer category grouping |
| Drizzle `schema.ts` | mirror all of the above | avoid drift |

No subcategory/parent schema.

## 14. Recommended safe, repeatable seed strategy (not run) [Proposed]

1. **Pre-flight diff (read-only):** a script compares the approved catalogue file with live rows and prints the inserts and updates it would make. The owner reviews the output.
2. **Stable IDs:** every new industry, category, commodity, grade and unit gets a pre-assigned UUID committed in the seed file (or a UUIDv5 from a fixed namespace + canonical key). Re-runs are therefore deterministic.
3. **Inserts:** `INSERT … ON CONFLICT (id) DO NOTHING`.
4. **Updates to existing rows** (renames, category assignment, deactivation): explicit statements guarded by expected current values, e.g. `UPDATE … SET … WHERE id = $1 AND name = 'Sharbati Wheat'`. A drifted row isn't touched and is reported.
5. **No DELETE statements.** No updates to `requirements`, `availabilities`, `deals` or `allocations`.
6. **Atomicity:** run in a single transaction; assert pre/post counts; a paired rollback script restores the previous names and statuses.
7. **HSN:** the seed sets `hsn_status = 'pending_verification'` only. Verified codes are applied later in a separate, evidence-referenced change.
8. **Order:** run on staging or a DB branch first, then production with explicit approval.

## 15. Questions and decisions requiring owner approval

1. Approve the canonical records and display renames: `2000…0001` → "Maize (Corn)", `2000…0002` → "Wheat", `2000…0003` → "Soybean".
2. Approve deactivating duplicates `97eccc57` (maize) and `13a5208a` (Wheat), and reactivating `b19c9beb` as Chickpea (Chana).
3. **Dal** (22 requirements): are these test records or real? Keep, reclassify, or deactivate for new use?
4. Create the new industry "Animal Nutrition & Feed" (or put all categories under Agriculture)?
5. Is the veterinary-type category in scope?
6. Ambiguous pairs in §9: same product or separate?
7. DDGS by source: separate products (proposed) or grades?
8. Finished feeds: forms (mash/pellet/nugget) as grades (proposed); segments as products or grades?
9. Should categories be readable by `anon` (public catalogue) or by `authenticated` only?
10. Who verifies HSN, and which CBIC tariff/notification versions are authoritative?
11. Should Hindi (Devanagari) names come from a provided source, or need a reviewer?
12. Approve the schema additions in §13 for the next sprint (BUYER-PRODUCT-MASTER-03)?

## 16. Actions deliberately not performed

- No INSERT, UPDATE, DELETE, UPSERT, DDL, migration, seed, policy, grant or RLS change (all sessions were `READ ONLY`).
- No mutating RPC calls; no RPC calls at all.
- No HSN columns or codes added.
- No application code changes in RMBuyer, RMBroker, RMSeller or web.
- No product-picker, navigation or fallback changes.
- No fixes to the unrelated requirement, company, payment, packaging, notes or cancel defects.
- No secrets printed or written; no buyer PII recorded (buyer identity anonymised; only role and usage counts).
- No commit or push. The next sprint was not started.
