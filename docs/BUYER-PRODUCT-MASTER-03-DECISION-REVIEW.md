# BUYER-PRODUCT-MASTER-03 — Catalogue Decisions & Data Integrity Review

**Sprint:** BUYER-PRODUCT-MASTER-03 (read-only) · **Inputs:** [01 audit](BUYER-PRODUCT-MASTER-01-AUDIT.md), [02 proposal](BUYER-PRODUCT-MASTER-02-CATALOGUE-PROPOSAL.md)
**Date:** 2026-10-24 · **Branch / HEAD:** `feature/broker-nilesh` @ `390fd84`
**Status:** **Awaiting owner approval. No writes performed in this sprint.**

**Labels:** **[Observed]** = read from the live DB or repo · **[Inferred]** = reasoning from observed evidence · **[Proposed]** = recommendation · **[Unverified]** = not confirmed.

**Evidence access:**
- Project `DATABASE_URL` (role `postgres`, BYPASSRLS); every query in `BEGIN READ ONLY`. DB timezone `UTC`; all times below are UTC.
- Buyer and anon access simulated with `SET LOCAL ROLE` + JWT claims.
- Companies, users and requirements are shown only as SHA-256 short hashes (`h_xxxxxxxx`). No emails, names or free-text locations are reproduced.

---

## ⚠ Disclosure: live writes caused by a test run in BUYER-PRODUCT-MASTER-01

**[Observed]** During BUYER-PRODUCT-MASTER-01 I ran RMBuyer's `flutter test` (analyze finished 2026-10-24 11:23:38 UTC; test log written 11:24:20 UTC) and reported it as non-destructive. **That was incorrect.**

Two RMBuyer test files sign in to the **live** Supabase project with a real buyer account. The credentials are hardcoded in the test files and are not reproduced here. The tests then insert real rows:

| Test file | Live writes |
|---|---|
| `test/unit/buyer_requirement_e2e_verification_test.dart` | inserts a requirement: Dal (`a732266b`), grade Moisture, unit kg, ₹5250, target +10 days |
| `test/unit/buyer_broker_notification_backend_test.dart` | inserts a requirement (₹5350, +12 days, broker selected) **and** calls `notify_requirement_brokers` |

**[Observed]** As a direct result, the live DB gained:
- **2 requirements** created 2026-10-24 11:23:51.46 and 11:23:52.59 UTC;
- **1 `REQUIREMENT_CREATED` notification** at 11:23:51.63 UTC.

They have not been modified or deleted (prohibited in this sprint). Removing them is your decision.

**[Proposed]** Until the live tests are isolated (see §9, step 0), do not run RMBuyer's full `flutter test`.

---

## 1. Summary of decisions required

| # | Decision | Recommendation | Section |
|---|---|---|---|
| D1 | Treatment of the 22 Dal requirements | Treat **≥15 as automated-test records** (strong evidence). Confirm ownership of the test buyer account and approve a provenance flag. Don't delete until approved | §2 |
| D2 | Rename `Yellow Maize (Corn)` → `Maize (Corn)` | Safe **with compatibility measure** (alias first) | §3 |
| D3 | Rename `Sharbati Wheat` → `Wheat`, Sharbati as grade | **Needs compatibility measures**; sequence after deactivating the duplicate `Wheat` | §3 |
| D4 | Rename `Soybean Seed` → `Soybean` | Safe, low impact; **do not** link `Soyabean` by identity | §3 |
| D5 | Deactivate duplicates `maize` (`97eccc57`), `Wheat` (`13a5208a`) | Safe for history; RMBroker caveat | §4 |
| D6 | Reactivate `Chana` (`b19c9beb`) | **Defer**: unsafe without a category and ≥1 real grade | §4 |
| D7 | Product identity questions (SBM/DOC, middlings/pollard, DDGS, form, variety) | Matrix in §5 | §5 |
| D8 | Separate "Animal Nutrition & Feed" industry? | **Not necessary now**; use categories + product type | §6 |
| D9 | Security follow-up (default ACL grants, live test credentials) | Separate micro-sprint, **before** catalogue writes | §7 |
| D10 | HSN and Hindi workflow, reviewer and sources | Approve the workflow in §8 | §8 |

