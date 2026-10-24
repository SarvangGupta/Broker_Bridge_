# BUYER-PRODUCT-MASTER-04 — Catalogue Implementation Plan (PM-04)

**Sprint:** PM-04 · **Date:** 2026-10-24 · **Branch / HEAD:** `feature/broker-nilesh` @ `390fd84`
**Inputs:** [01 audit](BUYER-PRODUCT-MASTER-01-AUDIT.md) · [02 proposal](BUYER-PRODUCT-MASTER-02-CATALOGUE-PROPOSAL.md) · [03 decision review](BUYER-PRODUCT-MASTER-03-DECISION-REVIEW.md)
**Status:** **Plan only. No catalogue writes were made.** Every batch below needs explicit owner approval before execution.

**Labels:** **[Observed]** live DB / repo · **[Proposed]** · **[Pending]** blocked on a decision, schema or verification.

---

## 0. Decision basis

- **No owner decisions from the 03 checklist (D1–D11) have been recorded.** Nothing in this plan is treated as already approved.
- Changes are grouped into batches, ordered by risk. Each batch states the criteria it depends on.
- Hierarchy kept: **Industry → Category → Commodity → Grade**. **No new industry**: 03 §6 found no consumer that needs one; everything goes under the existing `Agriculture` (`d82dbe9c`).
- **Preserved:** all existing IDs, requirements, availabilities, quotations, deal versions, negotiation events and deals. **No DELETE** anywhere.
- **HSN:** no column exists **[Observed]**. No HSN is stored or displayed in any batch here. All products stay *pending official verification* (03 §8.1).
- **Out of scope:** auth, RLS, grants and security policies. Note that buyers **cannot read `master_categories`** today (SEC-PRIV-01 §5). Category assignment still helps the web cascade, but the RMBuyer grouped picker stays blocked until a separately approved grant + policy.

## 1. Live baseline (re-validated read-only, 2026-10-24) [Observed]

Unchanged since BUYER-PRODUCT-MASTER-02/03: 9 commodities (7 active), 8 grades, 4 units, 2 categories, 2 industries, 1 quality parameter. Transactional rows: 29 requirements, 3 availabilities, 9 deals.

Foreign keys into the master tables (from `pg_constraint`):

| Target | Referencing columns |
|---|---|
| master_commodities | `requirements.commodity_id`, `availabilities.commodity_id`, `master_grades.commodity_id`, `master_quality_parameters.commodity_id` |
| master_grades | `requirements.grade_id`, `availabilities.grade_id` |
| master_units | `requirements.unit_id`, `availabilities.unit_id`, `requirement_allocations.unit_id` |
| master_categories | `master_commodities.category_id` |
| master_industries | `master_categories.industry_id` |
| master_quality_parameters | `requirement_quality_specs`, `availability_quality_values`, `lab_test_results` (`parameter_id`) |

Deals reach commodities only through `deals.requirement_id → requirements`.

**Consumer filters:**

| Consumer | Status filtering |
|---|---|
| RMBuyer, RMSeller | `master_commodities.status = true` |
| Web (`master-data-actions.ts`) | commodities `status = true`; categories and industries `is_active = true`; grades and units unfiltered |
| **RMBroker** `getMasterData()` | **no status filter** on commodities and **no commodity filter** on grades |

## 2. Existing products to retain [Observed + Proposed]

| ID | Current name | Status | Category | Grades | Refs (req / avail / deals) | Plan |
|---|---|---|---|---|---|---|
| `20000000-…0001` | Yellow Maize (Corn) | active | **none** | Grade A Milling, Feed Grade Premium | 4 / 2 / 7 | **retain as canonical maize**; Batch 1 assigns category; rename pending (§3) |
| `20000000-…0002` | Sharbati Wheat | active | **none** | Premium Sharbati | 2 / 1 / 2 | **retain as canonical wheat**; Batch 1 assigns category; rename pending |
| `20000000-…0003` | Soybean Seed | active | **none** | Standard Mandi Grade | 1 / 0 / 0 | **retain as canonical soybean**; Batch 1 assigns the new Oilseeds category; rename pending |
| `56809459` | Rice | active | Grains & Cereals | Moisture <12%, Whiteness and Translucency (quality attributes, not grades) | 0 / 0 / 0 | retain; real grades **[Pending]** |
| `a732266b` | Dal | active | Grains & Cereals | Moisture (22 req) | 22 / 0 / 0 | retain unchanged; disposition **[Pending D1]** (test-data review) |
| `b19c9beb` | Chana | inactive | none | none | 0 | retain inactive; reactivation **[Pending]** (needs category + grade; 03 §4) |
| `efbc3e5e` | Soyabean | inactive | none | none | 0 | retain inactive, untouched (identity with Soybean Seed unverified) |
| `97eccc57` | maize | active | Grains & Cereals | Moisture : 14 | 0 / 0 / 0 | **deactivate (Batch 1)** |
| `13a5208a` | Wheat | active | Grains & Cereals | none | 0 / 0 / 0 | **deactivate (Batch 1)** |

