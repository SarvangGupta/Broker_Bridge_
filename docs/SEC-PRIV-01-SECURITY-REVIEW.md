# SEC-PRIV-01 — Supabase Privilege Audit, Credential Exposure & Remediation Plan

**Sprint:** SEC-PRIV-01 (audit-first, read-only) · **Date:** 2026-10-24 (all times UTC)
**Branch / HEAD:** `feature/broker-nilesh` @ `390fd84` (TEST-ISOLATION-01 changes present in the working tree, uncommitted)
**Status:** **Proposal only. Awaiting owner approval.** No grants, revokes, policy or default-privilege changes, credential rotation, session revocation or history rewriting was performed.

**Labels:** **[Observed]** read from catalogs, repository or Git · **[Inferred]** reasoned from observed evidence · **[Proposed]** recommendation · **[Unverified]** not confirmed.

---

## 1. Executive summary

| # | Severity | Finding | Label |
|---|---|---|---|
| F1 | **Critical** | `public.crm_tasks` has **RLS disabled** and **no policies**. `authenticated` holds **DELETE** (+ TRUNCATE, TRIGGER, REFERENCES, MAINTAIN) but no SELECT/INSERT/UPDATE. The live state matches `supabase/migrations/rollback_0036_0037.sql` lines 6–10, so that rollback (or part of it) appears to have run in production. | Observed / Inferred |
| F2 | **Critical** | Two real buyer passwords are hardcoded in 3 RMBuyer test files. They were added in commit `8ef158e` (2026-10-20), which is **on `vetkind/feature/broker-nilesh`** and still in local HEAD. The accounts hold **49 and 24 non-revoked refresh tokens**. Account 1 shows a **sign-in at 11:30:14 UTC that is not explained by my test run** (ended ≈11:24). | Observed / Unverified |
| F3 | High | The default ACL for owner `postgres` in schema `public` gives `anon`, `authenticated` and `service_role` **TRUNCATE, REFERENCES, TRIGGER and MAINTAIN** on every future table. Today `anon` holds TRGM on 18 tables, `authenticated` on all 39, and `service_role` on all 39. | Observed |
| F4 | High | `authenticated` holds **DELETE** on `companies`, `crm_activities`, `crm_contacts`, `users` and `crm_tasks`. **No app issues DELETE through PostgREST.** RLS blocks it on the first four (no DELETE policy, except the admin `ALL` policy on `companies`), but not on `crm_tasks` (F1). | Observed |
| F5 | Medium | SECURITY DEFINER functions `notify_requirement_brokers`, `sync_privileged_role_to_auth` and `rls_auto_enable` are executable by **`anon`**. Policies on `deal_versions` and `negotiation_events` target the `public` pseudo-role, not `authenticated`. | Observed |
| F6 | Medium | `service_role` has **no SELECT/INSERT/UPDATE/DELETE on any public table**. The only server-side service-key use (`admin-user-actions.ts`) calls the Auth Admin API, not tables. **No evidence it needs table grants.** | Observed |
| F7 | Medium | Several app paths depend on grants that don't exist: `negotiation_events` inserts (all 3 apps), RMSeller reads of `invoices`, `lab_tests`, `dispatch_documents` and the non-existent `master_mandis`, `support_tickets` inserts, and the planned RMBuyer category picker (`master_categories`). These are functional gaps, not security holes. Fix them with policies first. | Observed |
| F8 | Medium (app) | RMSeller `AuthRepository.signInWithPassword` logs **any credentials** in as a hardcoded demo seller with a mock token whenever the Supabase client is null (`main()` swallows init errors). This gives no server access, but it is a client-side auth bypass. | Observed |
| F9 | Low | `admin-user-actions.ts` L71 silently falls back to the **anon key** when `SUPABASE_SERVICE_ROLE_KEY` is absent. | Observed |
| F10 | Info | The TEST-ISOLATION-01 guard is effective for `apps/rmbuyer_mobile/test` only. Gaps are listed in §2.3. | Observed |