## 2. Evidence about the 22 Dal requirements

### 2.1 Observed facts
- **Commodity** `a732266b` "Dal": active, category Grains & Cereals, only grade `1f13a047` "Moisture". 22 requirements, 0 availabilities, 0 deals.
- **Creation dates (UTC):** **20 on 2026-10-20** between 01:28:17 and 02:52:41; **2 on 2026-10-24** at 11:23:51–52 (my test run, see Disclosure).
- **Status / visibility:** 20 `Open`, 2 `Proposed to Buyer`; all `global`.
- **Companies:** 21 of 22 belong to one company `h_c23498dc`. That company ID is the one the live RMBuyer tests assert (`expect(success.user.companyId, '53b23dbe…')`); its hash matches. It has 1 user, a buyer. The remaining Dal requirement belongs to company `h_f3a06c41`.
- **Unit:** 21 × kg (`bfefee25`, the unit the tests hardcode), 1 × MT.
- **Signature groups** (price / broker set / target-minus-created days):

| Price | Broker | Offset (days) | Count | Matches |
|---|---|---|---|---|
| 5250 | no | 10.23 | 10 | `buyer_requirement_e2e_verification_test` (5250, +10 d, no broker) |
| 5350 | yes | 12.23 | 5 | `buyer_broker_notification_backend_test` (5350, +12 d, broker Varun) |
| 5400 | no | 10.00 | 3 | no current test file (possibly an earlier test version, **[Unverified]**) |
| 5200 | no | 7.00 | 1 | `5200` appears only in in-memory unit tests (`buyer_broker_selection_and_notification_unit_test`); **[Unverified]** link |
| 5000 / 5100 | no / yes | 14.00 | 1 / 1 | no matching source found |
| 4900 | yes | 14.89 | 1 | company `h_f3a06c41`, unit MT, RMBuyer preset location, target date at midnight |

- **Quantities:**
  - The 5250/5350 groups have quantities of 40–79. That fits `40 + second % 50` and `50 + second % 30` in the two tests.
  - Several 5250 and 5350 rows were created **one second apart in pairs** (e.g. 2026-10-20 ≈02:35:26/27 and ≈02:38:02/03 UTC; 2026-10-24 11:23:51/52 UTC). That fits the two test files running back-to-back.
- **The fractional `.23` day offset** = 5 h 30 min. **[Inferred]** The client sent an IST local `DateTime` without a zone (Dart `toIso8601String()` on a local time) while `created_at` is UTC `now()`. This is consistent with the Dart tests. The exact `.00` offsets indicate a UTC-computing writer (e.g. web actions using `Date.now() + n·86400000`).
- **Location field:** 21 rows carry free text that is not in RMBuyer's 6 preset locations. The tests use strings like "Jaipur Depot Gate <second>" and "Kota Mandi Yard Gate 1". Only 1 row uses an RMBuyer preset.
- **Downstream links:**
  - 17 rows have nothing linked.
  - 3 rows have 1 `REQUIREMENT_CREATED` notification each.
  - 2 rows (`Proposed to Buyer`) have 1 `deal_versions` row and 1 `negotiation_events` row each, plus `DEAL_VERSION_UPDATE` notifications. A broker proposal was made on them (RMBroker Work Desk proposal flow, 2026-10-20 03:38 UTC).
- **Demo indicators:** no requirement-level test flag exists (no `source`, `created_by` or `notes` column). Company and user names/emails of the two Dal companies do not match `test|demo|sample|dummy|qa|uat`. The 6 seeded non-Dal companies do.
- **Provenance tables:** `requirements` has no triggers. There's no app-level audit table for requirements; `public.negotiation_events` covers negotiations only. `auth.audit_log_entries` exists (logins), but **was not queried** because it contains PII. `pg_stat_statements` is installed but holds aggregate statements, not per-row provenance.

