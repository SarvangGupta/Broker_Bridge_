# BUYER-PRODUCT-MASTER-01 — Phase 1 Audit (RMBuyer Product Master)

**Sprint:** BUYER-PRODUCT-MASTER-01 · **Phase:** 1 (audit only, nothing changed) · **Date:** 2026-10-24
**Branch / HEAD:** `feature/broker-nilesh` @ `390fd84` · working tree unchanged except new `docs/*.md`
**Status:** **Stopped at approval gate.** No application code, schema, policies, seed data or remote records were modified.

**Evidence basis:**
- Repository code, migrations and Drizzle schema.
- Executed: `flutter analyze` (RMBuyer: 0 issues) and `flutter test` (RMBuyer: **156/156 passed**).
- **Remote database not inspected.** Live product rows are unknown. RB-DB-SEC-01 (2026-10-19) reported 6 `master_commodities` and 4 `master_grades` remotely, but names and IDs were not listed.

---

## 1. Project paths and architecture

| Item | Finding |
|---|---|
| RMBuyer app | `apps/rmbuyer_mobile` (Flutter 3.47.6 / Dart 3.13.5; Riverpod, GoRouter, `supabase_flutter`, Dio) |
| Data access | **Direct Supabase PostgREST** from the app (user JWT, RLS-enforced). No Next.js REST is used for products. |
| Database | Shared Supabase Postgres. Schema sources: `supabase/migrations/*.sql` and Drizzle `src/server/db/schema.ts` |
| Product master ownership | **Shared, admin-maintained.** Web admin server actions in `src/server/actions/master-data-actions.ts` (Drizzle over `DATABASE_URL`; `verifyAdminSession()` requires `users.role = 'admin'`). CRUD covers industries, categories, commodities (soft delete via `status=false`), grades, units (read), and quality parameters. |
| Other consumers of the same master | RMBroker (`work_repository.dart`, search, deals, commission), RMSeller (`commodities_repository.dart`, deals, invoices), web platform (≈20 server actions, quotation PDF) |

**Conclusion:** there is a single product master (`master_industries → master_categories → master_commodities → master_grades`, plus `master_units`). RMBuyer should **extend and consume it, not build a parallel catalogue**.

## 2. Existing product schema (repo definitions)

| Table | Columns | Constraints | Defined in |
|---|---|---|---|
| `master_industries` | id, name, is_active | PK only | 0018 |
| `master_categories` | id, industry_id → industries, name, is_active | PK, FK | 0018 |
| `master_commodities` | id (uuid), **name**, **code**, status (bool), category_id → categories | PK, FK. **No UNIQUE on name or code** | 0002, 0018 |
| `master_grades` | id, commodity_id → commodities, grade_name, parameters (jsonb) | PK, FK (nullable) | 0002 |
| `master_units` | id, name, symbol | PK only. No IsActive | 0002 |
| `master_quality_parameters` | commodity_id, name, type, unit, min/max/target, flags | FK | 0021 |
| `requirements` | commodity_id NOT NULL → commodities, grade_id NOT NULL → grades, unit_id NOT NULL → units, quantity, target_price, delivery_terms_id (free text), target_date, status, visibility, broker_id, company_id, fulfilled_quantity | FKs | 0003, 0010, 0016, Drizzle |

**Not present anywhere in the schema:**
- Hindi name, aliases, commodity type, subcategory, default or supported units per commodity, HSN code, HSN verification fields, approval status, created_at/updated_at on master tables.
- `payment_terms`, `packaging_type`, `notes` on `requirements`.

PRD v4.0 (`docs/BrokerBridge_PRD_v4.0.md` §Masters) specifies `Commodities: ID, Name, HSNCode, Category, IsActive` and a separate `GSTTypes (Rate, HSNApplicable)`. **HSN was planned but never implemented.**

### RLS / grants on product tables (repo)
- Migration 0038: RLS on for `master_commodities`, `master_grades`, `master_units` (plus states, districts, vehicle types); `SELECT USING (true)` granted to `authenticated` **and `anon`**. No write grants to app roles; writes go only through the admin server actions, which bypass RLS through Drizzle.
- **`master_categories` and `master_industries` have no RLS or grant definition in the repo.** RB-DB-SEC-01 says all public tables have RLS enabled remotely. If that is true, buyers cannot read categories until a SELECT policy is added. **Unverified.**

## 3. API / data contract used by RMBuyer today

