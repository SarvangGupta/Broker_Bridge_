# RB-SEC-PRIV-01 — Confidential Supply Data Audit (Phase 1, read-only)

Date: 2026-10-25 · Branch: `feature/broker-nilesh` · **Phase 1 status: PASS (audit complete)** · Remediation: **awaiting approval**

**How evidence was gathered:** live inspection inside `BEGIN READ ONLY` transactions. Role simulation used `SET LOCAL ROLE` plus JWT claims inside savepoints, all rolled back. **Only counts and booleans were collected**; no confidential value was read into the output or this report. There were no writes, policy changes, migrations, deployments or code changes.

## 1. Finding summary

| ID | Severity | Finding |
|---|---|---|
| **P1** | **Critical** | Any authenticated session can read `availabilities.confidential_minimum_price` for every listing through the Supabase REST API (PostgREST). This includes Buyers, Sellers of other companies, and accounts with no profile. |
| **P2** | High | The same path exposes the Seller organization identifier (`company_id`) and the assigned broker's user ID (`broker_id`) to Buyers and other Sellers. |
| **P3** | Amplifier | Self-registration is open: web `signUpAction` accepts `buyer`/`seller`. The anon key is embedded in the mobile apps. So **anyone can create an account and exploit P1/P2**. 2 such profile-less accounts already exist. |
| P4 | Info | Server-side (Next.js) paths are correctly guarded, and Buyer-channel payloads are scrubbed. No other table, JSON payload, view, function or realtime channel carries the minimum price. |

**Cause:** the database row-security policy is not role-aware. `availabilities_select_policy` grants SELECT on any `visibility = 'global'` row to *every* `authenticated` user. RLS filters rows, not columns, and `authenticated` holds a table-wide SELECT grant. API projections, joins and RPCs are **not** the cause (§4).

## 2. Approved business rules (source of truth)

From `docs/BrokerBridge_Buyer_PRD_v1.3_FINAL.md`:
- §4: "Seller confidential minimum price and private Seller negotiation notes **never reach Buyer**."
- §4: "Buyer receives Seller-side commercial supply only through Broker Proposals."
- §4: "Buyer cannot browse/search a Seller directory."
- §2: Broker ↔ Seller covers "supply discovery…"; "Exposing Seller private information to Buyer" is **not allowed**.

**Intended access, derived from the PRD and existing server code.** `broker-supply-actions.ts:76` says: "The Broker IS authorized to see the Seller's confidentialMinimumPrice to establish the negotiation floor".

| Role | Read listings | Read min price / Seller company | Insert | Update | Delete |
|---|---|---|---|---|---|
| Buyer | **No** (supply only via Broker Proposals) | **No** | No | No | No |
| Seller (owning company) | Own company's listings | Own values | Own listings (PRD) | Own listings (PRD) | — (status change, not delete) |
| Seller (other company) | **No** | **No** | — | — | — |
| Broker | Global listings + listings assigned to them (matches server actions) | Yes (negotiation floor) | Yes, as assigned broker | Assigned listings | No |
| Admin | All | Yes | Yes | Yes | No policy (none today) |
| Anonymous | No | No | No | No | No |

## 3. Reproduction (live, counts only)

**Population:** 3 listings, all `visibility = 'global'`, all 3 with a minimum price set, 3 distinct Seller companies, 1 broker.

| Simulated session | Listings visible | Min-price values visible | Seller company IDs visible | Should see |
|---|---|---|---|---|
| anon | **denied** (42501) | — | — | none ✓ |
| Buyer | **3** | **3** | **3** (3 distinct) | 0 ✗ |
| Seller, *other* company | **3** | **3** | **3** | 0 ✗ |
| Authenticated, **no profile row** | **3** | **3** | **3** | 0 ✗ |
| Broker, assigned | 3 | 3 | 3 | 3 ✓ |
| Broker, unassigned | 3 | 3 | 3 | 3 (global) ✓, per current design |
| Admin | 3 | 3 | 3 | 3 ✓ |
| Seller, owning company | *not testable* | | | No user belongs to any of the 3 owning companies |

**Seller names.** Buyers and other Sellers can't resolve Seller company *names*: `companies` RLS returns only their own company, and a join gave 0 Seller names. So P2 exposes opaque identifiers that allow linking, not names. Brokers and admins can read Seller names (3 of 3), which is intended.

## 4. Access paths examined

| Path | Exposes min price / Seller ID to unauthorized roles? | Evidence |
|---|---|---|
| **PostgREST `GET /rest/v1/availabilities`** (any client with the anon key + a user JWT) | **Yes (P1, P2)** | Policy `availabilities_select_policy`: `broker_id = auth.uid() OR visibility = 'global' OR is_admin()`. `authenticated` has table-level `SELECT` (no column restriction). |
| PostgREST embedding via `requirement_allocations` / `lab_tests` / `availability_quality_values` → `availabilities` | Same as above; embedded rows obey the same policy | FK parents of `availabilities`. `lab_tests` and `availability_quality_values` are denied to `authenticated` anyway. |
| Views / materialized views over `availabilities` | No | none exist |
| SQL functions / RPCs referencing `availabilities` or "confidential" | No | none exist in `public` |
| Other columns holding a minimum price | No | the only matching column is `availabilities.confidential_minimum_price` |
| JSON payloads (`deal_versions.snapshot_payload`, `negotiation_events.payload`, `notifications.payload`, `master_grades.parameters`) | No | 0 rows contain `confidential` / `minimum_price` / `minimumPrice` keys |
| Realtime (`supabase_realtime`) | No | only `quotations` is published; it has no min-price column |
| Storage `brokerbridge_lab_evidence` | No | SELECT limited to admin/broker or the listing's own company |
| **Next.js server actions** (DB role bypasses RLS) | **No** | Broker actions check `role ∈ {broker, admin}`: `broker-supply-actions.ts:108`, `broker-match-actions.ts:127`, `broker-negotiation-actions.ts:79/306/433/662`, `broker-mandate-actions.ts:154` via `getAuthenticatedBroker`. Seller actions use `verifySellerSession`. Buyer-channel actions strip the field via `sanitizePayloadForBuyer` / `sanitizeBuyerNegotiationPayload` (e.g. `broker-buyer-actions.ts:518`). |
| RMBuyer mobile | No reads of `availabilities` | the app itself never requests it, but its users can (P1) |
| RMSeller mobile | Reads with `company_id = own` filter | the filter is client-side only; the server returns all global rows to any seller |
| RMBroker mobile | Reads min price (authorized) | `work_repository.dart`, `offer_model.dart` |