### 2.2 Form behaviour (repo) [Observed]
- `post_requirement_screen.dart` `_loadMasterData()` selects `comms.first` and `grades.first` by default (L159–175).
- `getMasterCommodities()` orders by name. Live active order: **Dal, maize, Rice, Sharbati Wheat, Soybean Seed, Wheat, Yellow Maize (Corn)**.
- Dal's only grade is Moisture.
- `getMasterUnits()` has **no ORDER BY**. Live physical order starts with **Kilograms (kg)**, then Tonn, Metric Ton, Quintal.
- So the untouched RMBuyer form defaults to **Dal / Moisture / kg / qty 50 / ₹4800 / first preset location / +14 days**.

### 2.3 Inference
- **[Inferred, high confidence]** At least **15** Dal rows (the 5250 and 5350 groups), plus my 2, were written by the automated live tests: exact price, offset, unit and broker matches, the same test account's company, and paired timing.
- **[Inferred, medium]** The other 5 rows from company `h_c23498dc` (5400 ×3, 5200, 5000, 5100) are probably earlier or manual test activity by the same test account. **[Unverified]**
- **[Inferred, medium]** The single `h_f3a06c41` row (4900, MT, preset location, date-picker date) looks like a **manual RMBuyer submission**: quantity, price and date were edited, but commodity and grade were left at the **default Dal/Moisture**. The same company's maize requirement uses the untouched defaults (50 / ₹4800 / preset / +14 d) with maize explicitly selected. So default preselection plausibly produced a real but unintended Dal row. **[Unverified]**
- **Same pattern elsewhere:** the default-preselection effect cannot be seen on other products because Dal is the only default. The live-test pattern is confined to Dal (the tests hardcode its ID).

### 2.4 Recommendation [Proposed]
1. You confirm whether the account behind `h_c23498dc` is a dedicated test account.
2. If it is, classify its 21 Dal rows as test records using a **reviewed ID list** generated from the signatures above. Ask the `h_f3a06c41` buyer about their 1 row.
3. Record provenance **without deleting**. Options:
   - (a) an `is_test boolean` / `source text` column on `requirements` (schema change), or
   - (b) set status `Cancelled` with a reason. RMBuyer has no reason column today, so (a) is cleaner.
4. The 2 `Proposed to Buyer` rows have negotiation records (append-only, trigger 0034). Any clean-up must preserve those, so flag rather than delete.
5. Fix at the source:
   - isolate live tests (tag `live`, excluded by default; dedicated test project or DB branch; credentials from env, not source);
   - remove default preselection of commodity/grade in RMBuyer (planned picker sprint);
   - give `getMasterUnits()` a deterministic order.

## 3. Rename impact analysis [Observed unless noted]

| | `2000…0001` Yellow Maize (Corn) | `2000…0002` Sharbati Wheat | `2000…0003` Soybean Seed |
|---|---|---|---|
| Status / code / category | active / MAIZE-01 / **none** | active / WHEAT-01 / **none** | active / SOY-01 / **none** |
| Grades | Grade A Milling (3 req, 2 avail), Feed Grade Premium (1 req) | Premium Sharbati (2 req, 1 avail) | Standard Mandi Grade (1 req) |
| Requirements (total / live status) | 4 / 2 | 2 / 2 | 1 / 1 |
| Availabilities | 2 | 1 | 0 |
| Deals (via requirement) | 7: Draft, Negotiation, Awaiting Seller Confirmation, Finalized, Dispatch Pending, Disputed, Cancelled | 2: Awaiting Buyer Confirmation, Completed | 0 |
| Allocations / deal versions / bookings | 3 / 4 / 0 | 1 / 2 / 0 | 1 / 0 / 0 |
| Name frozen in stored text (snapshots, negotiation payloads, notifications) | 0 | 0 | 0 |
| Hardcoded in production code | RMBuyer fallback list (`master_requirement_data.dart` L74–76), RMBuyer demo offers (`offers_repository.dart` L482, L606), RMBroker form fallback `comm-102` (`create_requirement_sheet.dart` L259, `create_offer_sheet.dart` L268), web demo data (`broker-work-actions.ts` L113) | same RMBuyer lists (L79–81, `offers_repository.dart` L546); RMBroker fallback `comm-101`; RMBroker demo commission/invoice (`commission_repository.dart` L53, `invoice_repository.dart` L174/182); web demo (`broker-work-actions.ts` L83; "Malwa Sharbati Wheat" in 5 web demo actions) | RMBuyer fallback (L84–86), demo offer (L648) |
| Display consumers | name joined live by RMBuyer (requirements, offers, deals), RMBroker (Work Desk, deals, search, commission), RMSeller (commodities, deals, invoices), web (≈20 actions) | same | same |
| Web cascade (Industry → Category → Commodity) | **unreachable today** (no category) | **unreachable** | **unreachable** |

