# RB-SELLER-ADDRESS-PIN-COVERAGE-01 — National District Coverage & Device Verification

**Date:** 2026-10-28 · **App:** RMSeller (`apps/rmseller_mobile`) · **Branch:** `feature/broker-nilesh` (uncommitted)

**Production statement:** production data and schema were **not modified**. The only contact with the production project was read-only `GET` requests to the publicly readable `master_states` / `master_districts` tables using the app's public anon key. No migration was applied and no profile was saved.

| Phase | Status |
|---|---|
| 1. Audit | ✅ Done |
| 2. National coverage (data + migration) | ✅ Prepared and tested. ⛔ Not applied (needs approval) |
| 3. Automated tests | ✅ Pass. No new regressions |
| 4. Dedicated test account | ⛔ BLOCKED: no isolated environment exists |
| 5. Device / OCR / screenshots / save–reopen | ⛔ BLOCKED (gated on Phase 4; ADB input disabled; device in use) |
| 6. Regression + report | ✅ Done |

## Phase 1 — Baseline audit

### Postal reference data

| Item | Finding |
|---|---|
| Original app dataset (before RB-SELLER-ADDRESS-PIN-FIX-01) | Hand-written 3-digit-prefix table, about 120 prefixes. Not a postal dataset. |
| Current app dataset | `lib/features/profile/data/india_pincode_data.dart`, generated from the India Post *All India Pincode Directory* (data.gov.in, GODL-India). |
| Source version | Mirror `github.com/dropdevrahul/pincodes-india` `pincode.csv`, **last updated 2024-06-30**, retrieved 2026-10-28. The earlier report gave only the retrieval date; this report corrects it. |
| Source columns | CircleName, RegionName, DivisionName, OfficeName, Pincode, OfficeType, Delivery, District, StateName, Lat/Long. **There are no district codes**, so source names are the only identifiers. |
| Rows | 157,126 post offices. 0 malformed. 0 unknown state names. |

### Live database (read-only snapshot, 2026-10-28)

**`master_states`:** 38 rows covering all 36 official codes.
- **Duplicates:** Rajasthan (`a55c1bb2…` seed + `10000000-…01` demo) and Madhya Pradesh (`de3acb34…` seed + `10000000-…02` demo).
- **Origin of the duplicates:** `seed_broker_demo_dataset.sql`.

**`master_districts`:** 54 rows.
- **Rajasthan:** 50 under the seed row + 3 under the demo row.
- **Madhya Pradesh:** 1 (Ujjain, demo row).
- **All other 34 states/UTs:** none.

**Schema:** `master_districts(id, name, state_id → master_states)`. There is no unique constraint on name. `availabilities.district_id` is a foreign key to it.

**Dropdowns before FIX-01:** a hard-coded fallback list of 4 states / 15 "districts" was used. Unmatched values defaulted to the first item. `initialValue` didn't refresh after programmatic changes. *(Fixed in FIX-01.)*

## Phase 2 — National coverage

### Coverage from the dataset (computed, not inferred)

| Metric | Value |
|---|---|
| States/UTs with districts | **36 / 36** |
| Districts | **737** |
| PIN codes | **19,300** |
| PINs mapping to more than one district | **1,168** (returned as candidates, never auto-picked) |
| PINs listed under more than one state | **46** (source inconsistencies, mostly Telangana/Andhra Pradesh, e.g. `503145` Kamareddy TG / Vizianagaram AP). Neither state nor district is resolved; the PIN is flagged for review. |
| District spelling variants merged | 0 |
| Near-identical names (edit distance ≤ 2) | 40 pairs, **all genuinely distinct districts** (East/West Godavari, Udaipur/Jaipur, …). None merged. |

Districts and PINs by state:

| Code | Districts | PINs | Code | Districts | PINs | Code | Districts | PINs |
|---|---|---|---|---|---|---|---|---|
| AN | 3 | 22 | HP | 12 | 436 | OR | 30 | 935 |
| AP | 13 | 1243 | JK | 20 | 196 | PY | 4 | 33 |
| AR | 25 | 49 | JH | 24 | 381 | PB | 23 | 534 |
| AS | 33 | 574 | KA | 30 | 1347 | RJ | 33 | 1004 |
| BR | 38 | 857 | KL | 14 | 1425 | SK | 4 | 19 |
| CH | 1 | 25 | LA | 2 | 16 | TN | 38 | 2040 |
| CT | 28 | 274 | LD | 1 | 9 | TG | 33 | 676 |
| DN | 3 | 10 | MP | 52 | 770 | TR | 8 | 80 |
| DL | 11 | 97 | MH | 36 | 1585 | UP | 75 | 1655 |
| GA | 2 | 88 | MN | 16 | 52 | UT | 13 | 302 |
| GJ | 33 | 1010 | ML | 11 | 69 | WB | 23 | 1128 |
| HR | 22 | 315 | MZ | 11 | 47 | | | |
| | | | NL | 12 | 43 | | | |

### Reconciliation with the live master

- **Already live:** 34 postal districts are already in the live master. One of these is matched through the audited alias India Post **"Ganganagar" = Rajasthan "Sri Ganganagar"**, which the app also applies via `IndiaPinCodeDirectory.districtKey`.
- **Live names absent from postal data:** 18 live Rajasthan districts have no India Post equivalent. They are the 2023 administrative districts (Anoopgarh, Balotra, Beawar, Deeg, Didwana-Kuchaman, Dudu, Gangapur City, Jaipur Rural, Jodhpur Rural, Kekri, Khairthal-Tijara, Kotputli-Behror, Neem Ka Thana, Phalodi, Salumbar, Sanchore, Shahpura) plus "Sri Ganganagar" (aliased). They are **kept untouched**. Some of these were reportedly abolished in Dec 2024; that is a separate data-owner decision.
- **To insert:** **703** new districts across all 36 states/UTs.
- **India Post vs administrative names:** India Post names lag administrative changes. For example, Andhra Pradesh has 13 postal districts, while the state now has 26 administrative districts. The bundle preserves the source spelling (e.g. "Ahmadabad", "Pondicherry", "Visakhapatanam").

### Migration (prepared, NOT applied)

| File | Purpose |
|---|---|
| `supabase/proposed/0052_seed_national_districts.sql` | Inserts the 703 districts. IDs are deterministic UUIDv5 (namespace `b7e1c3a2-52d4-5c6e-9f10-2a6b8d4e0c01`, name `'<CODE>\|<normalised name>'`). The state is resolved by code to the non-demo `master_states` row. A district is skipped if the same normalised name exists under that code; `ON CONFLICT (id) DO NOTHING`. Never updates or deletes. |
| `supabase/proposed/rollback_0052.sql` | Deletes exactly those 703 deterministic IDs. It fails, deleting nothing, if any of them is referenced by a foreign key. |
| `supabase/proposed/0052_tools/coverage.mjs` | Regenerates the coverage report, migration and rollback from the CSV + live snapshot. |
| `supabase/proposed/0052_tools/migration_test.mjs` | Safe-database test (below). |
| `supabase/proposed/0052_tools/coverage_report.json` | Machine-readable coverage figures. |

## Phase 3 — Automated tests

### Migration test in a safe database

The database was PGlite 0.2.17 (in-process Postgres, in memory, no network), seeded with the live 38 states + 54 districts. **13 / 13 checks passed**:

- **Apply and re-apply:** the first apply adds 703 rows (54 → 757). Existing rows are byte-identical. A second apply is a no-op.
- **Integrity:** all 36 states/UTs have districts. No new row is attached to a demo state row. There is no duplicate (state code, normalised name).
- **Spot checks:** UP Kaushambi and MP Indore are present. RJ Jaipur is not duplicated. RJ "Ganganagar" is not inserted.
- **Rollback:** rollback is refused (FK) while a new district is referenced, and nothing is deleted. Rollback then restores the exact original 54 rows, and a second rollback is a no-op.

### Dart tests

New file **`test/unit/national_pin_coverage_test.dart` (42 tests)**:
- **Coverage:** 36 states/UTs; all 737 districts linked to a valid state.
- **Representative PINs:** one verified PIN per state/UT (36 tests), including Rajasthan 302019 → Jaipur, Uttar Pradesh 212201 → Kaushambi, Madhya Pradesh 462001 → Bhopal, and Delhi 110006 / Manipur 795001 as multi-district.
- **Hindi labels:** a Hindi label exists for every state/UT.
- **Cross-state PIN:** 503145 is unresolved and flagged.
- **Alias:** Ganganagar alias, and "Central" kept as a real Delhi district.
- **No PIN on the invoice:** an invoice without a PIN leaves the saved state/district/PIN unchanged.

