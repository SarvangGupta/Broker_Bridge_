# RB-SELLER-AVAILABILITY-RLS-FIX-02 — Security Test Report

No staging tests were run, because no staging exists (see the staging report). Below: the security review done in this sprint (read-only and by code review), plus the evidence already gathered in FIX-01 on production.

## 1. Policy review of 0044 (Phase 1, steps 6–8)
| Concern | Finding |
|---|---|
| Broad access | None. The new branches apply only `TO authenticated`, and every one requires the caller's own `users` row: `role = 'seller'`, `status = true`, `company_id` not null and equal to the row's `company_id`. No new grants. No `anon` or `PUBLIC`. |
| Policy interaction | Each command has a single permissive policy, so the new condition is OR-ed into existing rights. There are no other permissive policies on the table to combine with. |
| Privilege escalation via `role` | Blocked by the existing `users_update_policy` WITH CHECK `lower(role) = get_auth_role()`, where `get_auth_role` reads trusted `auth.users.raw_app_meta_data`. |
| Privilege escalation via `company_id` | Blocked by `trg_prevent_self_company_change`: `NEW.id = auth.uid()`, plus a change and not admin, raises 42501. |
| Admin process still works | Yes, in two ways. (1) An app admin passes `is_admin()`. (2) Service-role or SQL-editor updates have `auth.uid() = NULL`, so `NEW.id = NULL` is not true and the trigger does not fire. |
| Broker-managed counterparties | Unchanged: a broker may still edit `company_id` of sellers they created or have as CRM contacts (`id <> auth.uid()`). This is existing broker trust and a residual risk for owner review. |
| Delete | No DELETE policy exists before or after, so deletes are denied. |
| Rollback scope | `rollback_0044.sql` drops **only** `trg_prevent_self_company_change` and `prevent_self_company_change()`, and recreates the three `availabilities` policies **exactly as captured live before 0044**. It touches no other policy, table or grant. |

## 2. Tests actually executed (FIX-01, production `imztlkvkxzeaekxvmcfe`, in-transaction)
Impersonated with `SET LOCAL ROLE` and JWT claims, on synthetic rows rolled back via savepoint. The dry run and the committed run both passed **10/10**:

| Requirement (this sprint) | Executed check | Result |
|---|---|---|
| Seller (Company A) creates lot under A | #1 insert own-company restricted lot + RETURNING | PASS |
| Seller reads own A lots | #3 own restricted lot visible | PASS |
| Seller updates own lots incl. price | #4 update `asking_price` on own lot, 1 row | PASS |
| Cannot create under Company B | #2 | PASS (42501) |
| Cannot read or update B's lots | #3 (0 rows), #4 (0 rows) | PASS |
| Cannot move a lot to B | #5 | PASS (42501) |
| Cannot change own company | #6 | PASS (42501) |
| Broker policy intact | #8 broker inserts with `broker_id = self` | PASS |
| Buyer blocked | #7 | PASS (42501) |
| Anon blocked | #9 insert and select | PASS (42501 / 42501) |
| No unrelated privilege | #10 exactly 3 policies + trigger; no DELETE policy | PASS |

**Not executed:**
- An admin-role impersonation check (verified by code review only, see §1).
- **App end-to-end on the device:** posting a real lot, seeing it through the Home and My Commodities read paths, and a confirmed price update. No real seller lot exists yet (count is still 3).

## 3. App behaviour (automated, run in FIX-01: 74/74 passed)
- Success is shown only after the server returns the new ID. Price changes are shown only after the server returns the updated row (RB-SELLER-PRICE-SYNC-FIX-01).
- An RLS rejection (42501) shows "Your account is not yet allowed to publish listings…". It shows no raw error and keeps the form values.
- **Unlinked seller:** `createCommodity` reads `company_id` only from the caller's own `users` row. If it is null, it stops with "Your account is not linked to a company yet… Please contact support." There is no fallback ID and no bypass. **Verified by code review only;** a unit test for this branch needs a signed-in client and was not run.

## 4. Seller accounts without a company (Phase 4, read-only)
Seven `public.users` rows have role `seller`:

| user_id | Company | Login | Trusted role | Notes |
|---|---|---|---|---|
| 7ca27ae7-6e96-4c05-ab74-c7635f423428 | yes | yes | seller | real seller, can post |
| a302f4b7-916c-4340-bc15-88690379cbd8 | yes | yes | seller | real seller, can post |
| 06e2bf49-a0bd-4dfb-bfe0-955ab6aa179e | yes | **no** | — | broker-created CRM contact; cannot sign in |
| 00000000-0000-0000-0000-000000000201 | **no** | **no** | — | placeholder / seed CRM contact |
| 00000000-0000-0000-0000-000000000202 | **no** | **no** | — | placeholder / seed CRM contact |
| 00000000-0000-0000-0000-000000000203 | **no** | **no** | — | placeholder / seed CRM contact |
| 00000000-0000-0000-0000-000000000204 | **no** | **no** | — | placeholder / seed CRM contact |

- The **4 without a company** are the `…0201`–`…0204` placeholder records. None of them has a login, so none can be blocked from posting in practice.
- Every seller who can sign in is linked to a company.
- No records were modified.
- **For admin review:** whether these placeholder rows should be linked, given logins, or removed.