**Assessment [Proposed]:**
- **Maize: safe with a compatibility measure.**
  - No stored text depends on the name, and historical rows re-render with the new name.
  - Add the alias "Yellow Maize" before the rename (needs the `aliases` column), so search and the buyer's mental model still match.
  - "Yellow" carries colour/variety information. If white maize may be traded, keep the colour as a grade or variety. **Owner decision.**
- **Wheat: needs compatibility measures; don't do it standalone.**
  1. Deactivate `13a5208a` "Wheat" **first** (same transaction), or two active "Wheat" records would appear.
  2. The variety then lives only in grade "Premium Sharbati". RMBuyer's requirement list and deals list show commodity name only, so "Sharbati" disappears from those list views (detail screens show the grade). The **Completed** deal's history would read "Wheat".
  3. Accept that, or show the grade in list views first (Buyer picker sprint).
  4. The web demo strings "Malwa Sharbati Wheat" are not DB-bound and are unaffected.
- **Soybean: safe, low impact** (1 open requirement, 1 allocation).
  - **`Soyabean` (`efbc3e5e`)** is inactive, has no category, code or grades, and has 0 references. Its creator and intent are unknown. **[Unverified]** that it means the same product.
  - Recommendation: leave the record untouched and use "Soyabean" only as a **search alias string** on Soybean. Don't merge, and don't assert identity.
- **All three:** assign category Grains & Cereals (or Whole Oilseeds for soybean) in the same change. That makes them reachable in the web cascading forms.

## 4. Duplicate deactivation and Chana reactivation

| Record | Observed state | References | Code refers by ID/name? | Effect of change | Risk | Recommendation |
|---|---|---|---|---|---|---|
| `97eccc57` "maize" | active; category Grains & Cereals; 1 grade (`0c90ef99` "Moisture : 14"); 1 quality parameter | 0 req / 0 avail / 0 deals; FK from grade + quality param | No (ID not in code) | Hidden from RMBuyer, RMSeller and web admin lists (`status = true` filters). History unaffected (nothing references it) | **RMBroker** `getMasterData()` loads commodities **without a status filter** and all grades without a commodity filter, so the broker form would still offer it | **Deactivate (approve)**. Record the RMBroker filter gap for its owner |
| `13a5208a` "Wheat" | active; category Grains & Cereals; 0 grades | none | No | Hidden from selectors | Same RMBroker caveat. Must precede the Sharbati→Wheat rename | **Deactivate (approve)**, in the same transaction as D3 |
| `b19c9beb` "Chana" | **inactive**; no category, code or grades | none | No (RMBuyer/RMSeller fallbacks use different, non-existent IDs `2000…0005` / `1000…`) | Becomes selectable | **With no grade, RMBuyer falls back to synthetic grade `21000000-…0099`, which doesn't exist, so the insert fails the `grade_id` FK.** No category means it's unreachable in the web cascade | **Defer.** Reactivate only together with category assignment + ≥1 real grade, after the RMBuyer fallback is removed |