## 3. Renames and aliases [Pending]

| Record | Proposed display name | Blocking criterion |
|---|---|---|
| `20000000-…0001` | Maize (Corn) | the alias "Yellow Maize" must be stored first (no `aliases` column), and you must decide whether "Yellow" stays as a variety (D2) |
| `20000000-…0002` | Wheat | D3 approval. List views would show "Wheat" without "Sharbati"; 13a5 must be deactivated in the same transaction (Batch 1 does this) |
| `20000000-…0003` | Soybean | D4 approval; "Soyabean" to be stored as a search alias only |

- **Aliases and Hindi names:** **not storable** (no `aliases` / `name_hi` columns).
- **Proposal:** keep every rename out of production until the schema batch (§8, Batch 2) adds `aliases`. An unaliased rename would make the old name unsearchable and change historical display in all 4 apps.

## 4. Batch 1: category assignment and duplicate deactivation (data-only, existing columns)

**Approval needed:** D5 (deactivations), plus confirming the new category name "Oilseeds".

| # | Change | Reference check (live, 2026-10-24) | Visible effect |
|---|---|---|---|
| 1.1 | Create category **Oilseeds** (`fe59c01d-228e-47a8-854a-e0803cdadfa4`) under Agriculture, active | n/a (new) | web cascade gains the "Oilseeds" category (with 1 commodity) |
| 1.2 | `20000000-…0001` Yellow Maize (Corn): `category_id` → Grains & Cereals (`a3b89ba6`) | category currently NULL | now reachable in the web Industry → Category → Commodity form |
| 1.3 | `20000000-…0002` Sharbati Wheat: `category_id` → Grains & Cereals | currently NULL | same |
| 1.4 | `20000000-…0003` Soybean Seed: `category_id` → Oilseeds | currently NULL | same |
| 1.5 | `97eccc57` maize: `status = false` | 0 req, 0 avail, 0 deals; FK only from its own grade `0c90ef99` (0 refs) and quality param `19cfed1b` (0 refs in specs, values, lab results) | removed from RMBuyer, RMSeller and web selectors; **still listed in RMBroker** (no status filter) |
| 1.6 | `13a5208a` Wheat: `status = false` | 0 refs of any kind; no grades | same |

**Not changed by Batch 1:** names, codes, grades, units, requirements and history. RMBuyer's default first commodity stays **Dal**: active order after Batch 1 is Dal, Rice, Sharbati Wheat, Soybean Seed, Yellow Maize (Corn). That default-preselection defect is fixed in the picker sprint, not by data.

## 5. New products and category assignments (Batch 3) [Proposed]

Criteria to go live:
1. Owner approves this list.
2. Each product gets **≥1 grade**, because RMBuyer falls back to a non-existent grade ID otherwise (03 §4).
3. HSN stays pending (nothing stored).

**Initial grade proposal:** a single grade **"FAQ (Fair Average Quality)"** per new product, the standard mandi baseline term, until real grade specs are supplied. **[Pending owner approval of this default.]**

**Units:** there's no product-to-unit mapping yet. All units appear for every product. "Units" below documents the intended unit set for a later `master_commodity_units` table. Only **MT, Qtl, kg** exist today; bag, bale and litre are **[Pending]** (§7).

**New categories (all under Agriculture):** Pulses · Oil Cakes & Meals · Bran & Milling By-products · Protein & Agri By-products · Molasses & Liquid Feed Ingredients · Fodder & Roughage. That's 6, plus Oilseeds from Batch 1.

| Category | New commodity (canonical EN) | Initial grade | Intended units |
|---|---|---|---|
| Grains & Cereals (existing) | Paddy · Broken Rice · Bajra (Pearl Millet) · Jowar (Sorghum) · Barley · Oats | FAQ | MT, Qtl |
| Oilseeds (Batch 1) | Mustard Seed · Whole Cottonseed · Groundnut Kernels · Sunflower Seed · Sesame Seed · Linseed | FAQ | MT, Qtl |
| Pulses | Peas · Lentil · Moong (Green Gram) · Urad (Black Gram) | FAQ | MT, Qtl |
| Oil Cakes & Meals | Mustard Cake (Expeller) · Mustard De-oiled Cake (DOC) · Cottonseed Cake · Cottonseed DOC · Groundnut Cake · Sesame Cake · Linseed Cake · Sunflower Meal · Coconut Cake · Palm Kernel Cake · Safflower Cake · Maize Germ Cake | FAQ | MT, Qtl |
| Bran & Milling By-products | Rice Bran · Rice Polish · De-oiled Rice Bran (DORB) · Wheat Bran · Maize Bran · Maize Gluten Feed · Maize Gluten Meal · Maize Germ | FAQ | MT, Qtl |
| Protein & Agri By-products | Guar Churi · Chana Churi · Moong Chuni · Urad Chuni | FAQ | MT, Qtl |
| Molasses & Liquid Feed Ingredients | Sugarcane Molasses · Beet Molasses | FAQ | MT (litre pending) |
| Fodder & Roughage | Wheat Straw · Paddy Straw · Bajra Kadbi · Jowar Kadbi · Maize Stover · Lucerne Hay · Berseem Hay · Oat Hay · Maize Silage · Sorghum Silage | FAQ | MT, Qtl (bale pending) |