**RLS is not a substitute for privilege review.**
- RLS filters rows for SELECT, INSERT, UPDATE and DELETE.
- It does **not** apply to TRUNCATE, TRIGGER, REFERENCES or MAINTAIN.
- It does nothing at all when it is disabled on a table (F1).
- Table owners and roles with BYPASSRLS (`postgres`, `service_role`) ignore it.

Privileges are the first gate; RLS is the second.

## 2. Scope, inspection date and limitations

- **Database:**
  - Project `DATABASE_URL`, role `postgres` (BYPASSRLS, not superuser), PostgreSQL 17.6.
  - All queries were catalog/metadata reads inside `BEGIN READ ONLY`.
  - **Results are administrative privilege evidence.** Effective per-role privileges come from `has_table_privilege`, `has_function_privilege` and `pg_policies`; they are not proof of what a given end user can reach through PostgREST.
  - Row counts in `requirements` and `notifications` were unchanged before and after this sprint (29 / 7).
- **Auth data:** counts and timestamps only, for the 2 exposed accounts. Emails were resolved in-process and not printed; accounts are shown as `test_account_1/2`.
- **Repository:** static scan of `.from('<table>')` operations in all 3 Flutter apps and in web supabase-js usage, plus TEST-ISOLATION-01 source review.
- **Git history:** redacted scan of all 1,690 unique blobs across all refs. Only path, pattern, count and distinct-value count were printed; JWTs were decoded to role/ref claims only.
- **Limitations:**
  - Remote refs are as of the last local fetch (2026-10-20); no network fetch was made.
  - Whether the GitHub repositories are public or private, and their secret-scanning settings, are **[Unverified]**.
  - PostgREST/API settings (exposed schemas, `pg-safeupdate`, sign-up policy) were not read; the Supabase dashboard is needed.
  - No tests were run, by choice: the guard was already verified in TEST-ISOLATION-01, and nothing in this sprint needed new tests.

### 2.3 TEST-ISOLATION-01 review [Observed from source]
- **Verified in code:**
  - `test/flutter_test_config.dart` sets `HttpOverrides.global = TestNetworkGuardOverrides(...)` for every test file under `apps/rmbuyer_mobile/test`.
  - `network_guard.dart` refuses any host containing the production ref, even if allow-listed; allows loopback; refuses everything else unless allow-listed.
  - `live_test_config.dart` requires `RMBUYER_LIVE_TESTS=1` plus env values, never reads `AppConfig`, and rejects production URLs, production-ref keys and service-role keys. Missing values throw (fail closed).
  - The 3 live files contain **0** password literals in the working tree; `skip: LiveTestConfig.skipReason`; `@Tags(['live'])`.
  - `dart_test.yaml` declares the tag.
- **Gaps:**
  1. **Not committed.** HEAD and `vetkind/feature/broker-nilesh` still contain the old live tests with credentials. Anyone running tests from that branch writes to production.
  2. Covers RMBuyer only. RMBroker and RMSeller have no guard. No live-client tests were found there today, but RMSeller's auth tests rely on the demo-login path (F8).
  3. `HttpOverrides` covers `dart:io` HTTP and WebSocket only. Raw `Socket`, `flutter test --platform chrome`, `integration_test` and on-device runs are not covered.
  4. Loopback is always allowed, so a local proxy or tunnel to production would not be caught.
  5. The live allow-list trusts environment values. A non-production host is accepted on the user's word, apart from the production-ref and key checks.
  6. Live tests never sign out, so each opt-in run leaves sessions behind (see F2).

## 3. Verified privilege findings by role, schema and table [Observed]

Legend:
- S SELECT, I INSERT, U UPDATE, D DELETE, T TRUNCATE, R REFERENCES, G TRIGGER, M MAINTAIN.
- "pol" = number of RLS policies on the table.