**Related observed defects (not to be fixed now):**
- RMSeller offline fallback grade IDs `20000000-…01..06` equal live **commodity** IDs, and its fallback commodity IDs `10000000-…` equal seeded **state** IDs (`master_commodity_data.dart` L150–185). If used, they would write mismatched references.
- RMSeller also uses `20000000-…0001` as a fallback **user/actor ID** (`negotiation_repository.dart`, `notifications_repository.dart`, `seller_profile_repository.dart`).

## 5. Product identity and variant decision matrix [Proposed]

The hierarchy has **one** variant level (Grade). The proposed naming convention for multi-dimension grades is `<form/variety> · <quality tier>` (e.g. "Pellet · Standard"). A dedicated `form` attribute is a later schema option.

| Question | Identity vs grade vs form vs source vs regulatory | Recommendation | Basis / confidence |
|---|---|---|---|
| Soybean Meal vs Soybean DOC | Same product identity (solvent-extracted soybean residue, traded in India as DOC); differences are protein band and physical form | **One commodity** "Soybean Meal (DOC)"; grades by protein band/form; aliases SBM, Soya DOC | **[Inferred]** trade usage, no repo evidence. Medium. Owner/trader confirmation |
| Middlings vs Pollard | Both are wheat-milling fractions between bran and flour; naming varies by region and mill | **One commodity** "Wheat Middlings", alias "Pollard", **unless** your counterparties price them differently, in which case keep two | **[Inferred]** Low–medium. **Requires trade confirmation** |
| Mustard Cake vs Mustard DOC | Different processes (expeller cake retains oil; DOC is solvent-extracted); different oil/protein and price | **Separate commodities** | **[Inferred]** Medium–high |
| DDGS by source (rice / maize / wheat) | Source changes protein, fat and fibre materially, and the price | **Separate commodities** per source; grades by protein band | **[Inferred]** Medium. Owner confirm |
| BDG by source | Same logic, lower trade volume | One commodity "Brewers' Dried Grains" with source as grade, **or** separate if traded separately | **[Inferred]** Low. Owner |
| Pellet vs Mash vs Nuggets | Same formulation, different processing form | **Grade/form** of the finished feed, not separate commodities | **[Inferred]** Medium–high |
| Finished feed segments (dairy high-yield, buffalo, calf starter, heifer, dry-cow, transition) | Different formulations and nutrient specs | **Separate commodities** in Finished Cattle Feeds; form as grade | **[Inferred]** Medium |
| Sharbati, Lokwan, Malwa etc. (wheat); Desi/Kabuli (chana); Yellow/White (maize) | Varieties of the same commodity | **Grades/varieties**; existing grade "Premium Sharbati" already does this | **[Observed]** grade exists; Medium–high |
| Vitamin A / D3 / E / ADE premixes | Same product family, different composition | One commodity "Vitamin AD3E Premix" with grades, **or** separate if sold as distinct SKUs | **[Inferred]** Low–medium. Owner |
| Mineral mixture, premixes, bypass fat/protein, yeast, probiotics, enzymes, toxin binders, buffers | Feed additives/supplements; some may need product registration or compliance under feed/additive rules | Category "Vitamins, Supplements & Premixes", type `supplement`; **compliance review flag** per product | **[Unverified]** regulatory status. Separate review |
| Calcium boluses, oral calcium, electrolytes | Dosage-form products. Depending on composition and claims they may be classed as veterinary medicinal products rather than feed | **Separate category** "Veterinary-type Nutritional Products", type `veterinary_type`. **Exclude from buyer requirement trading until a compliance review approves them** | **[Unverified]**, needs regulatory review. Do not group with feed ingredients |
| Generic "Dal" | Processed split pulse, not one commodity | Keep the record for history; no new usage; review after D1 | **[Observed]** generic name |

## 6. Industry / category recommendation