| Call | Code | Contract |
|---|---|---|
| Commodity list | `RequirementsRepository.getMasterCommodities()` | `master_commodities.select('id, name, code, status').eq('status', true).order('name')` |
| Grades | `getMasterGrades(commodityId)` | `master_grades.select('id, commodity_id, grade_name, parameters').eq('commodity_id', id)` |
| Units | `getMasterUnits()` | `master_units.select('id, name, symbol')` (all units, no per-product mapping) |
| Commodity search | `SearchRepository.performCommoditySearch()` | `master_commodities ilike('name', '%q%') status=true limit 15` (**name only**, no code/alias) |
| Requirement insert | `CreateRequirementDto.toSupabaseInsert()` | stores `commodity_id`, `grade_id`, `unit_id` **(IDs, correct)** plus company, qty, price, `delivery_terms_id` = location text, target_date, status, visibility, broker_id |
| Requirement read | `getRequirements()`, `getRequirementById()` | embeds `master_commodities(name), master_grades(grade_name), master_units(symbol)`. The join does not filter on `status`, so inactive products still resolve for history |

## 4. Product selection and display screens (RMBuyer)

| Screen / component | File | Product use |
|---|---|---|
| Post Requirement: commodity dropdown | `requirements/presentation/post_requirement_screen.dart` `_buildCommodityDropdown` (L610) | Plain `DropdownButton<MasterCommodity>`, name only; no search, grouping or HSN. Defaults to the first commodity |
| Post Requirement: grade / unit dropdowns | same file L647, ~L700 | Grades per commodity; all units |
| Post Requirement: prefill | `_loadMasterData` L151-161, router `/requirements/new?commodity=<name>` | **Receives a commodity *name*, fuzzy `contains` match, `orElse: comms.first`, so it can silently preselect the wrong product** |
| Home: commodity search and tiles | `home/presentation/home_screen.dart` L155, L328, **hardcoded tiles L562-585** (Yellow Soybean, Desi Chana (Gram), Wheat (Sharbati), Mustard Seeds) | Navigates with a name |
| Buyer search | `search/presentation/buyer_search_screen.dart` L272-289 (hardcoded suggestion chips), L330 | Navigates with `item.title` (name) |
| Broker profile | `search/presentation/broker_profile_screen.dart` L229, L350-354 | Free-text "commodities handled" chips; prefill by name |
| Requirements list | `requirements/presentation/requirements_screen.dart` L199, L562 | `commodityName` |
| Requirement details | `requirements/presentation/requirement_details_screen.dart` L114, L255 | `commodityName` |
| Timeline | `requirements/domain/requirement_timeline_event.dart` L34 | `commodityName` |
| Offers list / detail | `offers/presentation/*.dart` | `commodityName` from requirement embed |
| Deals list / final review | `deals/presentation/*.dart` | `commodityName` from embed or snapshot |

**There is no requirement edit flow** in RMBuyer (routes: `/requirements/new`, `/requirements/:id`; detail allows cancel only). The Phase 5 check "editing does not change product" is therefore not applicable. Adding an edit flow would be a new feature and needs separate approval.

## 5. Existing products and inconsistencies

### 5.1 Product names found in the repo

| Source | Entries |
|---|---|
| Seed `supabase/seed_broker_demo_dataset.sql` (only if applied) | `2000…01` Yellow Maize (Corn) `MAIZE-01` · `2000…02` Sharbati Wheat `WHEAT-01` · `2000…03` Soybean Seed `SOY-01` |
| RMBuyer offline fallback `MasterRequirementData.verifiedCommodities` | the 3 above **plus** `2000…04` Mustard Seeds `MUSTARD-01`, `2000…05` Desi Chana (Gram) `CHANA-01` |
| RMBuyer search fallback `SearchRepository.fallbackCommodities` | ids `comm-1…comm-6`: Soybean, Chana (Gram), Wheat, Mustard Seeds, Maize (Corn), Groundnut (Peanut) |
| Home tiles / search chips / broker default specialties | Yellow Soybean, Desi Chana (Gram), Wheat (Sharbati), Mustard Seeds; Soybean, Desi Chana, Wheat, Mustard |
| Demo requirements / offers / deals in RMBuyer | Yellow Soybean, Desi Chana (Gram), Mustard Seeds, Yellow Maize / Corn, Sharbati Wheat, Soybean Seed |
| Remote | 6 commodities per RB-DB-SEC-01. **Names unknown** |

