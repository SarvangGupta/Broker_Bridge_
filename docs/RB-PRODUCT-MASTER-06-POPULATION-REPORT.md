# RB-PRODUCT-MASTER-06 — Raw-Material Catalogue Population Report

**Date:** 2026-10-24 · **Branch:** `feature/broker-nilesh` (no app code changed; nothing committed or pushed)
**Outcome:** ✅ **Committed** in one guarded transaction: **txid 5168**, 2026-10-24 14:54:22–14:54:25 UTC, `application_name = 'PM-06 catalogue population'`.
- **Added:** 6 categories, 52 products and 52 product-specific grades.
- **Checks:** independent post-write verification passed **16/16**, and an idempotency re-run was a no-op.
- **⚠ Open blocker (RMBroker):** see §8.

**Owner decisions taken in this sprint (2026-10-24):**
1. **Approved:** the single grade **"FAQ (Fair Average Quality)"** per new product. This is PM-04 §5's documented initial grade, which was pending approval until now.
2. **Held:** Chana reactivation.

---

## 1. Original catalogue scope recovered

**Source:** [PM-04 §5](BUYER-PRODUCT-MASTER-04-IMPLEMENTATION-PLAN.md) (derived from the [02 proposal §7](BUYER-PRODUCT-MASTER-02-CATALOGUE-PROPOSAL.md) and the [03 decision review](BUYER-PRODUCT-MASTER-03-DECISION-REVIEW.md)). It lists 6 new categories, **52 new commodities** and 52 grades. Names were used exactly as documented, with no aliases, Hindi names, HSN codes or product codes, because those columns don't exist or aren't approved.

| Category | Products (52) |
|---|---|
| Grains & Cereals (existing `a3b89ba6`) | Paddy · Broken Rice · Bajra (Pearl Millet) · Jowar (Sorghum) · Barley · Oats |
| Oilseeds (existing `fe59c01d`, PM-05) | Mustard Seed · Whole Cottonseed · Groundnut Kernels · Sunflower Seed · Sesame Seed · Linseed |
| **Pulses** (new) | Peas · Lentil · Moong (Green Gram) · Urad (Black Gram) |
| **Oil Cakes & Meals** (new) | Mustard Cake (Expeller) · Mustard De-oiled Cake (DOC) · Cottonseed Cake · Cottonseed DOC · Groundnut Cake · Sesame Cake · Linseed Cake · Sunflower Meal · Coconut Cake · Palm Kernel Cake · Safflower Cake · Maize Germ Cake |
| **Bran & Milling By-products** (new) | Rice Bran · Rice Polish · De-oiled Rice Bran (DORB) · Wheat Bran · Maize Bran · Maize Gluten Feed · Maize Gluten Meal · Maize Germ |
| **Protein & Agri By-products** (new) | Guar Churi · Chana Churi · Moong Chuni · Urad Chuni |
| **Molasses & Liquid Feed Ingredients** (new) | Sugarcane Molasses · Beet Molasses |
| **Fodder & Roughage** (new) | Wheat Straw · Paddy Straw · Bajra Kadbi · Jowar Kadbi · Maize Stover · Lucerne Hay · Berseem Hay · Oat Hay · Maize Silage · Sorghum Silage |

All new categories sit under **Agriculture** (`d82dbe9c`), per decision D8 (no new industry).

## 2. Reconciliation against production (read-only, before writing)

- **Baseline matched the PM-05 post-state exactly:**
  - 9 commodities (5 active), 3 categories, 8 grades, 4 units;
  - 29 requirements, 3 availabilities, 9 deals.
- **Exact matches** (case-, punctuation- and space-insensitive): **0 of 52**. **Category matches:** 0 of 6.
- **Near matches, all judged materially different and *not* reused or merged:**