**[Observed]**
- `Agriculture` is the only active industry. The web requirement form (`src/components/forms/requirement-form.tsx`) and the buyer wizard (`src/components/buyer/requirements/requirement-wizard.tsx`) cascade **Industry → Category → Commodity**.
- RMBuyer, RMBroker and RMSeller don't read industries.
- No code filters or reports by industry apart from these cascades and web admin listings.

**[Proposed]**
- A separate "Animal Nutrition & Feed" industry is **not necessary** to represent the catalogue. Categories (A–K + veterinary-type) plus the proposed `commodity_type` attribute separate raw materials, by-products, supplements, finished feeds and veterinary-type items cleanly.
- **Trade-off:** keeping everything under Agriculture gives one long category list in the web cascade (≈13 categories). A second industry would shorten it but adds a step. Moving categories between industries later is a one-column update.
- **Recommendation:** keep a single Agriculture industry now, and revisit once the web UX is reviewed. No new industry in this sprint.

## 7. Access-control findings and security follow-up

### 7.1 Read access by role (simulated, read-only) [Observed]
Access paths:
- `anon` = `SET LOCAL ROLE anon`.
- `authenticated buyer` = `SET LOCAL ROLE authenticated` + `request.jwt.claims.sub` = an existing buyer.
- Grants were taken from `has_table_privilege` and `information_schema.role_table_grants`.

| Table | anon SELECT | authenticated (buyer) SELECT | service_role SELECT | RLS policy |
|---|---|---|---|---|
| master_industries | ✘ 42501 | ✘ 42501 | ✘ | none |
| master_categories | ✘ 42501 | ✘ 42501 | ✘ | none |
| master_commodities | ✔ 9 rows | ✔ 9 rows | ✘ | `master_commodities_read` (true) |
| master_grades | ✔ 8 | ✔ 8 | ✘ | `master_grades_read` |
| master_units | ✔ 4 | ✔ 4 | ✘ | `master_units_read` |
| master_quality_parameters | ✘ 42501 | ✘ 42501 | ✘ | none |

- **Buyer product picker:** commodities, grades and units are readable, so the **current** picker works. **Category grouping, the category embed and quality parameters are not readable**, so the planned grouped picker needs a read grant + policy on `master_categories` (and `master_industries` if shown).
- **[Observed]** `service_role` has **no SELECT** on any master table. Server code using the service-role key through PostgREST (e.g. `src/server/actions/admin-user-actions.ts`) can't read master data that way. Drizzle over `DATABASE_URL` (role `postgres`) can.

### 7.2 TRUNCATE / TRIGGER / REFERENCES / MAINTAIN [Observed]
- `authenticated` holds REFERENCES, TRIGGER and TRUNCATE on **39** public tables; `anon` holds them on **18**. On every `master_*` table, all three roles (anon, authenticated, service_role) have TRUNCATE, TRIGGER and REFERENCES.
- **Root cause:** `pg_default_acl` for owner `postgres` in schema `public`, object type tables, = `anon=Dxtm, authenticated=Dxtm, service_role=Dxtm` (D = TRUNCATE, x = REFERENCES, t = TRIGGER, m = MAINTAIN). **Every new table** created by `postgres` inherits these. The default ACL for owner `supabase_admin` grants full `arwdDxtm` to anon/authenticated (Supabase platform default).
- **Why this matters (not proven safe):**
  - TRUNCATE is **not subject to RLS**. PostgREST doesn't expose TRUNCATE.
  - Any future path that runs SQL as these roles would allow wiping tables: a SECURITY INVOKER function, an RPC that builds dynamic SQL, an extension, or a misconfigured SQL endpoint. TRIGGER allows creating triggers only for owners in practice, but the grant should still not exist.
  - MAINTAIN (PostgreSQL 17) allows VACUUM, ANALYZE, REINDEX, REFRESH MATERIALIZED VIEW and LOCK.
