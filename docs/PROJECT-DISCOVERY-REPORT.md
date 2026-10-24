# RMBroker — Project Discovery Report

**Assignment:** project discovery and documentation only (no code, schema, or remote changes).
**Date:** 2026-10-24 · **Branch:** `feature/broker-nilesh` · **HEAD:** `390fd84` · **Working tree:** clean at start; only `docs/*.md` added by this assignment.
**Remotes:** `origin` (SarvangGupta/Broker_Bridge_), `vetkind` (vetkindinfo-maker/brokerage_com). Local is 1 commit ahead of `vetkind/feature/broker-nilesh`.

## 1. What was inspected

- Git: status, branches, remotes, last 30 commits.
- Flutter app `apps/rmbroker_mobile`: entire `lib/` tree (≈150 files) mapped. In full or in depth: router, config, main, auth, network, the dashboard (repository, models, controller), deals (repository, controller, screen, status model), work (repository, status models, screen filters), commission, notifications, tasks, invoices, broadcast repositories, and the More menu. `pubspec.yaml`, Android Gradle/manifest, `test/` tree.
- Backend: `supabase/migrations` 0001–0041 (core tables plus 0034, 0035, 0037, 0038, 0039, 0040, 0041, manual RLS read in full); Drizzle `src/server/db/schema.ts`; list of Next.js API routes and auth pattern of `/api/v1/broker/*`.
- Docs: RB-DASH-FIX-01, RB-DRILL-01, RB-DB-SEC-01 reports; headers of `project-audit/*`, `ARCHITECTURE.md`, `PROJECTSTATE.MD`, `docs/bug-log.md`.
- Env: names only of `.env` variables; confirmed `.env*` is git-ignored and only `.env.example` is tracked.

## 2. Findings supported by code

1. RMBroker reads its data from **Supabase directly**. The REST layer is attempted first, but only directory and requirement-proposal routes exist.
2. **Fabricated data is shown alongside or instead of real data** in notifications, tasks, deal detail (two magic ids), commission (no-session path, payments), invoices (always), broadcast delivery and history, and dashboard trend badges.
3. **The deal lifecycle write path cannot complete against the repo schema**: create (missing `seller_id`), terms (`change_reason`), confirm (immutable snapshot + no UPDATE policy), finalize (invalid bookings columns). The failures surface as errors, except the audit inserts, which are swallowed.
4. **Dashboard counts don't reconcile with drill-down lists** for 6 of 8 metrics because of different status vocabularies, expiry rules, quantity rules, null-broker scoping, inner joins, and (for disputes) a different source table.
5. Auth gate: the client role check falls back to user-editable metadata because of a column-name bug. There is no router guard and the 401 handler isn't wired. The server-side RLS design (0036–0041) is sound on paper: broker = `auth.uid()`, the trusted role is in `app_metadata`, and self-promotion is blocked.
6. Schema source of truth is split: `broker_id` on requirements/availabilities exists only in Drizzle, yet RLS depends on it.
7. Dispatch and disputes are honest placeholders; calling is limited to `tel:`/WhatsApp links; there is no reports module.

## 3. Findings supported by executed tests (this session)

| Command (run from `apps/rmbroker_mobile`) | Result |
|---|---|
| `D:\flutter_sdk\flutter\bin\flutter.bat --version` | Flutter 3.47.6 stable, Dart 3.13.5 |
| `flutter analyze --no-pub` | **No issues found** (11.7 s) |
| `flutter test --no-pub` | **295 passed, 0 failed** |

What these prove: models, widgets, navigation, and REST-path parsing behave as the tests expect. **What they don't prove:** any Supabase query, RLS behaviour, schema compatibility, or live data. No test injects a `SupabaseClient`.

**Not run:** `flutter build apk` (existing `build/app/outputs/flutter-apk/app-debug.apk` and `app-release.apk` dated 2026-10-23 were left untouched), device runs, Next.js build/tests, any database query.

## 4. Findings supported only by existing documentation

- Remote DB state on 2026-10-19: RLS enabled with 0 policies, no SELECT grants for `authenticated`, 0 operational rows, `deals` missing FKs (RB-DB-SEC-01).
- Isolated Postgres 16 validation of 0038 (25/25) (RB-DB-SEC-01).
- Live device verification of metrics with seeded data (RB-DASH-FIX-01, RB-DRILL-01, commit `6c35cfa`).
- Prior test baselines 235 → 242 tests (now 295).

## 5. Areas not inspected or inaccessible

- Remote Supabase (schema, policies, grants, data). No credentials were used, by design.
- `apps/rmbuyer_mobile`, `apps/rmseller_mobile` internals (they produce data RMBroker reads).
- Most of the Next.js web platform; VetKind module.
- Presentation widgets beyond the dashboard and filters (visual state of the RB-UI-DASH-01 redesign was not viewed).
- iOS configuration (none present for RMBroker beyond Flutter defaults).

## 6. Conflicts between code and documentation

| Document claim | Code reality |
|---|---|
| RB-DRILL-01: "all 8 metrics consistent … VERIFIED" | Predicates differ for 6/8 cards (KI-20) |
| RB-DRILL-01: "All mock fallback paths … in Commission Ledger were eliminated" | Mock cache still used with no session and in `getDealCommission`; payments are in-memory (KI-04) |
| Dashboard `dataSourceNotice`: "Authoritative … verified" | Disputes errors swallowed; trend badges fabricated |
| Router comments "(Protected)" | No guard exists |
| Work repository "Zero-Fabrication" comments | Other repositories seed demo data into live views |
| RB-DB-SEC-01 (remote empty, no grants) vs RB-DRILL-01 (live records verified) | Cannot be resolved without G-1 |
| `project-audit/*` (2026-10-17) describe the web platform as the source of truth | RMBroker Flutter work since then is not reflected there |

## 7. Recommended priorities (next micro-sprints)

1. **RB-FAKE-DATA-01: remove fabricated data from live paths** (fast-fix, client only).
   - **Scope:** stop seeding demo notifications/tasks into live results; delete the magic-id deal fallback; stop the commission demo cache on live paths and stop reporting in-memory payments as confirmed; make broadcast report real delivery outcomes; drop the fabricated trend badges.
   - **Not in scope:** invoices. Hide or label them "Preview / not persisted" pending gate G-5.
   - **Why first:** this is the largest trust risk. Brokers can act on fake deals, tasks, and payments. No DB approval is needed, and the change is easy to test.
2. **RB-DB-VERIFY-01: read-only remote verification** (controlled audit, gate G-1).
   - **Scope:** snapshot the remote columns, FKs, policies, grants, triggers, and row counts for the tables in DATABASE-AND-API-MAP §1. Do not change anything.
   - **Why:** most S1 findings (broken writes, auth column, RLS presence, conflicting reports) depend on the actual remote state. It decides whether the next sprint is a code fix or a migration.
3. **RB-DASH-RECON-01: one shared metric definition per card** (fast-fix, client only).
   - **Scope:**
     - extract shared status-bucket predicates used by both the dashboard and the destination filters (expiry, available qty, unknown-status handling);
     - drop `broker_id IS NULL` from list queries;
     - align Open Disputes to a single source and surface its errors;
     - add Supabase-path repository tests with a fake client.
   - **Why:** this is the user-visible correctness issue on the home screen, and the tests close the coverage gap behind it.

Then **RB-DEAL-WRITE-01** (controlled audit, gates G-3/G-4): move create, terms, confirm, and finalize into server-side transactional RPCs or REST, aligned with 0028, 0034, and 0035. It depends on the outcome of RB-DB-VERIFY-01.
