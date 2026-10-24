# BUYER-PRODUCT-MASTER-05 — Batch 1 Report (PM-05)

**Sprint:** PM-05 · **Date:** 2026-10-24 · **Plan:** [BUYER-PRODUCT-MASTER-04-IMPLEMENTATION-PLAN.md](BUYER-PRODUCT-MASTER-04-IMPLEMENTATION-PLAN.md) §4 / §7
**Authorization:** owner-approved 6 logical row changes (Oilseeds category, 3 category assignments, 2 duplicate deactivations)
**Outcome:** ✅ **Committed in one transaction** at **2026-10-24 12:37:13 UTC** (txid 5162, `application_name = 'PM-05 catalogue batch 1'`). Independent post-write verification passed **30/30**.

---

## 1. Before / after (the six logical changes)

| # | Record | Field | Before | After |
|---|---|---|---|---|
| 1 | `master_categories` `fe59c01d-228e-47a8-854a-e0803cdadfa4` | row | — (no Oilseeds-like category existed in any spelling or case) | **Oilseeds**, `industry_id` = Agriculture (`d82dbe9c`), `is_active` = true |
| 2 | `20000000-…0001` Yellow Maize (Corn) | `category_id` | NULL | Grains & Cereals (`a3b89ba6`) |
| 3 | `20000000-…0002` Sharbati Wheat | `category_id` | NULL | Grains & Cereals (`a3b89ba6`) |
| 4 | `20000000-…0003` Soybean Seed | `category_id` | NULL | Oilseeds (`fe59c01d`) |
| 5 | `97eccc57-7e80-435b-a51d-32700a727804` maize | `status` | true | **false** (category unchanged: Grains & Cereals) |
| 6 | `13a5208a-7bcd-48b8-adc8-6c0f0a136c13` Wheat | `status` | true | **false** (category unchanged: Grains & Cereals) |

Names, codes and IDs of all five commodity rows are unchanged. Nothing was deleted. No renames.

## 2. Pre-write verification (read-only, immediately before writing): 14/14 PASS

- **Parents:** Agriculture exists and is active. Grains & Cereals exists, is active, and sits under Agriculture.
- **No existing Oilseeds category:** checked with a letters-only, case-insensitive match on `%oilseed%`. The new UUID was unused.
- **The three primary products:** active with `category_id IS NULL`, matching exact names.
- **The two duplicates:** active, in Grains & Cereals, with **zero transactional references**, direct or indirect:
  - requirements, availabilities;
  - deals, quotations and allocations (via requirements and offers);
  - requirements/availabilities via their grades;
  - quality specs, values and lab results via their quality parameters.
  - `maize` keeps its own grade `0c90ef99` and quality parameter `19cfed1b`, both unreferenced and untouched.
- **Schema matches the plan SQL:**
  - `master_categories` (id uuid, industry_id uuid NULL, name text NOT NULL, is_active bool default true) and `master_commodities` (id, name, code, status, category_id).
  - Constraints: primary keys plus FKs `industry_id → master_industries` and `category_id → master_categories`.
  - Exactly 4 FKs into `master_commodities`.
  - **No user triggers or rules** on either table.
- **Baseline counts:** 9 commodities, 7 active, 2 categories.

## 3. Execution safeguards (all inside the same transaction)

1. `SET LOCAL lock_timeout = '5s'`, `statement_timeout = '30s'`.
2. `SELECT … FOR UPDATE` on the 5 target commodities. This blocks any concurrent new FK reference until commit. `FOR SHARE` on the Agriculture and Grains & Cereals parent rows.
3. The plan's §7 guard `DO` block, run verbatim, plus extra guards: spelling variants, parents, grade-level references.
4. **Exact affected-row assertions:** insert = 1; maize/wheat category = 2; soybean category = 1; deactivations = 2. Each `UPDATE` also carries its precondition in the `WHERE` clause (`category_id IS NULL` / `AND status`).
5. The plan's post-condition block, run verbatim: active commodities = 5.
6. **Unrelated-data fingerprints** (md5, taken before vs after, in-transaction), all identical: other commodities, pre-existing categories, industries, grades (incl. parameters), units, quality parameters, requirements, availabilities and deals.
7. Final-state assertions per target row; Oilseeds exactly once under Agriculture; 3 categories in total.

Any failed assertion would have thrown, and postgres.js would have rolled back the whole transaction.

## 4. Post-write verification (new read-only session, compared with the saved pre-write snapshot): 30/30 PASS

| Check | Result |
|---|---|
| Oilseeds exists exactly once, under Agriculture, active, expected ID | PASS |
| 5 target rows have the expected status/category; names and codes unchanged | PASS |
| The other 4 commodities (Dal, Rice, Chana, Soyabean) byte-identical | PASS |
| Pre-existing categories, industries, grades, units, quality parameters identical | PASS |
| Duplicates still zero-referenced | PASS |

**Final record counts:**

| Table | Before | After |
|---|---|---|
| master_industries | 2 | 2 |
| master_categories | 2 | **3** |
| master_commodities (total / active) | 9 / 7 | 9 / **5** |
| master_grades | 8 | 8 |
| master_units | 4 | 4 |
| master_quality_parameters | 1 | 1 |
| requirements / availabilities / deals | 29 / 3 / 9 | 29 / 3 / 9 |
| quotations / requirement_allocations / deal_versions / negotiation_events | 9 / 5 / 9 / 2 | 9 / 5 / 9 / 2 |
| requirements reference fingerprint (id + commodity + grade + unit) | `db8d5e6a…` | `db8d5e6a…` (identical) |
| availabilities reference fingerprint | `a5e2fa3e…` | `a5e2fa3e…` (identical) |

