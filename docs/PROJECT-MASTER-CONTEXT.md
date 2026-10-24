# RMBroker — Project Master Context

**Scope:** RMBroker Flutter app (`apps/rmbroker_mobile`) and the parts of the shared Supabase/Next.js backend it depends on.
**Baseline:** branch `feature/broker-nilesh`, HEAD `390fd84` (RB-UI-DASH-01), discovery date 2026-10-24.
**Companion docs:** [ARCHITECTURE-MAP.md](ARCHITECTURE-MAP.md) · [DATABASE-AND-API-MAP.md](DATABASE-AND-API-MAP.md) · [FEATURE-STATUS-REGISTER.md](FEATURE-STATUS-REGISTER.md) · [KNOWN-ISSUES-AND-DECISIONS.md](KNOWN-ISSUES-AND-DECISIONS.md) · [PROJECT-DISCOVERY-REPORT.md](PROJECT-DISCOVERY-REPORT.md)

> Read this file first in every session. Verify against code before trusting it. Update it when status, contracts, or rules change.

---

## 1. Product overview

RMBroker is the broker-facing mobile app of the BrokerBridge commodity brokerage platform (Indian mandi trading). Brokers manage buyer requirements, seller offer lots, allocations, deals/negotiations, commissions, a contact directory, tasks, notifications, and market price broadcasts.

Sibling apps live in the same repo, but each is a separate Flutter project with its own code: `apps/rmbuyer_mobile`, `apps/rmseller_mobile`. The Next.js web platform at the repo root (BrokerBridge Enterprise, plus an unrelated VetKind module) shares the same Supabase database.

## 2. Repository structure (relevant parts)

