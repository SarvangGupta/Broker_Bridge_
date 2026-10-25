# RMBROKER-DIRECTORY-SCALE-01 — Working directory routes + paginated listing

**Date:** 2026-10-25 · **Branch:** `feature/broker-nilesh` (uncommitted, not pushed; the route move is staged as `git mv` renames) · **Builds on:** RMBROKER-DIRECTORY-FIX-01 (also uncommitted, preserved)

**Result:**
- The directory API routes are now served and answer JSON.
- Buyer and seller lists page with keyset cursors, on both the API path and the direct-Supabase path. In the tests and the live read-only check, no contact was omitted or repeated.
- The time-dependent broadcast test is fixed in the test only.
- Results: RMBroker full suite **357/357**, `flutter analyze` clean, **release APK builds**.

---

## 1. Root causes

| # | Problem | Root cause |
|---|---|---|
| 1 | Every directory API call failed first (HTML 404) | The routes were in `src/app/api/v1/broker/directory/`. Next ignores `src/app` when a root `app/` exists (`node_modules/next/dist/docs/01-app/03-api-reference/03-file-conventions/src-folder.md:31`), and this repo has a root `app/` |
| 2 | Status toggle always failed first, even with routes served | App called `POST …/toggle-status`; server route is `PATCH …/status` (KI-41) |
| 3 | **API create skipped the duplicate check for the app** | `createBrokerContactAction` called `checkContactDuplicateAction` without the Bearer token. With no cookie session the check saw no session and returned "not a duplicate" |
| 4 | Enabling the routes would have logged brokers out | (a) The stored API token is saved at sign-in but never refreshed, while Supabase refreshes its own session. After expiry the API answers 401, and `AuthInterceptor` then **clears secure storage** (including the stored role). (b) The routes answered **401** for permission errors on a single contact ("Unauthorized: You do not have permission…"), which would trigger the same wipe |
| 5 | Raw DB/Zod error text reached the app | Action catch blocks returned `error.message` |
| 6 | Unpaged list; silently truncated at scale | The server listed all contacts and ran 3 count queries **per contact**. The direct path made one unbounded PostgREST query, which Supabase caps at 1000 rows, so contacts past 1000 were silently dropped. Filters and search ran on the whole list in memory |
| 7 | Broadcast-history test failed before 14:45 | The seeded fixture has a broadcast at 14:45 *today*. The test stamped its new send with `DateTime.now()`, which before 14:45 is older than that seed and correctly sorts below it. The repository's newest-first ordering is correct |

## 2. Changes

### Server (Next.js)
- **Routes moved** (`git mv`) to `app/api/v1/broker/directory/{route.ts, check-duplicate/, [id]/, [id]/status/}`, following the root `app/api` convention. Imports were unchanged (`@/src/server/...`).
- **New `src/server/utils/broker-directory-query.ts`.** It is a plain module, because `'use server'` files may export only async functions. It contains:
  - `queryDirectoryPage`: role, status and search filters run in SQL (search covers name, company, email, mobile digits, and the city/state label resolved through the master tables, never the raw UUID). It uses keyset order `(created_at, id) DESC` with `limit + 1` to detect more rows. The cursor text keeps full microsecond precision (`created_at::text`).
  - `queryDirectoryStats`: one aggregate query over **all** of the broker's contacts, with the same definitions as before.
  - Cursor encode/decode with strict validation, limit clamping (1–100), LIKE-pattern escaping, `publicDirectoryError` (passes Zod messages through, otherwise a generic message), and `directoryErrorStatus`, which maps only a missing session to 401 and permission errors to 403.
- **`getBrokerDirectoryContactsAction`.**
  - New optional `limit`/`cursor` arguments, and a `pageInfo { hasMore, nextCursor }` field in the response.
  - Without `limit` it still returns the full list, so the web workspace is unchanged apart from a guard for optional `stats`.
  - Mandate counts are 3 grouped queries per page instead of 3 per contact.
  - `stats` is sent with the first page only.
  - **Access scoping is unchanged:** `broker_id = broker` for brokers, everything for admins.