**Total: 6 new categories, 52 new commodities, 52 grades.** No aliases, Hindi names or HSN are stored. Names are the canonical English names from 03 §7, without regional aliases (aliases wait for Batch 2).

## 6. Deliberately held out of the live catalogue [Pending], with the criterion to release each

| Item(s) | Release criterion |
|---|---|
| Soybean Meal vs Soybean DOC | D7: confirm one product |
| Wheat Middlings / Pollard | D7: trader confirmation |
| Rice / Maize / Wheat DDGS; Brewers' Dried Grains | D7: separate products vs grades |
| Guar Meal (Korma); Rapeseed Meal; Rice Grits; Maize/Wheat Daliya; Broken Wheat; Pulse Chuni; Feed-grade Tapioca | D7 / scope review |
| Minerals (limestone, DCP, MCP, salt, bicarbonate, MgO, MgSO₄, mineral mixtures, premixes) | classification review (†) + D7 |
| Vitamins, premixes, bypass protein/fat, yeast, probiotics, enzymes, toxin binders, buffers, anionic/transition premixes | compliance + classification review (†) |
| Finished cattle feeds (incl. pellet/mash/nugget forms) | D7 product-vs-grade decision + classification review (†) |
| **Veterinary-type:** calcium bolus, oral calcium, electrolytes | **D7b regulatory review**; excluded from trading until approved |
| Chickpea (reactivate `b19c9beb`) | category + real grade approved (falls inside Batch 3 once approved) |
| Renames, aliases, Hindi names | Batch 2 schema + D2–D4 + Hindi reviewer (03 §8.2) |
| Rice real grades | owner supplies grade names |
| `Tonn` duplicate unit; bag, bale, litre units | Batch 2 adds unit status and kind; bag/bale weight is defined per lot |
| Dal (22 requirements) | D1 provenance decision |
| All HSN codes | official CBIC/GST verification workflow (03 §8.1) |

## 7. Exact SQL for Batch 1 (prepared, **not executed**)

The script runs in one transaction. Guards abort if the live state differs from what was validated. There are no deletes. To be run only after approval, ideally first through the web admin or on a staging copy.

```sql
BEGIN;

-- Guards: abort if live state drifted from the validated baseline
DO $$
BEGIN
  IF (SELECT count(*) FROM public.master_commodities WHERE
        (id = '20000000-0000-0000-0000-000000000001' AND name = 'Yellow Maize (Corn)' AND category_id IS NULL AND status) OR
        (id = '20000000-0000-0000-0000-000000000002' AND name = 'Sharbati Wheat'      AND category_id IS NULL AND status) OR
        (id = '20000000-0000-0000-0000-000000000003' AND name = 'Soybean Seed'        AND category_id IS NULL AND status) OR
        (id = '97eccc57-7e80-435b-a51d-32700a727804' AND name = 'maize' AND status) OR
        (id = '13a5208a-7bcd-48b8-adc8-6c0f0a136c13' AND name = 'Wheat' AND status)) <> 5
  THEN RAISE EXCEPTION 'PM-04 Batch 1: commodity baseline drifted'; END IF;

  IF EXISTS (SELECT 1 FROM public.requirements   WHERE commodity_id IN ('97eccc57-7e80-435b-a51d-32700a727804','13a5208a-7bcd-48b8-adc8-6c0f0a136c13'))
  OR EXISTS (SELECT 1 FROM public.availabilities WHERE commodity_id IN ('97eccc57-7e80-435b-a51d-32700a727804','13a5208a-7bcd-48b8-adc8-6c0f0a136c13'))
  THEN RAISE EXCEPTION 'PM-04 Batch 1: duplicate now referenced by transactions'; END IF;

  IF EXISTS (SELECT 1 FROM public.master_categories WHERE lower(btrim(name)) = 'oilseeds')
  THEN RAISE EXCEPTION 'PM-04 Batch 1: Oilseeds category already exists'; END IF;
END $$;

INSERT INTO public.master_categories (id, industry_id, name, is_active)
VALUES ('fe59c01d-228e-47a8-854a-e0803cdadfa4', 'd82dbe9c-6780-4c95-9cf2-0ed19680a0e7', 'Oilseeds', true)
ON CONFLICT (id) DO NOTHING;

UPDATE public.master_commodities SET category_id = 'a3b89ba6-fc77-4db6-ba32-25d833bf29ee'
 WHERE id IN ('20000000-0000-0000-0000-000000000001', '20000000-0000-0000-0000-000000000002') AND category_id IS NULL;
UPDATE public.master_commodities SET category_id = 'fe59c01d-228e-47a8-854a-e0803cdadfa4'
 WHERE id = '20000000-0000-0000-0000-000000000003' AND category_id IS NULL;
UPDATE public.master_commodities SET status = false
 WHERE id IN ('97eccc57-7e80-435b-a51d-32700a727804', '13a5208a-7bcd-48b8-adc8-6c0f0a136c13') AND status;

-- Post-condition: exactly the intended state
DO $$
BEGIN
  IF (SELECT count(*) FROM public.master_commodities WHERE status) <> 5
  THEN RAISE EXCEPTION 'PM-04 Batch 1: unexpected active commodity count'; END IF;
END $$;

COMMIT;
```

