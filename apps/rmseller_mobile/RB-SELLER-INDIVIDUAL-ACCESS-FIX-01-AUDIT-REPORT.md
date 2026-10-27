# RB-SELLER-INDIVIDUAL-ACCESS-FIX-01 — Audit Report

**App:** `apps/rmseller_mobile` · **Date:** 2026-10-27 · **Evidence:** code, plus read-only production inspection (`BEGIN READ ONLY … ROLLBACK`, project `imztlkvkxzeaekxvmcfe`; IDs and booleans only)

## 1. Root cause
**Error:** "Failed to load dashboard metrics. Your account is not linked to a company yet. Please contact support."

1. `SellerHomeScreen._loadDashboardData()` calls `CommoditiesRepository.getCommodities()`. Any exception fails the **whole** dashboard.
2. `getCommodities()` (since RB-SELLER-POST-REGRESSION-01) resolved the company through `_requireOwnCompanyId()`. That method **throws** "not linked" when `users.company_id` is null **or the `users` row does not exist**.
3. **The account on the device is unprovisioned.**
   - The most recent seller sign-in (2026-10-27 07:55) is `49534f2f-…`.
   - It has **no `public.users` row**.
   - Its `seller` role exists **only in `user_metadata`** (self-editable); `app_metadata.role` is empty.
   - A second account, `4e21f195-…`, is in the same state.
   - The two provisioned sellers (`7ca27ae7-…`, `a302f4b7-…`) have rows and companies.

So the dashboard demanded a company merely to list lots. For an account that cannot own lots, the truthful answer is "none".

## 2. Live schema and policies relevant to company linkage
| Object | Finding |
|---|---|
| `availabilities.company_id` | **NOT NULL**; **no seller/user owner column** |
| `availabilities` RLS (0044, applied) | Seller insert/select/update only for `users.company_id = availabilities.company_id`; global lots readable by all authenticated users |
| `deals.seller_id` | NOT NULL. SELECT policy: `broker_id = auth.uid() OR is_admin()`, so **a seller can read no deals at all** |
| `companies` | Seller can read and update own company (via `users.company_id`) |
| `users` | Seller can read own row (`id = auth.uid()`); cannot change own role (pinned to `get_auth_role()`) or own company (0044 trigger) |
| `get_auth_role()` | Uses `app_metadata.role`, else `user_metadata.role` if buyer/seller. The latter is **self-asserted** |

## 3. Can identity be established from the user ID alone?
- **Yes, for reads:** `auth.uid()` is authoritative.
- **Not for seller authority:** for the unprovisioned accounts, the only "seller" evidence is self-editable `user_metadata`. A signed-up user can claim it. Granting listing **ownership** on that basis would let anyone become a seller.
- The proposal therefore requires a provisioned `users` row (role `seller`, `status = true`) before an individual seller can own lots.

## 4. Which operations need a company today
| Operation | Needs company? | Why |
|---|---|---|
| Open Seller Desk / Home | **No** (after fix) | Reads only |
| List own lots (Home, My Commodities, posting history) | **No** (after fix) | With no company there are no own lots: empty, not an error |
| Post a lot | **Yes** | `availabilities.company_id` NOT NULL + RLS. Changeable only by schema (proposal 0047) |
| Change price / broker / status | **Yes** | They act on own-company lots only |
| Deals metrics | Independent of company, but **seller has no read access** (RLS); the repository falls back to **demo deals** | Pre-existing; see §5 |
| Profile view | No (reads storage and `users`/`companies`; tolerant) | — |

## 5. Other fabricated-company sources found
| Location | Behaviour | Status |
|---|---|---|
| `auth_repository.dart` sign-in | Stored `user_metadata.company_id ?? '20000000-…-0101'` and a fake GST and firm name for unprovisioned sellers | **Fixed** |
| `seller_deals_repository.dart` | Filters `seller_id = <stored company>`; falls back to **demo deals** | Reported (out of scope; seller cannot read deals under RLS) |
| `negotiation_repository.dart` (×4), `notifications_repository.dart`, `seller_profile_repository.dart` (`updateProfile`), `seller_invoices_repository.dart` demo data | `companyId ??= '…0101'` | Reported (unrelated features; separate sprint) |
| `commodities_repository.dart` `createCommodity` offline branch, `_offlineCompanyId` | Demo company in **offline/test mode only**; the online path uses the server company | Unchanged |

## 6. Pending migrations
| Migration | State | Conflict with 0047 |
|---|---|---|
| 0044 | **applied** (production) | 0047 is written on top of the 0044 policy text |
| 0045 | proposed | Its unique `(company_id, lot_number)` skips rows with `company_id` NULL; 0047 adds `(seller_user_id, lot_number) WHERE company_id IS NULL` |
| 0046 | proposed | Both rewrite the INSERT/UPDATE policies. If both are approved, the broker check from 0046 must be added to 0047's seller branches (single combined migration recommended) |