| Proposed | Near match in production | Decision |
|---|---|---|
| Broken Rice, Rice Bran, Rice Polish, De-oiled Rice Bran (DORB) | `56809459` Rice (active) | different products (grain vs milling by-products) → **add** |
| Wheat Bran, Wheat Straw | `13a5208a` Wheat (inactive duplicate) | by-product / roughage ≠ grain; duplicate stays inactive → **add** |
| Maize Bran, Maize Germ, Maize Germ Cake, Maize Gluten Feed, Maize Gluten Meal, Maize Stover, Maize Silage | `97eccc57` maize (inactive duplicate) | distinct by-products / roughage → **add**; duplicate not recreated |
| Chana Churi | `b19c9beb` Chana (inactive) | by-product ≠ whole pulse → **add**; Chana untouched |

- **Reused records:** none applicable. The PM-05 canonical records (Yellow Maize (Corn), Sharbati Wheat, Soybean Seed) are not in the 52-list and were left unchanged.
- **Schema facts that shaped the write:**
  - no unique constraints on names, so idempotency comes from fixed IDs plus guards;
  - `code`, `category_id` and `parameters` are nullable;
  - no triggers on the master tables.

## 3. Created records and ID convention

- **IDs:** deterministic **UUIDv5**, per the 02 proposal §14 (pre-assigned stable IDs). Each ID is derived from the namespace `3d025cc2-ebda-570d-8816-976f5f038c9e` (itself UUIDv5 of `https://rmbroker.app/product-master/v1` under the URL namespace) plus the key `category:<name>`, `commodity:<name>` or `grade:<name>:FAQ (Fair Average Quality)`. A re-run therefore targets the same IDs. The full ID list (6 + 52 + 52) is in the session result file `pm06_apply_result.json`.
- **Products:** `status = true`, `code = NULL` (no codes invented), `category_id` as in §1.
- **Grades:** exactly one per product, `grade_name = 'FAQ (Fair Average Quality)'`, `commodity_id` = that product, `parameters = NULL` (no specs invented).

Sample IDs (as verified over REST):

| Product | Product ID | Grade ID |
|---|---|---|
| Wheat Bran | `8f58c547-e988-5843-954a-6e0e57ae6b44` | `5dcb586c-632a-50c0-b097-a33efae04a20` |
| De-oiled Rice Bran (DORB) | `c5882ee5-29c8-5983-a24c-848222e7f259` | `add32e4f-14b2-528e-be9b-8bed0516c554` |
| Sugarcane Molasses | `7ee21d3d-e0e0-5639-9942-a4b4ba970eff` | `576c12d1-b43f-5775-9691-f0974811b13d` |
| Lucerne Hay | `f9cddcd6-9178-5c78-bfe9-94b4a1af946d` | `f292a722-6336-557a-9587-965b50007178` |

## 4. Products still held (not written), with reasons

| Item(s) | Reason held (from 03 / PM-04 §6) |
|---|---|
| **Chickpea / Chana** reactivation (`b19c9beb`) | **Owner chose to keep it held** (this sprint). The canonical name "Chickpea (Chana)" and Desi/Kabuli grades depend on the rename/alias work (D2–D4, D6) |
| Soybean Meal vs Soybean DOC | D7: one product or two? |
| Wheat Middlings / Pollard | D7: needs trader confirmation |
| Rice / Maize / Wheat DDGS; Brewers' Dried Grains (BDG) | D7: separate products vs grades (DDGS ≠ BDG; not merged) |
| Guar Meal (Korma), Rapeseed Meal, Rice Grits, Maize/Wheat Daliya, Broken Wheat, Pulse Chuni, Feed-grade Tapioca | D7 / scope review |
| Minerals (limestone, DCP, MCP, salt, bicarbonate, MgO, MgSO₄, mineral mixtures) | classification review + D7 |
| Vitamins, premixes, bypass protein/fat, yeast, probiotics, enzymes, toxin binders, buffers, anionic/transition premixes | compliance + classification review |
| Finished cattle feeds (and pellet/mash/nugget forms) | D7 product-vs-grade + classification review |
| **Veterinary-type:** calcium bolus, oral calcium, electrolytes | **D7b regulatory review; excluded from trading** |
| Renames (Maize (Corn), Wheat, Soybean), aliases, Hindi names | need the Batch 2 schema (no `aliases` / `name_hi` columns) + D2–D4 + Hindi reviewer |
| Real grades for Rice and the 52 new products | the FAQ grade is the approved interim baseline; product-specific grades need owner-supplied specs |
| Units: duplicate `Tonn`; bag, bale, litre | Batch 2 schema (unit status/kind) |
| Dal (22 requirements) | D1 provenance decision |
| HSN codes | CBIC/GST verification workflow (03 §8.1) |

