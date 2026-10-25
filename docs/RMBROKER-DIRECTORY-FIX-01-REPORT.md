# RMBROKER-DIRECTORY-FIX-01 — Directory regression test & fix

**Date:** 2026-10-25 · **Branch:** `feature/broker-nilesh` (uncommitted, not pushed) · **App:** `apps/rmbroker_mobile`

**Result:** both Add Buyer and Add Seller now validate, save and report errors correctly through the path the app actually uses (direct Supabase). The directory list loads every contact the broker is authorised to see. Directory tests 40/40, `flutter analyze` clean, full suite 324 passed / 1 failed (pre-existing, unrelated — see §5).

This sprint continued uncommitted directory work already in the tree from the previous session. That work is listed below as fixes 1–5, re-verified here; fixes 6–7 are new in this session.

---

## 1. How the directory reaches data (verified)

- Every repository call first tries `/api/v1/broker/directory*`. Those route files exist only in `src/app/api/v1/broker/directory/`, and Next ignores `src/app` when a root `app/` exists (`node_modules/next/dist/docs/01-app/03-api-reference/03-file-conventions/src-folder.md:31`). So the REST step **always** fails: in dev with an HTML 404 page, in release with a DNS failure on the placeholder `rmbroker.example.com` (KI-34).
- The real data path is therefore the Supabase fallback: `crm_contacts` filtered by `broker_id = auth.uid()`, with embedded `users` and `companies`.

## 2. Root causes and fixes

| # | Bug (reproducible) | Root cause | Fix |
|---|---|---|---|
| 1 | Duplicate-mobile check never ran; Add Buyer/Seller could create duplicates | `checkDuplicate`/`createContact` sent a top-level `or=(users.mobile.eq…)`. PostgREST rejects it: **HTTP 400 PGRST100** (re-probed live this session). The error was swallowed, so "no duplicate" was assumed | `queryContactsByMobile()` filters the embedded resource (`users.mobile=in.(+91…,…)`); the probe now parses. Creation uses a **strict** check: if the check itself fails, nothing is inserted and the user is told to retry |
| 2 | Any save failure (RLS, network, expired JWT) showed "Backend is offline or endpoint … unavailable" | Direct insert wrapped in `catch (e) {}` falling through to `DirectoryUnavailable` | Specific results: 42501 → "Your account is not permitted to add this contact."; PGRST301/JWT → sign-in again; other → "Could not save the contact…" |
| 3 | A saved contact was reported as failed when the optional note failed; retry then duplicated it | Note insert inside the same try as the contact insert | Note saved separately; its failure is logged only |
| 4 | City/State showed raw UUIDs; search by city name failed; editing could overwrite stored IDs | 14 of 16 live companies store `district_id`/`state_id` as master UUIDs (text columns) | Names resolved from `master_districts`/`master_states` (readable to brokers: 54/38 rows); labels never show a UUID; search uses names; edit saves the stored value back unless the user changed the text |
| 5 | Field errors stayed after the value was corrected; general error persisted after a later success | `copyWith` treated `null` as "keep" | Sentinel `_keep` so `null` clears; also `ref.mounted` guards after async loads |
| 6 | **Add Buyer / Add Seller / Edit crashed (spinner stuck) whenever the API host was reachable** | Next answers the missing route with an HTML 404 → Dio `badResponse` with a **String** body. `dioErr.response?.data?['error']` ran inside the `on DioException` handler; indexing a String throws, and an error thrown in a catch clause escapes the sibling `catch (_)`, so the Supabase path never ran | `_serverError()` reads `error` only from a JSON map; used in create and update |
| 7 | List error states misleading/unsafe | Expired/missing session showed "endpoint pending backend exposure"; DB failures showed raw exception text (`Database query failed: PostgrestException(…)`) | Client without a valid session → `DirectoryUnauthorized`; JWT errors → unauthorized; other failures → plain retry message (details only in `debugPrint`) |

No hardcoded/mock contact fallbacks exist in `lib/features/directory` (grep for mock/demo/sample/fake/seed: none). With no client the list stays an honest "unavailable" state.

## 3. Files changed

