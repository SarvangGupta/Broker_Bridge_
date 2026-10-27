# RB-SELLER-AVAILABILITY-RLS-FIX-01 — Audit Report

**App:** RM Seller · **Date:** 2026-10-27 · **Error:** `new row violates row-level security policy for table "availabilities"` (42501)

## 1. Flow traced
1. **Submit:** `PostCommodityScreen` → Review & List → `_handleSubmit()` → `CommoditiesRepository.createCommodity(dto)`.
2. **Insert:** `client.from('availabilities').insert(dto.toSupabaseInsert(companyId)).select('id, created_at, status').single()`.
3. **Payload ownership fields:** `company_id` and an optional `broker_id` (the trusted broker). There is no user or seller column. `availabilities` has no `seller_id` or `user_id`; ownership is **`company_id`** (FK to `companies`, migration 0004).
4. **Company resolution before the fix:** the stored company ID from sign-in, then the `users` row, then a **hard-coded fallback `20000000-…-0101`**.
5. **Session:** the device log showed authenticated requests (`… TO authenticated` hints) after RB-SELLER-POST-CATEGORY-FIX-01, so this is not an anon or session problem.

## 2. Live schema and policy evidence (read-only)
Read-only transaction (`BEGIN READ ONLY … ROLLBACK`) against the configured project using `DATABASE_URL`. No personal data was printed.

| Item | Live value |
|---|---|
| RLS on `availabilities` | enabled (not forced) |
| Triggers on `availabilities` | none |
| Grants to `authenticated` | SELECT, INSERT, UPDATE (+ REFERENCES, TRIGGER, TRUNCATE) |
| `availabilities_insert_policy` WITH CHECK | `((broker_id = auth.uid()) AND (is_broker() OR is_admin())) OR is_admin()` |
| `availabilities_select_policy` USING | `(broker_id = auth.uid()) OR (visibility = 'global') OR is_admin()` |
| `availabilities_update_policy` USING / CHECK | `(broker_id = auth.uid()) OR is_admin()` |
| `public.users` rows with role `seller` | 7: 3 with a company, 2 with `seller` in app_metadata (trusted), 5 without an auth user (CRM contacts) |
| `availabilities` rows | 3 total |

These match migration `0038_add_operational_desk_rls_and_grants.sql` (RB-DB-SEC-01) exactly.

## 3. Root cause
**The INSERT policy has no seller branch.** Only a broker inserting with `broker_id = auth.uid()`, or an admin, passes. A seller's insert is rejected regardless of payload, identity mapping or session. The other hypotheses were ruled out:

| Hypothesis | Finding |
|---|---|
| Missing or incorrect ownership field | `company_id` is sent; the policy never looks at it |
| Seller vs user ID mix-up | The policy checks only `broker_id` against `auth.uid()` |
| Missing or expired session | Requests are authenticated |
| Trigger rewriting values | No triggers exist |
| Wrong environment | The app's project serves the same policies |

### Related gaps found (same root)
- **SELECT:** a seller cannot read their own `restricted` lots. This also breaks `INSERT … RETURNING`, which the app uses to confirm the new ID.
- **UPDATE:** a seller cannot update their own lots, which blocks price and status changes (RB-SELLER-PRICE-SYNC-FIX-01).
- **Tenant-isolation risk if fixed naively:** `users_update_policy` lets a user update any column of their own row except `role`, including `company_id`. A policy that trusts `users.company_id` must also stop self-changes to it.
- **App:** the insert path could fall back to a hard-coded company ID (`…0101`).