**Rollback (prepared, not executed):**
```sql
BEGIN;
UPDATE public.master_commodities SET status = true
 WHERE id IN ('97eccc57-7e80-435b-a51d-32700a727804', '13a5208a-7bcd-48b8-adc8-6c0f0a136c13');
UPDATE public.master_commodities SET category_id = NULL
 WHERE id IN ('20000000-0000-0000-0000-000000000001', '20000000-0000-0000-0000-000000000002', '20000000-0000-0000-0000-000000000003');
DELETE FROM public.master_categories                      -- only the category this batch created,
 WHERE id = 'fe59c01d-228e-47a8-854a-e0803cdadfa4'          -- and only if nothing references it
   AND NOT EXISTS (SELECT 1 FROM public.master_commodities WHERE category_id = 'fe59c01d-228e-47a8-854a-e0803cdadfa4');
COMMIT;
```

**Post-execution verification (read-only):**
- 5 active commodities;
- 3 seeded records carry categories;
- requirements, availabilities and deals counts unchanged (29 / 3 / 9);
- RMBuyer and RMSeller selectors show 5 products; the web cascade reaches maize, wheat and soybean.

## 8. Implementation batches and order

| Batch | Content | Type | Depends on |
|---|---|---|---|
| **1 (PM-05)** | §4 / §7: 1 category, 3 category assignments, 2 deactivations | data, 6 rows | owner approval (D5, category name) |
| 2 (PM-06) | Additive schema: `master_commodities.aliases`, `name_hi`, `commodity_type`, HSN fields (`hsn_status` default `pending_verification`); `master_units.status` / `kind`; optional `master_commodity_units`; Drizzle `schema.ts` sync | migration | owner approval; staging run |
| 2b | Renames with aliases (D2–D4); hide `Tonn` | data | Batch 2 + decisions |
| 3 (PM-07) | §5: 6 categories, 52 commodities, 52 FAQ grades; Chickpea reactivation | data (idempotent seed, fixed UUIDs, `ON CONFLICT DO NOTHING`, guarded) | list + default-grade approval |
| 4 | RMBuyer picker (no default preselection, ID prefill, fallbacks removed) | app code | category read grant (separate security approval) |
| 5+ | Held items (§6) in small batches as their criteria are met; HSN verification batches | data | per item |

## 9. Safe, isolated changes made in PM-04

**None.** No database writes, schema changes or app-code changes. All database access was read-only (`transaction_read_only = on`). No tests were run; none were needed for a planning sprint. The only new file is this plan.

## 10. Blocked by a missing decision or access

| Blocker | Blocks |
|---|---|
| Owner approval of Batch 1 (D5 + "Oilseeds") | PM-05 |
| D2–D4 rename decisions + alias storage (Batch 2 migration) | all renames |
| Approval of the Batch 3 list and the default "FAQ" grade | new products |
| D7 / D7b identity and regulatory decisions | items in §6 |
| Category SELECT grant + policy for `authenticated` (security change, out of scope) | RMBuyer grouped picker |
| HSN reviewer and sources (D10) | any HSN data |
| No staging / branch database | dry-runs of Batches 1–3 (currently only guarded production execution is possible) |
| RMBroker `getMasterData()` lacks status/commodity filters (RMBroker code, out of scope) | deactivated duplicates still appear in RMBroker |

## 11. Next smallest implementation sprint

**PM-05: execute Batch 1** (6 row changes) after explicit approval.
1. Re-run the read-only validation.
2. Run the §7 script in one transaction, via the guarded SQL or the equivalent web-admin actions.
3. Run the read-only verification.
4. Record the before/after state in a short report.

No renames, new products, schema or security changes.