- **Create** passes `authToken` to the duplicate check (fix 3). Create and update return sanitized errors (fix 5).
- **Routes** use `directoryErrorStatus`. Server errors (500) are logged and return a generic message. An invalid cursor returns 400.

### App (Flutter, `apps/rmbroker_mobile`)
- **Repository** (`directory_repository.dart`):
  - `getContacts(..., limit, cursor)` returns `DirectoryListPayload { contacts, stats?, hasMore, nextCursor }`. `limit: null` keeps the full list; broadcast recipient selection relies on that.
  - **API path:** sends `limit`/`cursor`, parses `pageInfo`, and resolves location names. `hasMore` with an unusable cursor is treated as the end of the list. A server without paging returns one complete page.
  - **Direct path:** keyset query (`created_at`, `id` desc), with role pushed down via `users!inner` (anything but `seller` counts as a buyer, matching `ContactRole.fromString`). Status and search, which span users and companies and which PostgREST cannot OR across, are applied with the same predicate as the screen. Each call stops after at most 5 requests; the cursor is always the last row **scanned**, so a sparse search continues without gaps. Full scans read in 500-row chunks, which removes the 1000-row truncation. Stats come from a light projection read in 1000-row chunks, on the first page only. Mandate counts are fetched per page.
  - **Token sync (fix 4a):** before any directory API call, the stored bearer is updated from the current Supabase session. Without a valid session the API call is skipped and the result is "sign in again". The login, session and interceptor code is unchanged.
  - **Toggle** uses `PATCH …/status` (fix 2). A **409** from create keeps the duplicate flag, so the form shows a duplicate warning. API JSON errors (403/404) on update, toggle and details are reported instead of falling back. Location names are resolved on the details screen too.
- **`DirectoryCursor`** (`<created_at>|<id>`, the same wire format as the server, so either path can continue a list started by the other), plus `MandateCounts`.
- **`DirectoryContact.matchesFilters`:** one predicate shared by the screen and the paged scan, mirrored by the server SQL.
- **Controller:**
  - The first page loads with the current tab, status and search.
  - `loadMore()` appends and de-duplicates by id.
  - A tab or status change reloads; search reloads after a 350 ms debounce.
  - A generation counter drops responses for outdated filters.
  - Toggling a contact adjusts the stats for that one contact.
- **State:** adds `hasMore`, `nextCursor`, `isLoadingMore` and `loadMoreError`.
- **Screen:**
  - A footer row loads the next page when it scrolls into view, or shows Retry if that page failed; the loaded rows stay.
  - When a filtered page is empty but more rows remain, the screen keeps loading instead of showing "No results".

### Tests
- New `test/features/directory/directory_pagination_test.dart` (32 tests):
  - **Cursor:** round-trip, malformed values rejected, and an invalid cursor is an error rather than a silent restart.
  - **Direct path:** page sizes 1/3/4/10/11 concatenate to the full ordered list. An exact multiple of the page size ends without an extra page. Rows with the same `created_at` are split by id. Role tabs are pushed down. Inactive, sparse-search and combined filters omit nothing. A contact added between pages causes no shift. Stats cover all contacts and are fetched once. Mandate counts are attached per page. The full list with 1201 rows passes the 1000-row cap.
  - **API path:** page params sent and `pageInfo`/stats parsed. A later page carries no stats. `hasMore` with an unusable cursor counts as the end. A server without paging works. 401 maps to unauthorized. Create 201 does no second insert. A 409 keeps the duplicate flag with no fallback. A check-duplicate hit blocks the save. A 400 message is shown as sent. Update succeeds, and a 403 is reported. Toggle uses `PATCH …/status`. Details never show raw UUID locations.
  - **PostgREST query shape:** URLs captured by a loopback HTTP server assert `users.or`, the keyset `or`, `order`, `limit` and `!inner`.
  - **Controller:** first page plus `loadMore` to the end exactly once. A tab change drops the stale response. Search reloads after the debounce and finds a row outside the first page. A failed later page keeps the rows, and Retry completes the list.