### 3.1 Roles
| Role | Login | BYPASSRLS | Notes |
|---|---|---|---|
| `anon`, `authenticated` | no | no | assumed by PostgREST through `authenticator` |
| `service_role` | no | **yes** | no table grants (below) |
| `authenticator` | yes | no | member of anon, authenticated, service_role |
| `postgres` | yes | **yes** | owner of all public tables; member of `pg_read_all_data` |
| `supabase_admin` | yes (superuser) | yes | platform |

No application-specific database roles exist.

### 3.2 Schema `public`. Every table is owned by `postgres`.

| Table | RLS | pol | anon | authenticated | service_role |
|---|---|---|---|---|---|
| availabilities | on | 3 | — | SIU TRGM | TRGM |
| availability_quality_values | on | 0 | TRGM | TRGM | TRGM |
| bookings | on | 2 | — | SI TRGM | TRGM |
| companies | on | 6 | — | SIU**D** TRGM | TRGM |
| crm_activities | on | 3 | — | SIU**D** TRGM | TRGM |
| crm_contacts | on | 3 | — | SIU**D** TRGM | TRGM |
| **crm_tasks** | **OFF** | **0** | — | **D** TRGM | TRGM |
| deal_versions | on | 2 | — | SIU TRGM | TRGM |
| deals | on | 3 | — | SIU TRGM | TRGM |
| dispatch_documents | on | 0 | TRGM | TRGM | TRGM |
| dispatches | on | 3 | — | SIU TRGM | TRGM |
| disputes | on | 3 | — | SIU TRGM | TRGM |
| invoices | on | 0 | TRGM | TRGM | TRGM |
| lab_tests, lab_test_results | on | 0 | TRGM | TRGM | TRGM |
| master_business_types | on | 0 | TRGM | TRGM | TRGM |
| master_categories | on | 0 | TRGM | TRGM | TRGM |
| master_commodities | on | 1 | S | S TRGM | TRGM |
| master_districts | on | 1 | S | S TRGM | TRGM |
| master_grades | on | 1 | S | S TRGM | TRGM |
| master_industries | on | 0 | TRGM | TRGM | TRGM |
| master_packaging_types | on | 0 | TRGM | TRGM | TRGM |
| master_quality_parameters | on | 0 | TRGM | TRGM | TRGM |
| master_states | on | 1 | S | S TRGM | TRGM |
| master_units | on | 1 | S | S TRGM | TRGM |
| master_vehicle_types | on | 1 | S | S TRGM | TRGM |
| negotiation_events | on | 2 | TRGM | TRGM | TRGM |
| notifications | on | 2 | — | SU TRGM | TRGM |
| payments | on | 0 | TRGM | TRGM | TRGM |
| profiles_broker/buyer/seller | on | 0 | TRGM | TRGM | TRGM |
| quotations | on | 3 | — | SIU TRGM | TRGM |
| requirement_allocations | on | 3 | — | SIU TRGM | TRGM |
| requirement_documents, requirement_quality_specs | on | 0 | TRGM | TRGM | TRGM |
| requirements | on | 3 | — | SIU TRGM | TRGM |
| support_tickets | on | 0 | TRGM | TRGM | TRGM |
| users | on | 3 | — | SIU**D** TRGM | TRGM |

- No column-level grants beyond table grants. No sequences or views in `public`.
- Schema USAGE: anon, authenticated and service_role have USAGE (not CREATE) on public, auth, storage, graphql, graphql_public, realtime and extensions. `vault` is service_role only.
- `storage` schema (Supabase-managed): anon and authenticated hold SIUD on `storage.objects`/`buckets` with RLS on. All 5 `objects` policies target `authenticated`; `buckets` has 0 policies. Platform default; review separately.