Already in place from FIX-01:
- `address_pin_mapping_test.dart` (12): missing, malformed, unknown, conflicting and ambiguous PINs; English/Hindi addresses; buyer block first.
- `seller_profile_pin_location_test.dart` (3): the dropdowns refresh after a PIN; an unmatched district stays empty with a review notice; addresses wrap.
- The updated `seller_profile_menu_test` check that the district dropdown refreshes after a state change.

### Regression (full RMSeller `test/unit` + `test/widgets`; `test/realdb` excluded because it uses the live DB)

| Run | Passed | Failed |
|---|---|---|
| Unmodified HEAD (`git stash -u`) | 399 | 16 |
| This branch | **479** | **16** |
| **New regressions** | — | **0** (identical failing set) |

The 16 pre-existing failures are unchanged and are not reclassified. They include the 5 `seller_profile_menu_test` "RB-SELLER-PROFILE-02" tests. The exact lists are in session scratchpad files `coverage/fail_head.txt` and `coverage/fail_now.txt`.

`flutter analyze` on the changed code: no issues.

## Phase 4 — Dedicated test account: BLOCKED

- **No isolated environment:** the project has **one Supabase project, and it is production**; there is no staging or test tenant. A dedicated account would therefore still write to production `users` / `companies` rows.
- **No account created:** creating a test user or changing permissions needs your explicit approval, so none was created.
- **`harishanker` not used:** per instruction, it is a real working profile.

To unblock, choose one of:
- **Option A:** approve a staging Supabase project and point a debug build at it.
- **Option B:** approve one clearly-labelled test seller in production, accepting that its rows are production rows.

## Phase 5 — Device verification: BLOCKED

| Step | Status | Evidence |
|---|---|---|
| Device available | ✅ | `e0d9da95`, Redmi Note 5 Pro (whyred) |
| ADB input works | ⛔ | `persist.security.adbinput = 0`. MIUI *USB debugging (Security settings)* is off and can only be enabled on the phone by its owner. |
| Device free to use | ⛔ | The phone was touched 4.7 s before the check, so it was in active use. |
| Final debug APK built | ✅ | `build/app/outputs/flutter-apk/app-debug.apk`, 256,970,028 bytes, SHA-256 `E8D978F6…D142B72F`. No probe or debug-logging code remains (`TEMP-OCR-VERIFY` / `RAW_OCR_BEGIN` search finds nothing; `tool/ocr_probe_main.dart` was removed). **Not installed** this run. |
| Screenshots 01–06 | ⛔ | Not captured. This phase is gated on Phase 4, and the device can't be driven. |
| Save / reopen | ⛔ | No dedicated test account. |
| Genuine OCR on the Siyaram invoice | ✅ (earlier, RB-SELLER-OCR-AUTO-VERIFY-01) | On-device ML Kit output, stored verbatim as `test/unit/siyaram_real_ocr_supplier_test.dart`. It passes with the final code. |

## Remaining limitations

- **District names:** India Post districts are postal names, not LGD administrative districts, and have no district codes. LGD (Local Government Directory) data would be the authoritative administrative source if exact administrative names or codes are needed.
- **Snapshot age:** the data is a June 2024 snapshot. Refreshing it needs the official data.gov.in API key or download. Regenerating the bundle and migration is scripted.
- **Hindi district names:** not available. State labels are bilingual.
- **Duplicate state rows:** the duplicate Rajasthan / Madhya Pradesh rows remain. The app merges them in its dropdown; removing them needs an FK audit and owner approval.

## Approvals needed

1. Apply `0052_seed_national_districts.sql` to production. A rollback file is provided, and the migration was tested in an isolated database.
2. Provide a test environment or approve a test account (Phase 4, option A or B).
3. On the phone, enable *Developer options → USB debugging (Security settings)* and leave the phone idle during the run (Phase 5).
