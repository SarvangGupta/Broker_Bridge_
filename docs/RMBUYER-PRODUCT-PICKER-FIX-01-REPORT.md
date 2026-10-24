# RMBUYER-PRODUCT-PICKER-FIX-01 — Commodity Picker Report

**Date:** 2026-10-24 · **Branch:** `feature/broker-nilesh` (uncommitted, not pushed)
**Scope:** RMBuyer → Post Procurement Requirement → Select Commodity only.
**Outcome:** ✅ The picker loads the live shared Product Master. The three products (Yellow Maize (Corn), Sharbati Wheat, Soybean Seed) are selectable, and the selected product's database ID reaches the submission payload. No schema, RLS, grant, auth or data change.

---

## 1. Root cause

The database was **not** the problem. A read-only check (role `authenticated` with buyer JWT claims, and role `anon`) returns exactly the 5 active products. `master_commodities_read` allows SELECT for `anon` and `authenticated` with `qual = true`.

The defects were all in the app's loading and selection logic:

| # | Defect | Effect |
|---|---|---|
| 1 | `getMasterCommodities()` **swallowed every error and empty result** and returned a hardcoded list (`MasterRequirementData.verifiedCommodities`). | On any failure the picker silently showed a stale list. That list included **Mustard Seeds / Desi Chana with IDs `20000000-…0004/0005` that do not exist in the live table**, and it omitted Dal and Rice. The screen's "offline defaults" banner could never fire, because the repository never threw. |
| 2 | `.order('name')`: in postgrest-dart, `order()` **defaults to descending** (`order=name.desc.nullslast`). | The catalogue was reverse-alphabetical: Yellow Maize, Soybean Seed, Sharbati Wheat, Rice, Dal. The device screenshot taken before the fix showed this: the screen opened with "Yellow Maize (Corn)" preselected. PM-05 predicted "Dal" from the SQL; the Dart client actually sends DESC. |
| 3 | **Silent default preselection.** With no route commodity, the screen picked `comms.first`; any unmatched `?commodity=` (e.g. "Soyabean" from a broker's specialties, or "Mustard Seeds"/"Chana (Gram)"/"Groundnut" from the search fallback list) also fell back to `comms.first`. `comms.first` also throws on an empty list. | A product the buyer never chose could be submitted. |
| 4 | When the commodity changed and the grade fetch failed, the **previous commodity's grade stayed selected**. With no grade, the DTO defaulted to `21000000-…0001`, which is a *Maize* grade. | A requirement could pair one product with another product's grade. |
| 5 | No retry, no empty/error state for the catalogue, and no search. | Not recoverable without leaving the screen. |

## 2. Actual data-loading path (after fix)

```
/requirements/new[?commodity=…&brokerId=…]          app_router.dart
  └─ PostRequirementScreen.initState
       ├─ _loadMasterData()   units / locations / payment terms (unchanged)
       └─ _loadCommodities()
            └─ RequirementsRepository.getMasterCommodities()
                 Supabase.instance.client
                 GET /rest/v1/master_commodities
                     ?select=id,name,code,status&status=eq.true&order=name.asc.nullslast
                 └─ parseActiveCommodities(): keeps status == true && id != ''
                    (missing optional fields such as `code` never exclude a row)
            ├─ success → picker field (tap → CommodityPickerSheet: search + refresh)
            ├─ empty   → "No active commodities…" + Refresh
            └─ failure → error box + Retry (no fallback list)
  └─ select commodity → _onCommodityChanged: clear grade → getMasterGrades(id)
  └─ submit → CreateRequirementDto(commodityId: selected.id, gradeId: grade.id)
       → toSupabaseInsert → requirements.commodity_id / grade_id   (unchanged insert path)
```

## 3. Fix implemented

- **Repository** (`requirements_repository.dart`): `getMasterCommodities()` now throws when the client is missing or the request fails. It has no fallback, uses explicit `ascending: true`, and maps rows through the new `parseActiveCommodities()`. The hardcoded `verifiedCommodities` list was removed from `master_requirement_data.dart`, so it can't be reused.
- **Screen** (`post_requirement_screen.dart`):
  - Commodity loading is separate from the rest of the form and has loading, error + Retry, and empty + Refresh states.
  - **Nothing is preselected.** A route-supplied commodity is matched with `PostRequirementScreen.matchInitialCommodity()`: exact name first, then the existing contains-match. If nothing matches, the result is `null` (never the first product) and a hint says the product is "not in the current catalogue".
  - Changing the commodity clears the grade first and ignores out-of-order grade responses.
  - Submit requires a grade belonging to the selected product. The hardcoded grade-ID default was removed.
  - A selection that drops out of the active catalogue on refresh is cleared.
  - The review summary shows "Not selected" until a commodity is chosen.
- **Picker** (new `commodity_picker_sheet.dart`): a bottom sheet over the fetched list, following the app's existing modal-sheet style. It has name/code search, a manual refresh, and loading, empty and no-match states. It returns the `MasterCommodity` object, so the ID travels with the selection.

**Unchanged:** the insert payload shape, the `requirements` table, negotiation, deal versioning, seller visibility, broker mediation, units/locations/payment terms, and historical records. Existing requirements reference commodities by ID, and their joins do not filter on status.

## 4. Files changed

| File | Change |
|---|---|
| `apps/rmbuyer_mobile/lib/features/requirements/data/requirements_repository.dart` | live-only catalogue, ascending order, `parseActiveCommodities` |
| `apps/rmbuyer_mobile/lib/features/requirements/domain/master_requirement_data.dart` | removed stale `verifiedCommodities` |
| `apps/rmbuyer_mobile/lib/features/requirements/presentation/post_requirement_screen.dart` | load/retry/empty states, no default selection, grade integrity |
| `apps/rmbuyer_mobile/lib/features/requirements/presentation/commodity_picker_sheet.dart` | **new**: searchable picker sheet |
| `apps/rmbuyer_mobile/test/support/fake_requirements_repository.dart` | **new**: in-memory repo + production catalogue snapshot (incl. the 2 deactivated duplicates) |
| `apps/rmbuyer_mobile/test/unit/product_master_catalogue_query_test.dart` | **new**: asserts the exact REST request against a loopback fake PostgREST |
| `apps/rmbuyer_mobile/test/widgets/post_requirement_commodity_picker_test.dart` | **new**: 16 picker/selection/submission tests |
| `apps/rmbuyer_mobile/test/unit/requirements_repository_test.dart` | the "returns hardcoded catalogue" test replaced by "fails loudly" + parsing tests |
| `apps/rmbuyer_mobile/test/widgets/post_requirement_screen_test.dart`, `post_requirement_broker_selection_widget_test.dart` | the two submit tests now select a product explicitly (previously relied on the silent default) |

The pre-existing uncommitted TEST-ISOLATION-01 files were preserved unchanged.

## 5. Tests, analysis, build

| Step | Result |
|---|---|
| `flutter analyze` (apps/rmbuyer_mobile) | **No issues found** |
| Targeted: 5 picker-related files | **37/37 passed** |
| Full suite `flutter test` (network guard active; live tests opt-in only) | **183 passed, 4 skipped, 0 failed** (baseline was 164 + 4 skipped) |
| `flutter build apk --debug` | built `apps/rmbuyer_mobile/build/app/outputs/flutter-apk/app-debug.apk` (2026-10-24 20:16) |

Coverage of the sprint checklist:

1. **Correct live source:** the loopback fake-PostgREST test asserts path `/rest/v1/master_commodities`, `select=id,name,code,status`, `status=eq.true`, `order=name.asc…`. This test caught defect #2.
2. **Three products appear:** picker test asserts Yellow Maize (Corn), Sharbati Wheat and Soybean Seed (plus Dal, Rice) are listed.
3. **Duplicates excluded:** `maize` (`97eccc57…`) and `Wheat` (`13a5208a…`) are absent.
4. **Search and selection:** "soy" → Soybean Seed only; "groundnut" → no-match state.
5. **Payload ID:** for each of the three products, the submitted DTO and `toSupabaseInsert()` carry `commodity_id` = `20000000-…0001/0002/0003` and that product's own grade ID. Switching Maize → Wheat submits Wheat's grade.
6. **States:** loading (gated fake), request failure (no stale names, submit blocked) → Retry → loaded, empty catalogue, sheet refresh picking up a newly active product.
7. **Existing behavior:** all prior requirement-creation, broker-selection and repository tests pass.

No test wrote to any backend. The fake repository records submissions in memory.

## 6. Live verification

| Check | How | Result |
|---|---|---|
| Catalogue as the buyer sees it | read-only SQL (`BEGIN READ ONLY`, `SET LOCAL ROLE authenticated` + buyer JWT claims; also `anon`) | 5 active: Dal, Rice, Sharbati Wheat, Soybean Seed, Yellow Maize (Corn). The duplicates are inactive. |
| The exact request the fixed app sends | read-only `GET` to the production REST endpoint with the app's public anon key | same 5 rows, ascending, correct IDs |
| On device (Redmi Note 5 Pro, debug build updated with `adb install -r`) | screenshot only | the new build runs and loads live master data (unit `kg` and Dal's live grade "Moisture" exist only in production tables) |

**Not verified live:**
- I did not open the new picker sheet on the phone myself. While I was testing, the phone was being operated by hand (input history showed touch gestures I did not send), so I stopped interacting with it. The "Dal" visible in my last screenshot was selected by that person, not preselected by the app.
- No requirement was submitted to production, as the sprint instructed. Submission integrity is verified by widget tests only.

## 7. Remaining items / blockers (not changed in this sprint)

There is **no blocker** for this sprint. Out-of-scope observations:

- `getMasterGrades()` still falls back silently to hardcoded grades (`21000000-…0099` doesn't exist live) and also uses `.order('grade_name')`, which is **descending**.
- The unit picker preselects the first live unit, `kg`. Production has two "MT" units (`Tonn` `afd6b4a9…`, `Metric Ton` `22000000-…0001`).
- `SearchRepository.fallbackCommodities` and the home "Browse Commodity Mandi Catalogs" tiles are hardcoded (Mustard Seeds, Chana, Groundnut, "Yellow Soybean"…) and don't match the live catalogue. Tapping one now opens the form with nothing selected and a "not in the current catalogue" hint, rather than preselecting another product.
- Known from PM-05: RMBroker still lists inactive products, and `authenticated` has no SELECT on `master_categories`.