### 3.3 Functions in `public` [Observed]
| Function | SECURITY DEFINER | anon EXEC | authenticated EXEC | Note |
|---|---|---|---|---|
| get_auth_role, is_admin, is_broker | yes | no | yes | as intended (0036/0038) |
| notify_requirement_brokers | yes | **yes** | yes | rejects null `auth.uid()` internally; anon grant is unnecessary |
| sync_privileged_role_to_auth | yes | **yes** | yes | trigger function (direct calls fail), but the grant shouldn't exist |
| rls_auto_enable | yes | **yes** | yes | backs event trigger `ensure_rls`; likely platform-provided, **[Unverified]** origin |
| prevent_* (2) | no | yes | yes | trigger functions |

## 4. Default privilege configuration and future-table implications [Observed]

| Grantor (owner) | Schema | Object | Grants to app roles |
|---|---|---|---|
| **postgres** | **public** | tables | `anon=Dxtm`, `authenticated=Dxtm`, `service_role=Dxtm` (TRUNCATE, REFERENCES, TRIGGER, MAINTAIN) |
| postgres | public | sequences / functions | postgres only (functions keep the PostgreSQL default PUBLIC EXECUTE) |
| postgres | storage | tables / seq / func | anon, authenticated and service_role get **full** `arwdDxtm` / `rwU` / `X` |
| supabase_admin | public, graphql, graphql_public | tables / seq / func | anon, authenticated and service_role get **full** `arwdDxtm` / `rwU` / `X` |
| supabase_admin | extensions, realtime | — | postgres / dashboard_user only |
| supabase_auth_admin | auth | — | postgres / dashboard_user only |

**Implications:**
- Every table that a migration creates as `postgres` in `public` automatically gives all three app roles TRUNCATE, TRIGGER, REFERENCES and MAINTAIN.
- Any table created as `supabase_admin` in `public` (e.g. some dashboard or platform operations) gets **full CRUD for `anon`**. Its safety then rests entirely on RLS being enabled. **[Inferred]** The `ensure_rls` event trigger suggests auto-RLS is configured, yet `crm_tasks` shows RLS can be disabled afterwards.
- `postgres` can change its own defaults (`ALTER DEFAULT PRIVILEGES FOR ROLE postgres`). The `supabase_admin` defaults are platform-managed and **[Unverified]** whether they're changeable on hosted Supabase. Mitigation: always create tables as `postgres` through migrations, and make each migration issue explicit REVOKE/GRANT.

## 5. Current RLS / policy findings (separate from SQL privileges) [Observed]

- RLS is enabled on every public table **except `crm_tasks`**.
- **Policies exist** on availabilities, bookings, companies (6, including an admin `ALL`), crm_activities, crm_contacts, deal_versions, deals, dispatches, disputes, the 6 master read tables, negotiation_events, notifications, quotations, requirement_allocations, requirements and users.
- **Grant/policy mismatches:**
  - `deal_versions`: U granted, but no UPDATE policy, so updates silently affect 0 rows (blocks the RMBroker confirmation flow; see earlier sprints).
  - `negotiation_events`: SELECT and INSERT policies exist (role `public`) but **no grant**, so app inserts fail with 42501.
  - `notifications`: no INSERT grant or policy, so RMBroker and RMSeller client inserts fail. The RPC path works.
  - `master_categories`, `master_industries`, `master_quality_parameters`, `invoices`, `lab_tests`, `dispatch_documents`, `support_tickets`, `payments`, `profiles_*`: RLS on, 0 policies, and no S/I/U grants. Default-deny for clients.
  - The policies on `deal_versions` and `negotiation_events` target `{public}`. Today anon has no grant on them, so it's harmless, but one future grant would expose them to anon.
- **No DELETE policies** exist except `companies` "Tier 0 admin … ALL".

## 6. Proposed least-privilege matrix [Proposed — every row Requires approval]