### 5.2 Inconsistencies and defects
1. **One product, many names.** Maize appears as "Yellow Maize (Corn)", "Maize (Corn)" and "Yellow Maize / Corn". Soybean appears as "Soybean Seed", "Yellow Soybean" and "Soybean". Wheat appears as "Sharbati Wheat", "Wheat (Sharbati)" and "Wheat". *Sharbati* is a variety and should be a grade or variant, not the product name.
2. **Fallback IDs that don't exist.** If the live query fails or returns empty, the selector shows the hardcoded list.
   - `2000…04` and `2000…05` are not in the seed. Fallback grades `2100…05`, `…06` and `…0099` are not in the seed either. Saving with them would raise FK errors, or would work against a DB that happens to differ.
   - `post_requirement_screen.dart` L251/L254 also substitutes hardcoded grade and unit IDs when none is selected.
   - The UI presents these as "verified" data.
3. **Search fallback IDs** (`comm-1…6`) are not UUIDs and don't map to the master. Only the name is passed forward, which reaches the fuzzy match in §4.
4. **Hardcoded product lists** in home tiles, search chips and the broker default specialties (`['Soybean','Chana','Wheat','Mustard']`, shown when a broker has none) display products and broker specialties that may not exist.
5. **No uniqueness** on `name`/`code`. Duplicates can be created through admin CRUD.
6. **Search is by name only.** No code, Hindi or alias search.
7. **Units are global.** Every product offers MT/Qtl regardless of how it's traded, so fodder (bales), premixes (kg/bags) and liquids (kg/litre) aren't representable.

### 5.3 Adjacent defects found while tracing (outside this sprint; recommend separate sprints)
- `RequirementsRepository._baselineRequirements` merges 3 demo requirements into every buyer's list and detail. Offers and deals repositories also seed baseline demo records.
- `createRequirement` defaults `companyId` to `30000000-…0101`, **a real seeded demo company**, when the buyer's company can't be resolved. It also attempts inserts without a session and returns a locally fabricated requirement if that insert fails.
- `paymentTerms`, `packagingType` and `notes` are collected on the form but **not persisted** (no columns). They exist only in the session cache.
- `cancelRequirement` returns `true` even when nothing was updated.

## 6. HSN availability and verification gaps
- **No HSN field exists** in the schema, the Drizzle model, or any app. Nothing to verify today.
- No GST/HSN master exists, and no invoice/GST logic in RMBuyer depends on HSN (out of scope per the sprint rules).
- **No HSN codes are proposed in this audit.** Each code must be verified in Phase 2 against the CBIC Customs Tariff / GST rate schedules for the exact commodity description, with source and date recorded. Until then every product stays `pending`.
- Risk: several candidate items (finished feeds, premixes, supplements, boluses, straw, silage) may classify under different headings depending on form or composition. These need per-product evidence, not category-level assumptions.

## 7. Security and backward-compatibility risks

| Risk | Detail | Mitigation in plan |
|---|---|---|
| Shared master | Broker, Seller, web and historical requirements/deals all join `master_commodities.name` | Additive columns only. **No renames** of existing rows without an approved mapping (a rename changes historical display everywhere) |
| FK references | `requirements`, `availabilities`, `master_grades`, `master_quality_parameters` reference commodity IDs | Preserve IDs; never delete; deactivate with `status=false` |
| Drizzle drift | `schema.ts` is the Drizzle source; SQL-only columns would show up as drift in the next `drizzle-kit generate` | Update `schema.ts` in the same change |
| Category visibility | No SELECT policy for `master_categories` (or industries) in the repo | Add read-only SELECT policy (approval gate) |
| Anonymous read | 0038 grants `anon` SELECT on product tables | Acceptable for a public catalogue (HSN is public data); confirm with product owner |
| Writes | Must stay admin-only via the server actions; the Flutter apps must not write master data | No client write path added |
| Fabricated data | Hardcoded fallbacks currently mask live-query failures | Replace with an honest error/empty state + retry |
| Broker-mediated model | Product work must not expose sellers | Catalogue contains no seller or counterparty data; no change to requirement/offer visibility |

## 8. Minimal, ordered implementation plan (for approval)

**Step 0 — Read-only remote snapshot** (gate G-1). Collect:
- `master_industries`, `master_categories`, `master_commodities` and `master_grades` rows;
- `master_units`;
- reference counts per `commodity_id` across `requirements` and `availabilities`;
- RLS policies on the master tables.

Output: the duplicate/mapping list. *No writes.*

