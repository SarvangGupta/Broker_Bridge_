# RB-SEC-PRIV-02 — Profile Trust-Field Protection Audit

Date: 2026-10-25 · Branch: `feature/broker-nilesh` · **Status: PASS WITH LIMITATIONS** (audit complete; see §7) · **Audit only**

**No code, SQL, schema, RLS, grant, trigger, RPC or configuration was changed, and no write query was executed.** Live evidence came from `BEGIN READ ONLY` transactions. Role simulation used `SET LOCAL ROLE authenticated` plus JWT claims inside savepoints that were rolled back. Only metadata, policy text and row **counts** were read. No user data or secrets were read.

## 1. Executive summary

The trust fields `companies.is_verified` (boolean, default `false`) and `companies.trust_score` (integer, default `100`) have **no server-side protection**. The `authenticated` role holds table-wide `INSERT`/`UPDATE` on `companies`, with no column restriction, trigger or validating function. Three row-security policies give write access to non-admins:

| ID | Severity | Finding | How verified |
|---|---|---|---|
| **T1** | **Critical** | A Buyer or Seller can set **their own company's** `is_verified`, `trust_score` and `status` (and `gst`) through the Supabase REST API | Policy + column privilege + predicate evaluation (1 row in scope for a test buyer and a test seller) |
| **T2** | **Critical** | A Buyer or Seller can **repoint their own `users.company_id` to another company**, then change that company's trust fields (cross-tenant) | Policy and privilege logic. Not executed, because it requires a write |
| **T3** | **Critical** | A Broker can change trust fields on **any company**: link it through a new `crm_contacts` row (no `company_id` constraint), then update it through `crm_companies_update_policy` | Policy logic. A test broker already has **10 companies** in update scope, all other organizations |
| **T4** | High | A Broker can **insert** a company with `is_verified = true` and any `trust_score` (the insert check doesn't cover these columns) | Policy text + column privilege |
| **T5** | High | `companies.status` is treated as equivalent to verification (`status OR is_verified` means APPROVED) and is writable through T1–T3. `users.status`, which admin rejection sets to `false`, is self-writable | Code + policy |
| T6 | Info | Clients: RMBuyer never sends trust fields. RMSeller sends `name/gst/state/district`. RMBroker sends `name/status` on updates and **`is_verified`/`trust_score`/`status` on inserts**. The backend neither rejects nor ignores them | Code |
| T7 | Info | The legitimate writer is the web admin approve/reject actions only (server-side role check, bypass-RLS DB connection). **No workflow sets `trust_score` at all** | Code |

**Amplifier (from RB-SEC-PRIV-01):**
- **Open sign-up:** anyone can self-register as a buyer or seller, and the anon key ships in the apps, so T1/T2 are reachable by anyone.
- **Company ID leak:** the target company IDs T2 needs are readable by any signed-in user through `availabilities.company_id`.

## 2. Answers to the audit questions

1. **Can Buyers, Sellers or Brokers change their own values?**
   - **Buyers and Sellers: yes** (T1), directly through PostgREST, e.g. `PATCH /rest/v1/companies?id=eq.<own>` with `{"is_verified":true,"trust_score":100}`. None of the apps does this, but the API allows it.
   - **Brokers:** brokers own no company in the current data (own-company policy covers 0 rows). They can still create or link a company and set its fields (T3/T4).
2. **Can one user change another user's values?** **Yes.**
   - Buyers and Sellers via T2: repoint `company_id`, then update.
   - Brokers via T3: insert a `crm_contacts` link, then update.
3. **Do mobile clients submit protected fields, and does the backend reject them?**
   - **RMBroker:** `directory_repository.dart:402-411` inserts `is_verified: false, trust_score: 100, status: true`; `:524-529` updates `status`.
   - **The backend accepts** whatever is sent. Nothing rejects or strips these fields.
   - **RMBuyer:** writes only `users.name/mobile` (`buyer_profile_repository.dart`, `editableColumns = {name, mobile}`).
   - **RMSeller:** writes `companies.name, gst, state_id, district_id` (`seller_profile_repository.dart:77, 233-238`).
4. **Are the policies and privileges sufficient?** **No.**
   - **Columns:** `has_column_privilege('authenticated','companies', c, 'UPDATE'|'INSERT')` is true for `is_verified`, `trust_score`, `status`, `gst` and `name`.
   - **No guard:** no trigger and no function references `is_verified` or `trust_score`.
   - **Policies are row-level only** and OR'd across three UPDATE policies.
   - **Other writers:** server actions use a direct Postgres connection (`db`, bypasses RLS). Their safety depends only on their own code checks, which are correct for these fields (T7).
5. **Who is authorized to verify a company and set its trust score?** In code, only `public.users.role = 'admin'`. This is enforced in `approveCompanyAction` / `rejectCompanyAction` and mirrored by RLS policy "Tier 0 admin users full access to companies". **No business rule or workflow exists for `trust_score`**; current values (82–100) come from seed data. → *Owner decision D1.*
6. **Legitimate Admin workflow:** yes, for verification only (§4).
7. **Smallest safe remediation:** §5.
8. **Tests:** §6.

## 3. Evidence

### 3.1 Schema

- **Migration:** `supabase/migrations/0015_add_company_trust_scores.sql:4-6` adds `is_verified BOOLEAN NOT NULL DEFAULT false` and `trust_score INTEGER NOT NULL DEFAULT 100` to `public.companies`.
- **Live data:** 16 companies; 13 `is_verified = true`; `trust_score` 82–100; 16 `status = true`.
- **Scope:** no other table has these columns.

### 3.2 Grants and column privileges (live)

- **`companies`:** `authenticated` has `DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE`; `anon` has none.
- **Columns:** `authenticated` may UPDATE and INSERT `is_verified`, `trust_score`, `status`, `gst` and `name`.
- **`users`:** `authenticated` may UPDATE `company_id` and `status`.

### 3.3 Policies on `public.companies` (live)

| Policy | Cmd | Predicate |
|---|---|---|
| Tier 0 admin users full access to companies | ALL | `EXISTS (users.id = auth.uid() AND users.role = 'admin')` |
| **Users can update their own company** | UPDATE | USING/CHECK `id IN (SELECT company_id FROM users WHERE id = auth.uid())` (**no column limit**) → T1, T2 |
| **crm_companies_update_policy** | UPDATE | `is_admin() OR created_by = auth.uid() OR EXISTS (crm_contacts WHERE company_id = companies.id AND broker_id = auth.uid())` → T3 |
| **crm_companies_insert_policy** | INSERT | CHECK `(is_broker() OR is_admin()) AND (created_by IS NULL OR created_by = auth.uid())` (**trust columns unconstrained**) → T4 |
| Users can select their own company / crm_companies_select_policy | SELECT | (read paths) |

**Related policies:**
- **`users_update_policy`:** CHECK `is_admin() OR (id = auth.uid() AND lower(role) = get_auth_role()) OR (broker-contact clause)`. Only `role` is pinned on self-updates, so `company_id` and `status` are free → T2, T5.
- **`crm_contacts_insert_policy`:** CHECK `((broker_id = auth.uid()) AND (is_broker() OR is_admin())) OR is_admin()`. `company_id` is unconstrained → T3.
- **Triggers:** the only trigger on `users`/`companies` is `trg_sync_privileged_role` (on `users`, syncing role into `auth.users.raw_app_meta_data`). It doesn't touch the trust fields.

### 3.4 Predicate evaluation (simulated sessions, counts only)

| Session (auth role) | Companies selectable | Rows in "own company" UPDATE scope | Rows in CRM UPDATE scope | …of which not own company |
|---|---|---|---|---|
| Buyer (`buyer`) | 1 | **1** | 0 | 0 |
| Seller (`seller`) | 1 | **1** | 0 | 0 |
| Broker (`broker`) | 10 | 0 | **10** | **10** |
| Admin (`admin`) | 16 | 0 | 16 | 16 (intended) |

### 3.5 Application write paths

| Location | Writes | Trust fields? | Auth |
|---|---|---|---|
| `src/server/actions/company-actions.ts:268-289` `approveCompanyAction` | `companies.status = true, is_verified = true`; `users.status = true` | **yes (legitimate)** | `auth.getUser()` + `public.users.role === 'admin'` (`:274-279`) |
| `company-actions.ts:291-312` `rejectCompanyAction` | `status = false, is_verified = false`; `users.status = false` | **yes (legitimate)** | same (`:297-302`) |
| `company-actions.ts:35-43` `createCompanyProfile` (update) | name, gst, state, district, business type | no | signed-in user, own company |
| `company-actions.ts:55-63` (insert) | new company, `status: false, isVerified: false` | defaults only | signed-in user |
| `src/server/actions/user-profile-actions.ts:56-61` | name, gst, state, district | no | own company |
| `src/server/actions/broker-directory-actions.ts:503-512` | insert company `status: true, isVerified: false, trustScore: 100` | sets defaults; `status: true` (T5) | broker session |
| `broker-directory-actions.ts:646-654` | name, district, state, **status** | `status` (T5) | broker session |
| `apps/rmbroker_mobile/.../directory_repository.dart:402-411` | **PostgREST insert** with `is_verified`, `trust_score`, `status: true` | **client-chosen** (T4/T6) | RLS only |
| `directory_repository.dart:524-529` | PostgREST update name, district, state, **status** | `status` | RLS only |
| `apps/rmbroker_mobile/.../profile_repository.dart:214-216` | PostgREST update `companies.name` | no | RLS only |
| `apps/rmseller_mobile/.../seller_profile_repository.dart:77, 233-238` | PostgREST update name, **gst**, state, district | no (gst is KYC) | RLS only |
| `apps/rmbuyer_mobile/.../buyer_profile_repository.dart` | `users.name`, `mobile` only | no | RLS only |

- **`trust_score` writer:** none, besides defaults and seed data.
- **Reads:** `seller_ratings_repository.dart:288-296` and several web actions read `trust_score`.

**Approval-equivalence code (T5):** `company-actions.ts:140` and `:199` compute `isApproved = Boolean(status) || Boolean(isVerified) …`, so writing `status = true` alone yields APPROVED onboarding.

## 4. Current legitimate Admin workflow

- **UI:** web admin `app/(admin)/admin/_components/company-approval-queue.tsx`.
- **Server action:** `approveCompanyAction` / `rejectCompanyAction` (`src/server/actions/company-actions.ts:268-312`).
- **Authorization:** Supabase session `auth.getUser()` → `public.users` row → `role === 'admin'`.
- **Write path:** the Drizzle `db` connection (direct Postgres, bypasses RLS).
- **What it sets:** `companies.status` and `companies.is_verified` together, and the company users' `status`.
- **Not covered:** `trust_score` (none).

Database-side, admins also pass RLS through "Tier 0" and `is_admin()`. No admin mobile path writes these fields.

## 5. Recommended minimal remediation (proposed only; each needs approval)

**P1 — Lock trust fields at the database (fixes T1–T4 for these columns).** The recommended option is a column-privilege split. It is declarative, and it doesn't affect server actions, which don't use the `authenticated` role.

```sql
-- DRAFT ONLY — not applied
REVOKE INSERT, UPDATE ON public.companies FROM authenticated;
GRANT INSERT (name, gst, state_id, district_id, business_type_id, created_by) ON public.companies TO authenticated;
GRANT UPDATE (name, gst, state_id, district_id, business_type_id)            ON public.companies TO authenticated;
-- is_verified, trust_score, status: writable only by the server-side admin path (and service role).
```

- **Effect:** PostgREST rejects any request carrying `is_verified`, `trust_score` or `status` from a client, with 42501.
- **Admin:** admin verification through the web server action keeps working, because it uses the direct DB connection.
- **Alternative (if admins must also write via PostgREST):** a `BEFORE INSERT OR UPDATE` trigger. When `NOT public.is_admin()` and the session is an API role, it raises if the trust columns change, and forces defaults on insert.

**P2 — Stop self-repointing and self-reactivation on `users` (fixes T2, part of T5).** Use a `BEFORE UPDATE` trigger on `public.users`. When `NEW.id = auth.uid() AND NOT public.is_admin()`, it rejects changes to `company_id`, `status` and `role`. A trigger is preferred over column grants because brokers legitimately update *contacts'* `status`/`role` today (`directory_repository.dart:514-520`); that's a decision, see D3.

**P3 — Constrain broker CRM links (fixes T3).** Tighten the `crm_contacts` INSERT/UPDATE CHECK so `company_id` must be a company the broker created (`companies.created_by = auth.uid()`) or one with no other owner. The exact rule needs the CRM business definition (D2).

**P4 — Client clean-up (required for P1 compatibility; no security value on its own).**
- **RMBroker:** remove `is_verified`, `trust_score` and `status` from the `directory_repository.dart:402-411` insert, and `status` from `:524-529`; otherwise those calls fail after P1.
- **RMSeller:** decide whether `gst` stays self-editable (D4).

**P5 — Trust score ownership (D1).** Define who sets `trust_score` (admin-only RPC with audit, or system-computed) before any writer is built. Until then, P1 leaves it read-only for every API role.

**P6 — Decouple approval from `status` (T5, optional).** Base onboarding approval on `is_verified` only, or keep `status` but protect it under P1, as drafted.

**Order:** P1 → P4 (same release) → P2 → P3. P5 and P6 follow the owner decisions.

## 6. Regression and security test plan

Run on a staging or branch database with authorized test accounts. For each role (anon, buyer, seller, broker, admin), with writes inside transactions that are rolled back:

| # | Case | Expected after fix |
|---|---|---|
| 1 | Buyer PATCH own company `is_verified`, `trust_score` or `status` | 42501 / rejected; values unchanged |
| 2 | Seller, same as #1 | rejected |
| 3 | Buyer/Seller PATCH own company `name`, `state_id` (and `gst` if D4 allows) | succeeds; other columns unchanged |
| 4 | Buyer PATCH own `users.company_id` to another company | rejected (P2) |
| 5 | Buyer PATCH own `users.status = true` after rejection | rejected (P2) |
| 6 | Broker INSERT company with `is_verified = true` / `trust_score = 500` | rejected (P1) |
| 7 | Broker INSERT `crm_contacts` for an unrelated company, then PATCH it | link rejected (P3); PATCH has no rows |
| 8 | Broker PATCH a CRM company's trust fields | rejected (P1) |
| 9 | RMBroker directory create/update (after P4) | succeeds |
| 10 | Admin web `approveCompanyAction` / `rejectCompanyAction` | sets `status` + `is_verified` as today |
| 11 | Non-admin calls `approveCompanyAction` | "Admin access required"; no change |
| 12 | anon PATCH or INSERT companies | rejected |
| 13 | RMBuyer Edit Profile (name, mobile) and RMSeller profile save | succeed |
| 14 | Existing suites: RMBuyer, RMSeller, RMBroker, web admin/company tests | unchanged results |

Also add a static check that no mobile client includes `is_verified`, `trust_score` or `status` in a `companies` write payload.

## 7. Limitations

- **Not exercised:** T2 and T3 were proven from live policy text, column privileges and predicate evaluation, not by executing UPDATE/INSERT, because writes are prohibited in this sprint. T1's write scope was confirmed the same way: 1 row covered by the USING/CHECK predicate, plus the column privilege.
- **Not reviewed:** PostgREST/API logs (dashboard access needed), so whether any of these paths has been used is unknown. The 13 verified and 3 unverified companies weren't traced to their writer.
- **Service role:** the `service_role` key isn't used by the mobile apps (`grep` found no usage), and its own grants weren't analysed here.

## 8. Decisions requiring owner approval

- **D1:** who sets `trust_score`, and how (admin-only with audit, or computed)?
- **D2:** the CRM rule. Which companies may a broker link to and edit?
- **D3:** should brokers keep the ability to change a contact's `users.status` / `role` from the mobile directory?
- **D4:** is `companies.gst` self-editable by Buyers and Sellers, or locked after verification?
- **D5:** should onboarding approval depend on `status`, `is_verified`, or both (T5)?
- **D6:** approve P1–P4 as migrations and client changes. A staging verification run is recommended first.
- **D7:** treat this as an incident? That requires reviewing API logs for `PATCH /companies` and `PATCH /users` by non-admins.

## 9. Change statement

This sprint made no code, migration, schema, RLS, grant, trigger, RPC, configuration or data changes. The only new file is this report. The audit doesn't fix any vulnerability.