Basis: the observed PostgREST usage per app (static scan), observed policies and planned features. "—" = no privilege. **No role gets TRUNCATE, TRIGGER, REFERENCES, MAINTAIN or DELETE on any public table.** No app uses DELETE.

| Table | anon | authenticated | service_role | Evidence (who uses it) | Prerequisite |
|---|---|---|---|---|---|
| availabilities | — | S I U | — | RMBroker S/I, RMSeller S/I/U | policies exist |
| bookings | — | S I | — | RMBroker I; deals embed | policies exist |
| companies | — | S I U | — | RMBroker S/I/U, RMSeller S/U, RMBuyer S | policies exist |
| crm_activities | — | S I | — | RMBroker | policies exist (U not used: drop U) |
| crm_contacts | — | S I U | — | RMBroker | policies exist |
| **crm_tasks** | — | S I U | — | RMBroker tasks | **re-enable RLS + 0036 policies first** |
| deal_versions | — | S I U | — | RMBuyer S/U, RMBroker S/I/U | add an UPDATE policy limited to the status column (separate functional sprint); policies `TO authenticated` |
| deals | — | S I U | — | all apps | policies exist |
| dispatch_documents | — | S | — | RMSeller S | policy needed first |
| dispatches | — | S I U | — | policies exist; no client usage found (**[Unverified]** need) | review |
| disputes | — | S | — | RMBroker S (dashboard) | trim I/U unless a dispute flow is approved |
| invoices | — | S | — | RMSeller S | policy needed first |
| lab_tests | — | S I U | — | RMSeller | policy needed first |
| master_commodities, grades, units, states, districts | S **only if** pre-login use is confirmed, otherwise — | S | — | all apps after login; anon use **[Unverified]** | — |
| master_categories, master_industries | same as above | S | — | planned RMBuyer picker; web cascade uses Drizzle | add SELECT policy |
| master_quality_parameters | — | S (when needed) | — | planned | add policy |
| master_vehicle_types | — | S | — | web Drizzle only; client need **[Unverified]** | — |
| master_business_types, master_packaging_types | — | — (until a client needs them) | — | no client usage | — |
| negotiation_events | — | S I | — | RMSeller S/I; RMBroker and RMBuyer I | change policies `TO authenticated`; insert columns must be fixed in the apps |
| notifications | — | S U | — | all apps S/U | **no client INSERT**: use the RPC or server (RMBroker broadcast needs a server path) |
| payments, profiles_*, availability_quality_values, lab_test_results, requirement_documents, requirement_quality_specs | — | — | — | no client usage (web Drizzle) | — |
| quotations, requirement_allocations, requirements | — | S I U | — | all apps | policies exist |
| support_tickets | — | I | — | RMSeller I | policy needed first |
| users | — | S I U | — | all apps | policies exist |

**Functions:** `REVOKE EXECUTE … FROM PUBLIC, anon` on `notify_requirement_brokers`, `sync_privileged_role_to_auth` and the trigger functions. Keep `authenticated` EXECUTE on `notify_requirement_brokers`, `get_auth_role`, `is_admin` and `is_broker`. `rls_auto_enable`: **review with Supabase docs before changing**.

**anon vs authenticated for master data:**
- No public/anonymous page or pre-login screen reading master tables was found in the scanned code. All Flutter reads happen after login; the web uses Drizzle.
- **[Proposed]** authenticated-only, **unless** the owner confirms a pre-login need (e.g. registration dropdowns). Check RMSeller/RMBuyer registration screens before revoking anon SELECT.

**service_role:**
- **[Proposed]** No table grants (only remove its TRGM).
- The only use is the Auth Admin API.
- Adding grants without a traced dependency would only enlarge the impact of a key leak.

## 7. Application dependency and compatibility assessment