- **[Proposed] Separate micro-sprint SEC-PRIV-01 (controlled, approval gate):**
  1. Inventory every grant.
  2. `REVOKE TRUNCATE, TRIGGER, REFERENCES, MAINTAIN` from anon/authenticated (and review service_role) on public tables.
  3. `ALTER DEFAULT PRIVILEGES … REVOKE` for future tables.
  4. Decide whether service_role needs SELECT on master data.
  5. Regression-test all three apps and the web.

  Also include in SEC-PRIV-01 (or a sibling sprint): **remove hardcoded live credentials from RMBuyer tests and rotate that account's password.**

## 8. HSN and Hindi-name verification workflow

### 8.1 HSN [Proposed]
- **[Observed]** No HSN data exists, so **every product stays `pending_verification`**. No codes are proposed.
- **Workflow:**
  1. **Describe:** write the exact commercial description (material, process, form, intended use) per product. Classification depends on these.
  2. **Classify** against the CBIC Customs Tariff (First Schedule, including section and chapter notes) and the current GST rate notifications and amendments. Record:
     - candidate code (4/6/8 digits as required);
     - source document and version or notification number;
     - effective date;
     - classification rationale.
  3. **Review:** a second reviewer (tax adviser or CA) confirms. Rows flagged `requires_review` (supplements, premixes, finished feeds, veterinary-type, silage/straw forms) always need this second review.
  4. **Record:** `hsn_code`, `hsn_status = verified`, `hsn_source`, `hsn_effective_date`, `hsn_verified_at`, `hsn_verified_by`. Applied in a separate, evidence-referenced data change, never in the catalogue seed.
  5. **Re-verify** whenever a relevant notification changes. Keep the old values in history.
  6. **Display:** show the code only if `verified`; otherwise "HSN pending verification".

### 8.2 Hindi names [Proposed — every row needs owner review; none approved]
Only common, widely used terms are listed. Anything uncertain is marked.

| Canonical (EN) | Proposed Hindi display | Aliases (romanised) | Confidence |
|---|---|---|---|
| Maize (Corn) | मक्का | Makka, Makki | High |
| Wheat | गेहूँ | Gehun, Gehu | High |
| Soybean | सोयाबीन | Soyabean, Soya | High |
| Chickpea (Chana) | चना | Chana, Desi Chana, Gram | High |
| Rice | चावल | Chawal | High |
| Paddy | धान | Dhan | High |
| Bajra (Pearl Millet) | बाजरा | Bajra | High |
| Jowar (Sorghum) | ज्वार | Jowar, Jwar | High |
| Barley | जौ | Jau | High |
| Mustard Seed | सरसों | Sarson, Rai (**review**: rai can denote a different mustard type) | Medium |
| Mustard Cake | सरसों की खली | Sarson Khal | Medium |
| Cottonseed / Cottonseed Cake | बिनौला / बिनौला खली | Binola, Binola Khal | Medium |
| Groundnut | मूंगफली | Moongphali | High |
| Sesame | तिल | Til | High |
| Linseed | अलसी | Alsi | High |
| Wheat Bran | गेहूँ का चोकर | Chokar | Medium |
| Wheat Straw | गेहूँ का भूसा | Bhusa, Gehu Bhusa | Medium |
| Molasses | शीरा | Sheera | Medium (**review**: "gud" is jaggery, not molasses) |
| Lucerne Hay | रिजका | Rijka | Medium |
| Berseem | बरसीम | Berseem | High |
| Moong | मूंग | Moong | High |
| Urad | उड़द | Urad | High |
| Lentil | मसूर | Masoor | High |
| Peas | मटर | Matar | High |
| Common Salt | नमक | Namak | High |
| DDGS, DORB, DCP, MCP, premixes, bypass fat, toxin binder, etc. | **No Hindi display proposed**: trade uses the English/acronym names | — | Owner to decide |

Process: native-speaker review, then owner approval, then stored in `name_hi`/`aliases` by the approved seed. Unapproved names are not displayed.