## 5. Before / after counts

| Table | Before | After |
|---|---|---|
| master_categories | 3 | **9** |
| master_commodities (total / active) | 9 / 5 | **61 / 57** |
| master_grades | 8 | **60** |
| master_units / master_industries | 4 / 2 | 4 / 2 (unchanged) |
| requirements / availabilities / deals | 29 / 3 / 9 | 29 / 3 / 9 (unchanged) |
| deal_versions / negotiation_events | 9 / 2 | 9 / 2 (unchanged) |

## 6. Transaction safeguards and results

**Script:** `pm06_apply.mjs`, kept in the session scratchpad outside the repo. It used `postgres.js` `sql.begin()` (one `BEGIN … COMMIT`; any throw rolls back) as role `postgres` against database `postgres` on the project's `DATABASE_URL`. The connection string was never printed.

1. `lock_timeout 5s`, `statement_timeout 60s`. `LOCK … IN SHARE ROW EXCLUSIVE MODE` on categories, commodities and grades, which blocks concurrent catalogue writes but not reads.
2. **Idempotency:** if all 110 target IDs exist → no-op. If only some exist → abort.
3. **Preconditions:**
   - baseline counts 9 / 5 active / 3 / 8;
   - PM-05 state: the 3 canonical products active and categorised; `maize`, `Wheat` and `Chana` inactive;
   - parent categories active under an active Agriculture industry.
4. **Duplicate guards:** no existing category or commodity (active *or* inactive) with the same normalized name.
5. **Exact insert counts:** 6 / 52 / 52 (`ON CONFLICT (id) DO NOTHING … RETURNING`).
6. **In-transaction post-conditions:**
   - 61 / 57 / 9 / 60;
   - each new product active, in its planned category under Agriculture, with exactly 1 grade owned by it;
   - no duplicate active names.
7. **Fingerprints, before vs after, all identical:** md5 of the pre-existing commodities, categories, grades, units and industries; md5 of requirements and availabilities (`id + commodity + grade + unit`); counts of deals, deal_versions and negotiation_events.

| Run | Result |
|---|---|
| Dry run (txid 5167, forced rollback) | `DRY_RUN_OK`: every guard passed; all fingerprints identical |
| **Apply (txid 5168)** | **`COMMITTED`**: inserted 6 / 52 / 52; post-counts 61 / 57 / 9 / 60; all fingerprints identical |
| Re-run after commit | `ALREADY_APPLIED_NOOP` (no writes) |

## 7. Post-write verification (new read-only session): 16/16 PASS

`pm06_verify.mjs`: every query ran in `BEGIN READ ONLY`. App roles were simulated with `SET LOCAL ROLE` + JWT claims of an existing user of that role.

| Check | Result |
|---|---|
| Counts 61 / 57 active / 9 categories / 60 grades; transactions 29 / 3 / 9 | PASS |
| 6 categories present, active, under Agriculture | PASS |
| 52 products: active, exact name and category, exactly 1 own grade with the planned ID | PASS |
| No duplicate commodity or category names (normalized, all rows) | PASS |
| PM-05 state intact (canonical 3 active and categorised; maize / Wheat / Chana / Soyabean inactive) | PASS |
| Historical references + pre-existing master rows byte-identical to the pre-write snapshot | PASS |
| **RMBuyer** path (authenticated buyer): `status=true` list = 57 incl. all 52; each grade readable by `commodity_id` | PASS |
| **RMSeller** path (authenticated seller): same queries | PASS |
| anon: same queries | PASS |
| **RMBroker** fallback path (authenticated broker): all commodities + all grades include the 52 and their grades | PASS |