| Consumer | Path / DB role | Tables (ops) [Observed static scan] | Impact of the proposed revokes |
|---|---|---|---|
| RMBuyer | PostgREST as `authenticated` | companies S; deal_versions S/U; deals S/U; master_commodities, grades, units S; negotiation_events I; notifications S; quotations S/U; requirements S/I/U; users S; RPC `notify_requirement_brokers` | none (no D/T/G/R/M used) |
| RMBroker | PostgREST as `authenticated` | availabilities S/I; bookings I; companies S/I/U; crm_activities S/I; crm_contacts S/I/U; crm_tasks S/I/U; deal_versions S/I/U; deals S/I/U; disputes S; master_* S; negotiation_events I; notifications S/I/U; quotations S/I/U; requirement_allocations S/I/U; requirements S/I/U; users S/I/U | none for the revokes. **crm_tasks needs S/I/U back**, which only fixes currently-broken behaviour |
| RMSeller | PostgREST as `authenticated` | availabilities S/I/U; companies S/U; deals S; dispatch_documents S; invoices S; lab_tests S/I/U; master_* S (incl. missing `master_mandis`); negotiation_events S/I; notifications S/I/U; support_tickets I; users S/U; storage `brokerbridge_lab_evidence` | none for the revokes; several reads are already denied today (F7) |
| Web | Drizzle over `DATABASE_URL` as `postgres` (≈80 files) | all tables | **unaffected**: owner plus BYPASSRLS. Table grants to app roles don't apply |
| Web | supabase-js (user session) | `users` S; storage buckets `brokerbridge_documents`, `brokerbridge_lab_evidence`, `fulfillment_documents` | none |
| Web | service-role client (`admin-user-actions.ts`) | `auth.admin.createUser` only | none |
| Migrations / dashboard | `postgres` / `supabase_admin` | DDL | default-privilege change affects **future** tables only; migrations must then add explicit grants |

**Limitations:** the static scan may miss dynamically built table names. Edge Functions, cron jobs and external integrations (WhatsApp webhook, cron routes) were not traced beyond the web code. **[Unverified]**

## 8. Credential exposure and Git history findings (no secret values)

| Item | Files | Introduced | Remotes containing it | Still in HEAD | Status |
|---|---|---|---|---|---|
| **2 real buyer-account passwords** (5 literals, 2 distinct values) + their emails | `apps/rmbuyer_mobile/test/unit/buyer_requirement_e2e_verification_test.dart`, `buyer_broker_notification_backend_test.dart`, `buyer_live_auth_verification_test.dart` | `8ef158e` (2026-10-20) | **`vetkind/feature/broker-nilesh`** (not `origin/*`, not `vetkind/main`) as of last fetch | **yes** (`390fd84`). Working tree: removed (uncommitted TEST-ISOLATION-01) | **Exposed: rotate** |
| Production **anon** key (role=anon, ref = production) | `apps/{rmbroker,rmbuyer,rmseller}_mobile/lib/core/config/app_config.dart` | `b8e484d`, `8ef158e`, `56e52fb` | yes | yes | public by design (shipped in apps); acceptable while RLS and privileges are correct. Not a secret, but it's why F1–F5 matter |
| Mock passwords and tokens (mocked clients) | RMBuyer `auth_repository_test.dart` (7 password literals, 2 token-like strings); RMSeller/RMBroker auth tests (placeholders) | various | yes | yes | **0 overlap with the real passwords** (in-process comparison). Low risk |
| DB URL with password | `project-audit/deep-intelligence/07_INTEGRATIONS_AND_DEPLOYMENT_MAP.md` L35 | `b8e484d` | `vetkind/feature/broker-nilesh`, `vetkind/main` | yes | **placeholder-shaped**; does **not** match the live password or host |
| DB URL | `drizzle.config.ts` (fallback `user:password@localhost`), `.env.example` | — | yes | yes | placeholders |
| `.env`, `.env.local` | — | never tracked (git-ignored) | — | — | OK |

