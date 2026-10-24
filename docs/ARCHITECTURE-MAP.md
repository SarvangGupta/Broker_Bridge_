# RMBroker — Architecture Map

Baseline: HEAD `390fd84`, 2026-10-24. Paths relative to `apps/rmbroker_mobile/`.

## 1. Entry points

| Item | File | Notes |
|---|---|---|
| `main()` | [lib/main.dart](../apps/rmbroker_mobile/lib/main.dart) | `Supabase.initialize(url, publishableKey)` (errors only `debugPrint`ed), then `ProviderScope(RMBrokerApp)` |
| App widget | [lib/app/app.dart](../apps/rmbroker_mobile/lib/app/app.dart) | `MaterialApp.router` with `AppRouter.router` + theme |
| Config | [lib/core/config/app_config.dart](../apps/rmbroker_mobile/lib/core/config/app_config.dart) | `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `API_BASE_URL` via `--dart-define`; defaults compiled in. Debug API = `http://localhost:3001/api/v1`; **release API = placeholder `https://rmbroker.example.com/api/v1`** |

## 2. Navigation ([app_router.dart](../apps/rmbroker_mobile/lib/app/router/app_router.dart))

- `/` Splash → `checkSession()` → `/work` (authenticated) | `/login` | `/access-denied`.
- `StatefulShellRoute.indexedStack` with 5 branches: `/dashboard`, `/work?tab&status&requirementId`, `/deals?filter`, `/directory`, `/more`.
- Root-level routes: `/deals/:id`, `/requirements/:id`, `/search?q&entity`, `/commission`, `/invoices[/:id]`, `/tasks[/:id]`, `/notifications`, `/settings`, `/profile`, `/broadcast/market-price`, `/broadcast/history[/:id]`.
- Placeholders: `/orders` (RB-LOG-01), `/disputes` (RB-DIS-01).
- Legacy redirects: `/buyer/requirements[/:id]`.
- **There is no global `redirect` auth guard.** Routes commented "(Protected)" rely on each repository returning Unauthorized. Deep links reach screens without a session check.
- Splash lands on `/work`, not `/dashboard`.

## 3. Layers and dependency flow

```
Screen (ConsumerWidget)
  └─ Riverpod Notifier (presentation/controllers)
       └─ Repository (data/)
            ├─ 1) ApiClient (Dio + AuthInterceptor) → Next.js /api/v1/broker/...   [mostly 404 / unreachable]
            ├─ 2) Supabase.instance.client.from(table)...  (user JWT, RLS-enforced) [actual production path]
            └─ 3) In-memory seeded demo store / ContractPending notice           [fallback; some modules merge it always]
       └─ Domain models (domain/) — fromJson + status enums
```

- Repositories are created directly (`DealRepository()`) or via simple `Provider`s; the Supabase client is resolved lazily from `Supabase.instance`. Constructors accept an optional `SupabaseClient`/`ApiClient` for tests. Tests only ever inject the `ApiClient`.
- Exceptions to the pattern:
  - `InvoiceRepository` has no Supabase path at all (REST → memory).
  - `BroadcastHistoryRepository` persists to local secure storage and generates default history.
  - `ProfileRepository` keeps some profile fields in local storage (`localExtras`).
- Domain objects are flattened from PostgREST embeds inside the repositories (no DTO layer).

## 4. Authentication and session

- [auth_repository.dart](../apps/rmbroker_mobile/lib/features/authentication/data/auth_repository.dart): `signInWithPassword`, then looks up `public.users`. It selects **`full_name`, which does not exist in the schema (`name`)**; the error is swallowed, so the role comes from JWT `user_metadata`. Only `broker`/`admin` is allowed in; otherwise it signs out and shows Access Denied.
- Tokens, role, and user info are stored in `flutter_secure_storage` ([secure_storage_service.dart](../apps/rmbroker_mobile/lib/core/security/secure_storage_service.dart)).
- `checkSession()` trusts the stored role or `user_metadata.role`. If there is no Supabase session, it accepts any stored token with a broker role, without checking expiry.
- `AuthInterceptor` adds the Bearer token to Dio calls; on a 401 it clears storage and calls `onSessionExpired`, but **no caller passes `onSessionExpired`**, so nothing navigates to login.

## 5. State management

Riverpod 3 `Notifier`/`NotifierProvider` per feature (dashboard, deals, allocations, deal detail, requirements, offers, matches, directory, contact form/details, notifications, tasks, commission, invoices, search, settings). Filters (`presetFilter`, `statusFilter`, search) are applied **client-side** to fully loaded lists.

## 6. API and backend layers

- **Next.js REST** (`src/app/api/v1/broker/`). The only routes that exist are `directory` (GET/POST), `directory/check-duplicate` (POST), `directory/[id]` (GET/PUT), `directory/[id]/status` (PATCH), and `requirements/[id]/proposal` (GET/POST). They validate the Bearer token via `supabase.auth.getUser` and use Drizzle/Postgres with code-level ownership checks. The app calls `directory/:id/toggle-status` (POST), which does not match the server route.
- **Supabase PostgREST** is the primary data path. RPC used by the buyer app is `notify_requirement_brokers` (0040); RMBroker makes no `.rpc()` calls.
- No Edge Functions referenced. Realtime: `notification_repository` holds a `RealtimeChannel` field (0008 enables realtime on deals/quotations).

## 7. Shared UI / design system

`lib/app/theme/` (`AppColors`, `AppTheme`, `AppTypography`). `lib/core/widgets/` (button, card, empty/error/loading states, text field, confirmation dialog, status badge, module placeholder). Dashboard widgets: header (static `LIVE` badge), welcome banner, KPI grid (8 cards), quick actions (6), recent activity.

## 8. Caching, offline, local storage

- No offline persistence of business data. Data is held in Riverpod state and re-fetched on refresh.
- **Static/in-memory seeded stores:** `CommissionRepository._cachedRecords` (static, 6 demo deals), `NotificationRepository._cachedNotifications` (7 demo), `TaskRepository._cachedTasks` (6 demo), `InvoiceRepository._cachedInvoices` (demo). Also broadcast history in secure storage.
- App settings are kept in [app_settings_provider.dart](../apps/rmbroker_mobile/lib/core/preferences/app_settings_provider.dart).

## 9. Logging and diagnostics

`debugPrint` only. Raw `PostgrestException` messages and exception `toString()` reach UI error text (e.g. "Database permission or query error: … (code: 42501)"). No crash reporting or analytics.

## 10. Architectural inconsistencies (document, do not refactor during discovery)

1. Dual data path (REST-first, then Supabase) everywhere, though about 28 of 30 REST endpoints don't exist. In release builds every call first hits a placeholder host.
2. Multi-table writes done as sequential client calls (no transaction or RPC), so partial failure leaves orphaned rows.
3. Demo data mixed into production repositories.
4. Status vocabularies differ between DB strings, Dart enums, dashboard predicates, and the web platform.
5. There are two schema sources: Drizzle `schema.ts` has columns, such as `broker_id` on requirements/availabilities, that no numbered SQL migration creates.