| Path | What it is |
|---|---|
| `apps/rmbroker_mobile/` | **RMBroker Flutter app** (this project's focus) |
| `apps/rmbuyer_mobile/`, `apps/rmseller_mobile/` | Sibling Flutter apps (not inspected in depth) |
| `src/server/db/schema.ts` | Drizzle schema — the most complete schema definition in the repo |
| `supabase/migrations/` | SQL migrations 0001–0041 + `manual_*` + `rollback_*` files |
| `supabase/seed_broker_demo_dataset.sql` | Demo seed (do not run without approval) |
| `src/app/api/v1/broker/` | Next.js REST routes for brokers (only directory + requirement proposal exist) |
| `app/`, `src/` | Next.js 16.3 web platform |
| `docs/` | PRDs, sprint reports, these context documents |
| `project-audit/`, `ARCHITECTURE.md`, `PROJECTSTATE.MD` | Older web-platform-centric audits (2026-10-14/17); predate most RMBroker work |

## 3. Technology stack

- **Flutter** 3.47.6 (stable), **Dart** 3.13.5 (SDK at `D:\flutter_sdk\flutter`, not on PATH). JDK 17.
- Packages: `flutter_riverpod` 3.x, `go_router` 18.x, `supabase_flutter` 2.18, `dio` 5.x, `flutter_secure_storage` 11.x, `intl`, `lucide_icons_flutter`, `url_launcher`.
- Android: `applicationId com.brokerbridge.rmbroker_mobile`; release build is **signed with the debug key**.
- Backend: Supabase (Postgres + Auth + PostgREST), project ref `imztlkvkxzeaekxvmcfe`. Next.js 16.3 / Drizzle ORM for the web platform.
- No CI/CD pipeline in the repo (no `.github/`). `vercel.json` defines one cron (`/api/cron/monitor-dispatches`) for the web app.

## 4. Architecture in one paragraph

Feature-first Flutter app: `lib/features/<feature>/{data,domain,presentation}`. Riverpod `Notifier` controllers call repositories. Each repository **first tries a Next.js REST endpoint** (`AppConfig.apiBaseUrl` + `/broker/...`). On any failure other than 401, it **falls back to direct Supabase PostgREST queries** made with the user's session; RLS is the only server-side authorization on that path. Some repositories also keep **in-memory seeded demo data** that is merged into, or substituted for, real data. Navigation is a single GoRouter with a 5-tab `StatefulShellRoute` (Home, Work Desk, Deals, Directory, More). See [ARCHITECTURE-MAP.md](ARCHITECTURE-MAP.md).

## 5. Feature inventory (summary — details in the register)

| Status | Features |
|---|---|
| Implemented, not fully verified (reads work on Supabase path; writes partly unverified) | Dashboard, Work Desk (requirements/offers/matching), Deals list, Directory, Search, Profile, Settings, Auth |
| Partially implemented / broken write path | Allocations, deal creation, negotiation, party confirmation, finalize/booking, commission ledger |
| Demo/mock-backed (presents fabricated data) | Invoices, commission payments, tasks (mixed), notifications (mixed), broadcast history & delivery |
| Placeholder | Dispatch & logistics (`/orders`), Disputes (`/disputes`), voice search |
| Not found | Voice/video calling (only `tel:` / `wa.me` links), reports module |

## 6. Business workflows (as implemented)

1. **Requirement:** broker creates on Work Desk → insert `requirements` (broker_id = auth.uid, visibility global). The buyer app can notify brokers via the `notify_requirement_brokers` RPC (0040).
2. **Offer:** broker creates a seller lot → insert `availabilities` (broker_id = auth.uid, visibility global).
3. **Matching:** computed client-side only (`RequirementMatcher`); recommendation only.
4. **Allocation:** insert `requirement_allocations` with status `CONFIRMED` directly. **No inventory reservation and no `fulfilled_quantity` update.**
5. **Deal:** a client-side multi-step write: quotation → deal (`Draft`) → `deal_versions` v1 → allocation `COMMITTED_TO_DEAL`. **Stops here in practice:** it selects the non-existent `availabilities.seller_id`.
6. **Negotiation / confirmation / finalize:** these update `deal_versions.snapshot_payload`, which the 0034 trigger forbids. Finalize inserts invalid `bookings` columns. **Cannot complete via the Supabase path.**
7. **Commission:** derived on the fly as `agreed_quantity × ₹50` per non-cancelled deal; no ledger table.
8. **Dispatch, disputes:** not implemented in RMBroker.

## 7. Core business rules found in code (verify with product owner)

- The broker is identified as `auth.uid()`. `public.users.id` equals `auth.users.id` (per RB-DB-SEC-01 audit). RLS uses `broker_id = auth.uid()`.
- Trusted role = `auth.users.raw_app_meta_data.role`, synced from `public.users.role` by trigger (0037). Client gate accepts `broker` or `admin`.
- Offers/requirements with `visibility = 'global'` are readable by all authenticated users (RLS 0038/0039).
- Brokerage rate hardcoded at **₹50/MT** in dashboard and commission code (not from deal terms).
- Finalization requires buyer and seller confirmation on the latest version (client-side check). The broker records both confirmations on the parties' behalf.

## 8. Design conventions

- Repositories return sealed result types (`DealDataResult`, `WorkDataResult`, `DashboardDataResult`): Success / ContractPending / Error / Unauthorized.
- Status strings are mapped to enums with `fromString`. **Unknown strings fall back to a default (`draft` / `open`)**, which silently re-buckets data.
- Theme in `lib/app/theme/`; shared widgets in `lib/core/widgets/`; roadmap screens use `ModulePlaceholderScreen`.

## 9. Development constraints (mandatory)

- Do not run migrations or seeds, or mutate remote data, without explicit approval.
- Do not weaken RLS or expose a service-role key (Flutter uses the anon key only; that is correct).
- Do not display fabricated data as real. This rule is currently violated in several modules; see Known Issues.
- One micro-sprint per task; report tests honestly. Supabase-path behaviour has **no automated tests**.
- Run Flutter with the full path: `D:\flutter_sdk\flutter\bin\flutter.bat`.