## 5. Role-resolution check (needed for a safe fix)

`is_broker()` and `is_admin()` call `get_auth_role()`. That reads `auth.users.raw_app_meta_data.role`, which users can't set themselves, or a self-declared `buyer`/`seller` from user metadata.

- **Brokers and admins:** every one that can sign in resolves correctly (1 broker → `broker`, 1 admin → `admin`). The one `public.users` broker row without an auth account can't sign in anyway.
- **Profile-less accounts:** 2 auth accounts have no `public.users` row (self-declared `seller`). Today they read all minimum prices.
- **Users without auth accounts:** 13 `public.users` rows have no auth account (seed/demo), so they can't sign in.

So a policy keyed on `is_broker()` / `is_admin()` keeps every working broker and admin.

## 6. Proposed remediation (smallest safe change) — NOT APPLIED

**R1 — make the SELECT policy role-aware.** This needs approval and is one migration.

```sql
-- DRAFT ONLY — do not apply without approval
BEGIN;
DROP POLICY IF EXISTS availabilities_select_policy ON public.availabilities;
CREATE POLICY availabilities_select_policy ON public.availabilities
  FOR SELECT TO authenticated
  USING (
    public.is_admin()
    OR (public.is_broker() AND (broker_id = auth.uid() OR visibility = 'global'))
    OR company_id = public.current_user_company_id()   -- owning Seller only
  );
COMMIT;
```

**Helper function.** The owning-Seller clause needs a `SECURITY DEFINER`, `search_path=''` helper `public.current_user_company_id()`, returning `company_id` from `public.users` for `auth.uid()` (or for seller-role users only). It avoids RLS recursion on `users`. If an equivalent helper already exists, reuse it.

**Rollback:** recreate the current policy text (recorded in §4).

**Effect:**

| Role | Before | After |
|---|---|---|
| Buyer | all global rows, all columns | **0 rows** |
| Seller, other company | all global rows | **0 rows** |
| Seller, owning company | own rows only while global; **restricted own rows invisible** (latent bug) | all own rows |
| Profile-less account | all global rows | **0 rows** |
| Broker | global + assigned | unchanged |
| Admin | all | unchanged |
| Anonymous | denied | denied |
| Next.js server actions | unaffected (bypass RLS; already guarded) | unaffected |

**Expected client impact:**
- **RMBuyer:** none; it never reads listings.
- **RMBroker:** none.
- **RMSeller:** reads of its own listings keep working and now include restricted listings.
- **Web app:** none.

**Why not column grants?** Revoking the column from `authenticated` would also hide it from brokers, who use the same database role, and break RMBroker's negotiation floor. Doing it that way needs a broker-only RPC: more change for the same result.

**Optional follow-ups (separate approvals, not required for P1/P2):**
- **R2:** decide whether *unassigned* brokers may see the minimum price of global listings. Current server design says yes; restricting it needs a column split or RPC.
- **R3:** Seller write path. The insert and update policies admit only broker/admin, so RMSeller can't create or update its own listings (seen in earlier sprints). This is a functional fix that must not widen read access.
- **R4:** the default-ACL `TRUNCATE` / `TRIGGER` / `REFERENCES` grants to `authenticated` on `availabilities` (already SEC-PRIV-01). They're not reachable through PostgREST, but should be revoked as hardening.
- **R5:** decide whether open self-registration should create active accounts, or require approval/KYC before data access (P3).

## 7. Remediation test plan (for the approved follow-up)

1. **SQL authorization suite.** Run against a staging/branch database, or read-only on production after apply. For each role (anon, Buyer, Seller-owner, Seller-other, profile-less, Broker-assigned, Broker-unassigned, Admin), assert the row counts and min-price visibility in the "After" table. Also assert INSERT/UPDATE outcomes inside rolled-back transactions on staging.
2. **Seller-owner fixture.** Production has no user in an owning company, so this case needs a staging fixture.
3. **Static checks.** Repeat that no Buyer client code selects `availabilities`, and that Buyer-channel server payloads are scrubbed (existing scrubber tests).
4. **Regression.** RMBroker test suite (work, offers, search), RMSeller listing tests, and Next.js broker actions smoke tests.
5. **Approval gate.** Production apply only after approval, with the rollback SQL ready.

## 8. Outstanding approvals

- **A1:** approve R1, the role-aware `availabilities` SELECT policy plus the helper function, as a migration. Needed to close P1/P2.
- **A2:** choose where to verify: a staging/branch database (recommended), or production with read-only post-checks.
- **A3:** decisions on R2 (unassigned-broker minimum price), R3 (Seller write path), R4 (default ACL hardening) and R5 (self-registration).
- **A4:** whether to treat P1 as an incident. It's unknown whether any Buyer or self-registered account has queried the table, since PostgREST access logs weren't inspected. Reviewing the Supabase API logs requires dashboard access.