## 5. Application visibility after Batch 1 (read-only, same queries as the apps)

| Consumer | Now shows | Notes |
|---|---|---|
| RMBuyer / RMSeller selector (`status = true`, ordered by name; RMBuyer checked as role `authenticated`) | Dal, Rice, Sharbati Wheat, Soybean Seed, Yellow Maize (Corn) | duplicates gone. **Default preselection is still "Dal"** (alphabetically first). Fixing that is picker work, not data |
| Web cascade (active industry → active category → active commodity) | Agriculture → **Grains & Cereals**: Dal, Rice, Sharbati Wheat, Yellow Maize (Corn); → **Oilseeds**: Soybean Seed | maize, wheat and soybean are now reachable in the web form (previously unreachable without a category) |
| **RMBroker** `getMasterData()` (no status filter) | all 9 incl. **Wheat (inactive), maize (inactive)**, Chana, Soyabean | **Known limitation:** RMBroker still offers inactive products (and all grades, unfiltered by commodity). Needs an RMBroker code change (out of scope) |
| RMBuyer category grouping | not available | `authenticated` still has **no SELECT on `master_categories`** (SEC-PRIV-01). Unchanged, as instructed |

Historical requirements, offers and deals keep resolving their products (IDs unchanged; joins don't filter on status).

## 6. SQL used

This is the plan's §7 script (guards, statements and post-condition), executed through `postgres.js` `sql.begin()`, which is a single `BEGIN … COMMIT` and rolls back on any thrown error. The core statements:

```sql
INSERT INTO public.master_categories (id, industry_id, name, is_active)
VALUES ('fe59c01d-228e-47a8-854a-e0803cdadfa4', 'd82dbe9c-6780-4c95-9cf2-0ed19680a0e7', 'Oilseeds', true)
ON CONFLICT (id) DO NOTHING;                                                        -- 1 row

UPDATE public.master_commodities SET category_id = 'a3b89ba6-fc77-4db6-ba32-25d833bf29ee'
 WHERE id IN ('20000000-0000-0000-0000-000000000001','20000000-0000-0000-0000-000000000002')
   AND category_id IS NULL;                                                          -- 2 rows
UPDATE public.master_commodities SET category_id = 'fe59c01d-228e-47a8-854a-e0803cdadfa4'
 WHERE id = '20000000-0000-0000-0000-000000000003' AND category_id IS NULL;          -- 1 row
UPDATE public.master_commodities SET status = false
 WHERE id IN ('97eccc57-7e80-435b-a51d-32700a727804','13a5208a-7bcd-48b8-adc8-6c0f0a136c13')
   AND status;                                                                       -- 2 rows
```

The script itself (`pm05_apply.mjs`) was kept in the session scratchpad, outside the repository, and isn't a tracked migration. Batch 1 is a data change only, and the schema is unchanged.

## 7. Rollback instructions (not executed)

Only for an approved reversal. Run in one transaction and verify afterwards with the same read-only checks:

```sql
BEGIN;
UPDATE public.master_commodities SET status = true
 WHERE id IN ('97eccc57-7e80-435b-a51d-32700a727804','13a5208a-7bcd-48b8-adc8-6c0f0a136c13') AND status = false;
UPDATE public.master_commodities SET category_id = NULL
 WHERE id IN ('20000000-0000-0000-0000-000000000001','20000000-0000-0000-0000-000000000002','20000000-0000-0000-0000-000000000003');
DELETE FROM public.master_categories
 WHERE id = 'fe59c01d-228e-47a8-854a-e0803cdadfa4'
   AND NOT EXISTS (SELECT 1 FROM public.master_commodities WHERE category_id = 'fe59c01d-228e-47a8-854a-e0803cdadfa4');
COMMIT;
```

The `DELETE` removes only the category created by this batch, and only once no commodity references it. If later batches add commodities to Oilseeds, a rollback must reassign or keep them first.

## 8. Commands and tests actually run

| Step | Command (from repo root; scripts in the session scratchpad) | Result |
|---|---|---|
| Git state | `git status --short`, `git diff --stat` | only TEST-ISOLATION-01 changes + untracked docs (unchanged) |
| Pre-write verification | `node pm05_precheck.mjs <repo> pm05_before.json` (READ ONLY) | 14/14 PASS; snapshot saved |
| Apply | `node pm05_apply.mjs <repo>` (one read-write transaction) | `COMMITTED`; statement counts 1 / 2 / 1 / 2; fingerprints unchanged |
| Post-write verification | `node pm05_precheck.mjs <repo> pm05_after.json` (READ ONLY) + snapshot comparison | 30/30 PASS |
| Visibility | `node pm05_visibility.mjs <repo>` (READ ONLY; RMBuyer view as role `authenticated`) | as §5 |

- **Flutter / unit tests:** none run. No application code changed, and RMBuyer's live tests must not run against production.
- **Credentials:** the connection string was read from the git-ignored `.env.local`/`.env` inside the scripts and never printed or logged.

## 9. Not changed (per restrictions)

No schema, alias, auth, RLS, grant or application-code change. No renames. No new products or grades. No deletions. No commit or push.

## 10. Remaining items (unchanged from the PM-04 plan)

- Renames D2–D4, which need alias storage first.
- Batch 3 products, which need list approval and approval of the default "FAQ" grade.
- RMBroker status filtering.
- Category read access for RMBuyer (separate security approval).
- The RMBuyer default-preselection fix (picker sprint).