- **Mutation check:** making the cursor point at the first scanned row instead of the last makes **11** of these tests fail (code restored and re-verified).
- Mock signatures were updated in `directory_screen_test.dart`, `directory_regression_test.dart` and `market_price_broadcast_test.dart`.
- **Broadcast fix (test-only)** in `broadcast_history_test.dart`: the new send is stamped one minute after the latest seeded record. No broadcast code was changed. The test passed at 12:46, inside the window where it failed before.

## 3. Verification actually performed

| Check | Result |
|---|---|
| Next dev server, each route without a token | All JSON. List, create, details, update and status → **401** JSON. `cursor=bad` → **400** "Invalid page cursor". Check-duplicate → 200 `{"isDuplicate":false}`. The old `…/toggle-status` path → HTML 404 (no longer used by the app) |
| Server SQL against live DB inside `BEGIN READ ONLY` (`transaction_read_only: on`, counts only) | For both brokers (10 and 2 contacts), **every** combination of role × status × 6 search terms (including `50_%` for escaping) × page sizes 1/2/3 matched the unpaged result exactly, with no duplicates. Stats: 10 contacts, 6 active buyers, 4 active sellers, 21 mandates. Admin scope: 12 |
| Live PostgREST parse probe (anon key) of the app's new query shapes | buyer keyset, seller, stats and deals `in` → 401/42501 (parsed). Known-bad control → 400 PGRST100 |
| `flutter test test/features/directory` | **72/72** |
| `flutter test` (full RMBroker) | **357/357** (the KI-45 failure is gone) |
| `flutter analyze` | No issues |
| `flutter build apk --release` | Built `app-release.apk` (63.1 MB) |
| `tsc --noEmit` | No errors in touched files. The project has 3 errors, all in untouched files (`src/server/actions/broker-buyer-actions.ts` ×2, `scripts/test-proposal-api.ts`) |
| ESLint on touched web files | 0 errors. 23 warnings, all existing patterns (`any` in catch, unused imports) |

**Not performed:**
- **No authenticated end-to-end API call.** That needs a broker session. The only known credentials are the exposed test passwords from SEC-PRIV-01, which I deliberately did not use. No records were created anywhere.
- The direct path's role push-down was checked for syntax on live PostgREST and for semantics in unit tests, but not live under a broker JWT.
- `next build` was not run; the 3 pre-existing TypeScript errors would fail it.
- The live data has 0 inactive contacts, so the inactive filter's paging is exercised live only trivially and covered by unit tests.

## 4. Remaining blockers / notes
1. **Release API URL is still the placeholder** `https://rmbroker.example.com/api/v1` (KI-34). Release builds still make one failed request per directory call, then use the direct path, which now pages correctly. Removing it needs a real deployment URL (owner decision).
2. **Pre-existing TypeScript errors** in `broker-buyer-actions.ts` block `next build`; that's outside this sprint.
3. **Other `src/app` routes are still unserved** (`api/cron/monitor-dispatches`, `api/v1/requirements/sync`, `api/v1/broker/requirements/[id]/proposal`, `(buyer)/buyer/proposals`). Their callers and owners weren't in scope, so they were not moved. See KI-44.
4. **Contacts created through the API** get `created_by = NULL`: Drizzle runs as `postgres`, and `schema.ts` has no `created_by`. The broker still sees the contact through its `crm_contacts` link. Setting it explicitly would need a Drizzle schema-mapping change (not done; RB-SEC-PRIV-02 context).
5. **Search scanning on the direct path** is bounded per call (5 requests) and continues through "load more". The API path filters in SQL. A database-side search would need an RPC or view, which counts as a schema change and is out of scope.
6. Server role semantics now use `trim()`, matching the app. The web directory's search additionally matches state and resolved master names.
7. Other app features using `ApiClient` have the same stale-token risk (4a) once their routes exist; only the directory syncs the token today.