- Real service-role keys, Google API keys, private keys and `sb_secret_` keys: **none found** in any of the 1,690 historical blobs.
- **Secret scanning:** gitleaks, trufflehog, detect-secrets and ggshield are **not installed**. The redacted custom scan above was used instead.
- **[Proposed]** Install gitleaks locally (in redact mode) and enable GitHub secret scanning and push protection on both repositories. Repository visibility is **[Unverified]**.
- **History rewriting does not replace rotation.** Once a secret has been pushed, it must be treated as compromised: clones, forks, CI caches and GitHub caches may already hold it.

## 9. Recommended credential rotation and session-review sequence [Proposed — Requires approval]

1. **Confirm ownership** of `test_account_1/2` (both `public.users.role = buyer`) and whether they are dedicated test accounts.
2. **Investigate the unexplained sign-in:** `test_account_1` last signed in at **2026-10-24 11:30:14 UTC**, ≈6 minutes after my test run ended (account 2's last sign-in, 11:23:53, matches my run). Check `auth.audit_log_entries` (IP / user agent) in the dashboard. **[Unverified]**
3. **Rotate both passwords**, through the dashboard or Auth Admin API, by the account owner or admin. Store new test credentials only in a secret store or CI secrets.
4. **Revoke sessions and refresh tokens** for both accounts. Observed **non-revoked:** 49 for account 1 and 24 for account 2; nearly all were created by test runs that never signed out.
5. **Review activity** for these accounts since 2026-10-20: requirements, notifications, quotations and deal_versions linked to their companies. This ties into the Dal-requirement review (§10).
6. **Commit TEST-ISOLATION-01**, so the remote stops carrying live tests with credentials, and push after approval.
7. **Optionally**, after rotation: rewrite history to purge the literals from `vetkind/feature/broker-nilesh` (git filter-repo + force-push, coordinated with all clones). **Owner decision. It doesn't reduce the need for steps 3–4.**
8. Add `tearDown` sign-out to the live tests, and CI checks (gitleaks with push protection).

## 10. Live-test incident reference and cleanup recommendation

- **[Observed]** My RMBuyer `flutter test` run in BUYER-PRODUCT-MASTER-01 (≈11:23:38–11:24:20 UTC) created:
  - **2 requirements** (11:23:51.46 and 11:23:52.59 UTC; commodity Dal, grade Moisture, unit kg);
  - **1 `REQUIREMENT_CREATED` notification** to a broker (11:23:51.63 UTC);
  - new auth sessions for both test accounts.
- The records are untouched. The passwords used were the committed ones (§8).
- Full evidence: [BUYER-PRODUCT-MASTER-03-DECISION-REVIEW.md](BUYER-PRODUCT-MASTER-03-DECISION-REVIEW.md) (Disclosure, §2).
- **[Proposed] separate controlled review (DATA-PROVENANCE-01):**
  1. Verify exact IDs by query.
  2. Check relationships (quotations, deal_versions, negotiation_events, allocations, notifications).
  3. Check downstream broker activity (one of the earlier Dal requirements has broker proposals).
  4. Decide flag vs cancel. No deletion of append-only negotiation records.

## 11. Ordered remediation plan with rollback and verification

Each step is a separate, approved change, run in one transaction where possible.

| Step | Change | Why this order | Rollback | Verification |
|---|---|---|---|---|
| 0 | Credential response (§9, steps 1–5) | live exposure; independent of DB grants | n/a (new passwords) | sign-in with old password fails; 0 active refresh tokens |
| 1 | **Snapshot** current `pg_class.relacl`, `pg_default_acl`, `pg_policies`, `proacl` and RLS flags into a dated file (read-only export) | enables exact rollback | — | snapshot checksum stored |
| 2 | **crm_tasks:** `ENABLE ROW LEVEL SECURITY`; recreate the 0036 policies; `REVOKE ALL … FROM anon, authenticated`; `GRANT SELECT, INSERT, UPDATE … TO authenticated` | Critical (F1); RMBroker tasks currently fail anyway, so no regression | restore from snapshot (disable RLS + regrant), **not recommended** | `has_table_privilege` matrix; RMBroker task list and create as a broker; a non-owner broker can't see others' tasks |
| 3 | `REVOKE DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN ON ALL TABLES IN SCHEMA public FROM anon, authenticated, service_role` | no app uses them (§7) | regrant from the snapshot | privilege matrix; smoke-test each app (login, list, create, update) |
| 4 | `ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public REVOKE TRUNCATE, REFERENCES, TRIGGER, MAINTAIN ON TABLES FROM anon, authenticated, service_role` | stops future tables inheriting them | `ALTER DEFAULT PRIVILEGES … GRANT …` | create a scratch table **in a non-production branch** and inspect its ACL |
| 5 | Functions: `REVOKE EXECUTE … FROM PUBLIC, anon` (list in §6); default privileges for functions `REVOKE EXECUTE ON FUNCTIONS FROM PUBLIC` for postgres in public | least privilege | regrant | `has_function_privilege`; RMBuyer requirement and notification RPC still works |
| 6 | Re-target `deal_versions` and `negotiation_events` policies `TO authenticated` | defence in depth | recreate as before | policy list |
| 7 | anon master-data decision: revoke anon SELECT on master tables if no pre-login need is confirmed | depends on the owner check | regrant SELECT to anon | app pre-login screens |
| 8 | Functional least-privilege grants (separate sprints, each **policy before grant**): master_categories/industries S; negotiation_events S/I; seller invoices, lab_tests, dispatch_documents and support_tickets; deal_versions status-only UPDATE policy | restores intended features without broad grants | revoke | feature tests per app |
| 9 | Application follow-ups (separate code sprints): RMSeller demo-login bypass (F8); `admin-user-actions` anon-key fallback (F9); RMBroker/RMSeller test guards; live-test sign-out | — | — | — |

**Process:**
- Run every DB step first on a Supabase branch or staging copy.
- Then apply in production inside a maintenance window, with an explicit go/no-go per step.
- Never use broad `GRANT ALL`.
- Every migration file gets an explicit REVOKE/GRANT block, so it doesn't depend on default privileges.

## 12. Explicit owner approval gates

- [ ] **G1** Confirm the exposed accounts are test accounts. Approve password rotation and revocation of all their sessions and refresh tokens (§9).
- [ ] **G2** Investigate and explain the 11:30:14 UTC sign-in of test_account_1.
- [ ] **G3** Approve committing (and later pushing) TEST-ISOLATION-01.
- [ ] **G4** Decide on Git history rewriting for `vetkind/feature/broker-nilesh` (after rotation). Confirm repo visibility; enable GitHub secret scanning and push protection.
- [ ] **G5** Approve step 2 (crm_tasks RLS restoration) as the first DB change.
- [ ] **G6** Approve steps 3–6 (revokes, default privileges, function EXECUTE, policy roles) after the staging run.
- [ ] **G7** Decide anon vs authenticated for master-data reads (needs a check of pre-login screens).
- [ ] **G8** Confirm that `service_role` should get **no** table grants.
- [ ] **G9** Approve DATA-PROVENANCE-01 for the 2 test requirements, the notification and the earlier Dal records.
- [ ] **G10** Schedule the app follow-ups (F8 RMSeller demo login, F9 anon-key fallback, test guards for RMBroker/RMSeller).

---

### Actions deliberately not performed
- No GRANT, REVOKE, policy, default-privilege, ownership, schema or data change. All database access was `READ ONLY`.
- No credential rotation, session revocation, history rewrite, force-push, fetch or remote change.
- No code changes (RMBuyer, RMBroker, RMSeller, web). No tests run.
- No secret values printed or written. Emails were resolved in-process only. Auth data was limited to counts and timestamps for the 2 exposed accounts.
- No commit or push.