| File | Change |
|---|---|
| `lib/features/directory/data/directory_repository.dart` | Fixes 1–4, 6, 7; Supabase calls split into `@visibleForTesting` access points |
| `lib/features/directory/domain/directory_contact.dart` | `cityName`/`stateName`, `cityLabel`/`stateLabel`, `hasLocation`, UUID guard |
| `lib/features/directory/domain/directory_state.dart` | Search on resolved location labels |
| `lib/features/directory/presentation/controllers/contact_form_controller.dart` | Error clearing; stored-location preservation on edit |
| `lib/features/directory/presentation/controllers/directory_controller.dart` | `ref.mounted` guards |
| `lib/features/directory/presentation/widgets/directory_contact_card.dart` | Uses `hasLocation` |
| `test/features/directory/directory_regression_test.dart` (new) | 21 regression tests |
| `docs/KNOWN-ISSUES-AND-DECISIONS.md` | Added KI-44, KI-45 |

No schema, RLS, policy, auth or unrelated-feature changes.

## 4. Verification actually performed

### Live database (read-only transactions, counts only, no rows written)
- Live `crm_contacts`: 12 rows (7 buyer, 5 seller); 0 orphan users; 0 duplicate broker↔user links; 0 duplicate mobiles.
- Simulated broker (`SET LOCAL ROLE authenticated` + JWT claims): 10 CRM rows, **all 10** with readable user and company (6 buyers, 4 sellers); **0** buyer/seller users visible to the broker that are missing from its directory. So the query returns the complete authorised set.
- RLS permits the create path: `companies`/`users` INSERT allowed for brokers when `created_by` is null or `auth.uid()` (column default `auth.uid()`), users limited to role buyer/seller; the new rows are then readable via `created_by = auth.uid()`; `crm_contacts` INSERT requires `broker_id = auth.uid()`.
- PostgREST probe (anon key): old `or=` filter → 400 PGRST100; new embedded `in` filter → parses (401 permission denied without a session, as expected).

### Automated tests
| Area | Buyer | Seller |
|---|---|---|
| Valid create saves with its own role (`buyer`/`seller`) and `+91` mobile | ✅ | ✅ |
| HTML 404 from REST → falls back and saves (fix 6; **failed before the fix**) | ✅ | ✅ |
| Duplicate mobile blocks creation; both stored formats queried | ✅ | ✅ (shared path) |
| Duplicate-check failure → nothing created, explicit error | ✅ | shared path |
| RLS 42501 / expired JWT / network errors mapped | ✅ | ✅ |
| Note failure doesn't fail a saved contact; note trimmed | ✅ | ✅ |
| Rapid double submit creates one contact | ✅ | shared path |
| Field errors clear; failed submit then success clears error | ✅ | ✅ (seller role kept) |

List: no-session client → unauthorized; no client → unavailable; resolved locations shown and searchable, UUIDs never shown; existing screen tests (tabs, search, KPI, FAB opens form, empty/unavailable states, 360×640 layout) pass.

- `flutter test test/features/directory` → **40/40 passed**
- `flutter analyze` → **No issues found**
- `flutter test` (full) → **324 passed, 1 failed** (§5)

### Not performed
- **No live end-to-end create** on a device: the only database is production and the sprint forbids test records there. Persistence after refresh/navigation is covered by code path (form success triggers `loadContacts(isRefresh: true)`, which re-reads from `crm_contacts`) and the RLS check above, not by a live write.
- No release build was run (debug analysis and tests only).

## 5. Unresolved / blockers
1. **KI-45 (pre-existing, unrelated):** `broadcast_history_test.dart` "Recording a newly sent broadcast prepends it immediately" fails before 14:45 local time — the seeded fixture has a 14:45 broadcast *today* that sorts ahead of the new one. No broadcast code was touched.
2. **KI-44:** the directory REST routes are unserved (`src/app` ignored). The app works through Supabase, but each call still costs a failed request first (KI-40). Moving/merging routes is a backend decision outside this sprint.
3. **No pagination:** the directory loads all of the broker's contacts in one query (10 today). Fine at current volume; paging would be needed in the hundreds+.
4. **KI-41** (toggle-status contract mismatch) unchanged; status toggle uses the Supabase fallback.
5. RB-SEC-PRIV-02 items (brokers can link any company via `crm_contacts.company_id`; trust fields unconstrained on insert) still await owner decisions D1–D7 — not changed here.