## 8. App-level verification and blockers

| App | Verified | Not verified / blocker |
|---|---|---|
| **RMBuyer** | ✔ The exact REST request of the shipped picker (`…/master_commodities?select=id,name,code,status&status=eq.true&order=name.asc.nullslast`, public anon key) returns **57** rows in alphabetical order. ✔ The grade request sent after selection (`master_grades?commodity_id=eq.<id>`) returns that product's own FAQ grade for Wheat Bran, DORB, Sugarcane Molasses and Lucerne Hay. ✔ ID preservation into the payload is covered by the PICKER-FIX-01 widget tests (selected `MasterCommodity.id` → `CreateRequirementDto.commodityId` → `requirements.commodity_id`; grade must belong to the product). | Not clicked through on the phone; it was being operated by hand during the previous sprint. No requirement was submitted (as instructed). |
| **RMSeller** | ✔ Its query (`status = true`; grades filtered by `commodity_id`) returns all 52 with own grades under the seller role. | Not exercised in the app UI. Note: `order('name')` without `ascending: true` lists Z→A, and on failure it shows a hardcoded fallback list (both pre-existing; not changed here). |
| **RMBroker** | ✔ Its actual path is the Supabase fallback of `getMasterData()`; the `/broker/master-data` API route does not exist in `src/app/api`. The 52 products and their grades are returned. | **⚠ Blocker, KI-43 (S1):** the create-requirement and create-offer sheets list **all 60 grades unfiltered by commodity**, and 53 of them are now named "FAQ (Fair Average Quality)". A broker can therefore pick another product's grade, and nothing in the DB ties `grade_id` to `commodity_id`. The unfiltered grade list predates this sprint, but the catalogue makes it much easier to hit. RMBroker also still lists inactive commodities. **Fix needs an RMBroker code change** (filter commodities by `status` and grades by the selected `commodity_id`), which is out of scope for this data sprint. |

**I did not claim visibility in all three apps beyond what is listed above.**

## 9. Remaining blockers and recommended next steps

1. **RMBroker grade filtering (KI-43)**, before brokers create requirements or offers for the new products.
2. Product-specific grade specs to replace or supplement the interim FAQ grade. FAQ grades become undeletable once requirements reference them; add new grades alongside instead.
3. The held items in §4, released per decision (D2–D4, D6, D7, D7b, D10).
4. `authenticated` still has no SELECT on `master_categories`, so RMBuyer can't group the 57 products by category (security change, separate approval).

## 10. Not changed

- No schema, RLS, grant, auth or policy change.
- No updates or deletes of existing rows; no renames.
- No requirements, offers, deals or negotiations created.
- No app code changed (only this report and a KI-43 entry in `KNOWN-ISSUES-AND-DECISIONS.md`).
- No commit or push.

**Rollback (prepared, not executed; only for an approved reversal, and only while unreferenced):**
```sql
BEGIN;
-- abort if any new grade/product is referenced
DELETE FROM public.master_grades     WHERE id = ANY(:grade_ids)     AND NOT EXISTS (SELECT 1 FROM public.requirements r WHERE r.grade_id = master_grades.id)
                                                                    AND NOT EXISTS (SELECT 1 FROM public.availabilities a WHERE a.grade_id = master_grades.id);
DELETE FROM public.master_commodities WHERE id = ANY(:commodity_ids) AND NOT EXISTS (SELECT 1 FROM public.master_grades g WHERE g.commodity_id = master_commodities.id)
                                                                    AND NOT EXISTS (SELECT 1 FROM public.requirements r WHERE r.commodity_id = master_commodities.id)
                                                                    AND NOT EXISTS (SELECT 1 FROM public.availabilities a WHERE a.commodity_id = master_commodities.id);
DELETE FROM public.master_categories  WHERE id = ANY(:category_ids)  AND NOT EXISTS (SELECT 1 FROM public.master_commodities c WHERE c.category_id = master_categories.id);
COMMIT;
```
Once any new product is used, prefer `status = false` over deletion.