**Step 1 — Phase 2 catalogue specification** (document only). One reviewable table:
- Columns: canonical EN name, Hindi name, aliases, category/subcategory, commodity type, default and supported units, HSN, HSN status, source and date.
- Each candidate is marked new / existing (with ID) / alias of / grade-or-variant of / out of scope.
- Initial screening of the provided list:
  - **Likely aliases, not separate products:** Rice Polish vs Rice Polishings; Gram Churi vs Chana Churi; Soybean Meal vs Soybean DOC; Wheat Middlings vs Wheat Pollard; Chickpea/Chana vs existing Desi Chana; Soybean vs existing Soybean Seed; Mustard Seed vs existing Mustard Seeds; Maize vs existing Yellow Maize.
  - **Likely grades/variants:** DDGS by source (rice, maize, wheat); BDG by source; Vitamin A/D3/E/ADE premixes; cattle feed Mash/Pellets/Nuggets; Sharbati wheat.
  - **Generic placeholders, not products:** "Approved feed-grade liquid ingredients", "Feed-grade yeast products", "Green Fodder", "Dry Fodder Bales", "Feed Premix", "Pulse Chuni".
  - **Scope decision needed:** veterinary-type items (Calcium Bolus, Liquid Calcium Supplement, Electrolytes).

**Step 2 — Additive schema migration** (gate: exact SQL presented first). Proposed minimum:
- `master_commodities` + `name_hi text`, `aliases text[] default '{}'`, `commodity_type text` (check: raw_material, by_product, supplement, finished_feed, fodder, mineral), `default_unit_id uuid → master_units`, `hsn_code text null`, `hsn_status text not null default 'pending'` (check: pending, verified, not_applicable), `hsn_source text`, `hsn_verified_at date`, `created_at`, `updated_at`. Plus a partial unique index on `lower(name)` where status, applied only after duplicates are resolved.
- `master_categories` + `parent_id uuid → master_categories` (subcategory) **or** reuse industries as the top level. Decision in Step 1.
- New `master_commodity_units (commodity_id, unit_id, PK both)` for supported units. Add missing units (kg, bag, bale, litre) to `master_units` through the seed.
- SELECT policy on `master_categories` (and industries) for `authenticated`. No write grants.
- Update Drizzle `schema.ts` and the web admin actions to read/write the new fields. Web admin edit UI only if approved (it is not Buyer UI).

**Step 3 — Idempotent catalogue seed** (gate):
- Keyed on stable UUIDs with `ON CONFLICT (id) DO UPDATE` limited to the new fields.
- Existing IDs preserved; existing names unchanged unless the approved mapping says otherwise.
- HSN entered only with `verified` evidence; everything else stays `pending` with a null code.

**Step 4 — RMBuyer code** (after Steps 2–3 are live):
1. Extend the `MasterCommodity` model (Hindi name, aliases, category, type, default unit, HSN fields); one catalogue fetch with category embed, cached per session.
2. Replace the dropdown with a searchable selector (bottom sheet): EN/Hindi/alias/verified-HSN matching, deduplicated by product ID, grouped by category, with loading, empty and error/retry states. Inactive products hidden from selection but still resolved for history.
3. Selected label shows name + HSN line (`HSN: <code>` if verified, otherwise "HSN pending verification").
4. Pass **commodityId** (not name) from home, search and broker profile into `/requirements/new`; remove fuzzy matching and the `comms.first` default.
5. Requirement list and detail embed `master_commodities(name, hsn_code, hsn_status)` so saved requirements show the same product and HSN.
6. Remove the hardcoded commodity, grade, unit and search fallbacks and the hardcoded home tiles/chips (drive them from the catalogue or drop them). Units are offered from `master_commodity_units`, falling back to all units when unmapped.

**Step 5 — Tests:**
- Repository tests with a fake Supabase client covering the catalogue query, search matching, ID-based prefill, HSN display states, and requirement round-trip of `commodity_id`.
- Widget tests for the selector and the label.
- `flutter analyze`, the full `flutter test` suite, and a debug APK build.

**Not in this sprint:** Seller/Broker UI, GST/invoice logic, requirement edit flow, fixing the adjacent defects in §5.3 (recommended as their own sprint, e.g. BUYER-REQ-INTEGRITY-01).

## 9. Decisions needed before Phase 2 / implementation
1. Approve Step 0 (read-only remote snapshot) and say which credential to use.
2. Category model: subcategory via `master_categories.parent_id`, or industries as the top level?
3. Product scope: include supplements, premixes, veterinary-type items and finished feeds, or limit to tradeable mandi commodities?
4. Variant handling: confirm that varieties and forms (Sharbati, DDGS source, pellet/mash) become **grades** rather than separate products.
5. Who verifies HSN, and which source is authoritative (the CBIC tariff PDF version and date to cite)?
6. Fix the adjacent §5.3 defects first, or after this sprint?