## 9. Recommended implementation order [Proposed]

| Step | Sprint (suggested ID) | Type | Gate |
|---|---|---|---|
| 0 | **TEST-ISOLATION-01**: tag RMBuyer live tests (`@Tags(['live'])`, excluded by default via `dart_test.yaml`); move credentials to env; run live tests only against a test project/branch | code (tests only) | owner approval |
| 1 | **SEC-PRIV-01**: revoke TRUNCATE/TRIGGER/REFERENCES/MAINTAIN + fix default ACL; rotate the test credentials | DB security | **controlled** |
| 2 | **DATA-PROVENANCE-01**: agree how to flag the Dal/test requirements (D1); apply the approved flag | schema + data | controlled |
| 3 | **BUYER-PRODUCT-MASTER-04 (schema)**: additive columns (aliases, `name_hi`, `commodity_type`, HSN fields, unit status, `commodity_units`), category/industry read grant + policy, Drizzle sync | DB schema | controlled |
| 4 | **BUYER-PRODUCT-MASTER-05 (data)**, one guarded idempotent script: assign categories to the 3 canonical records; add aliases; deactivate `97eccc57` and `13a5208a`; renames D2–D4; hide unit `Tonn` | data | controlled |
| 5 | **BUYER-PRODUCT-MASTER-06 (catalogue seed)**: categories + new products/grades, HSN `pending_verification`, Hindi only where approved; Chana reactivation with category + grades | data | controlled |
| 6 | **BUYER-PRODUCT-PICKER-01**: RMBuyer searchable/grouped picker; no default preselection; ID-based prefill; remove hardcoded fallbacks; deterministic unit order | app code | fast-fix |
| 7 | HSN verification batches (§8.1) | data | per batch |
| Notes for other owners | RMBroker: status/commodity filters in `getMasterData()`. RMSeller: fallback ID collisions | — | their sprints |

## 10. Unresolved questions and owner approval checklist

- [ ] **D0** Acknowledge that my BUYER-PRODUCT-MASTER-01 test run created 2 live requirements and 1 notification, and decide what to do with them.
- [ ] **D1** Is the account behind company `h_c23498dc` a dedicated test account? Approve the provenance-flag approach (column vs cancel).
- [ ] **D1b** Should the `h_f3a06c41` buyer be asked about their single Dal requirement?
- [ ] **D2** Maize rename: keep "Yellow" as a variety/grade (white maize traded?).
- [ ] **D3** Wheat rename: accept that list views show "Wheat" (variety visible in detail), or wait until the grade shows in list views.
- [ ] **D4** Soybean rename; confirm "Soyabean" is a search alias only (no identity merge).
- [ ] **D5** Deactivate `97eccc57` and `13a5208a`.
- [ ] **D6** Agree to defer Chana reactivation until it has a category and grades.
- [ ] **D7** Decide the identity pairs: SBM = DOC? Middlings = Pollard? DDGS separate per source? BDG? Vitamin premixes as one product with grades?
- [ ] **D7b** Veterinary-type products: who performs the regulatory review? Excluded from trading until then?
- [ ] **D8** Keep a single Agriculture industry for now.
- [ ] **D9** Approve TEST-ISOLATION-01 and SEC-PRIV-01 before any catalogue writes.
- [ ] **D10** Name the HSN reviewer and authoritative tariff sources; name the Hindi reviewer.
- [ ] **D11** Should categories be readable by `authenticated` only, or also `anon` (public catalogue)?

---

### Actions deliberately not performed (this sprint)
- No INSERT, UPDATE, DELETE, DDL, migrations, seeds, renames, status changes, merges, policy, grant or RLS changes. All queries ran in `READ ONLY` transactions.
- No RPC calls.
- No application or test code changes; no RMBroker, RMSeller or web changes.
- No tests were run in this sprint (deliberately, given the live-write finding).
- `auth.audit_log_entries` and other PII-bearing tables were not read.
- No commit or push.
