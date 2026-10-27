# RB-SELLER-AVAILABILITY-RLS-FIX-02 — Production Review

## 1. Situation
- **Production** (`imztlkvkxzeaekxvmcfe`, the only configured project) **already runs migration 0044**. It was applied in FIX-01 after the owner's "approve".
- This sprint authorizes **staging only**, so that apply was outside what is now authorized.
- No staging exists, so the staging-first workflow cannot be carried out as written.

## 2. Exact migration in production
`supabase/migrations/0044_allow_sellers_own_availabilities.sql`, the same SQL as `RB-SELLER-AVAILABILITY-RLS-FIX-01-PROPOSED-SQL.md` §5:

| Part | Change |
|---|---|
| A | INSERT policy + active seller, own company |
| B | SELECT policy + active seller, own company |
| C | UPDATE policy + active seller, own company (USING and WITH CHECK) |
| D | `prevent_self_company_change()` with trigger `trg_prevent_self_company_change` on `public.users` |

Verified live, read-only, after commit: the policy text matches, the trigger is present, and the lot count is unchanged at 3.

## 3. Owner decision required (choose one)
| Option | Effect | Risk |
|---|---|---|
| **1. Keep 0044 in production** (ratify) | Sellers can post and update their own lots; FIX-01 security checks hold | Not validated on a staging copy, but validated by 10/10 in-transaction impersonated checks on production itself |
| **2. Roll back now, redo staging-first** | Run `supabase/migrations/rollback_0044.sql` on production, then set up staging, apply and test there, and re-approve for production | Seller posting and price updates stop working again until re-applied. The rollback recreates the exact pre-0044 policies and is safe to run now: no seller lots exist yet that depend on the new SELECT or UPDATE branches. |
| **3. Keep for now, set up staging, re-validate later** | As option 1, plus a staging re-test later | As option 1 |

**Assessment:**
- Rollback is clean and low-risk **today**: there are 3 rows, none created through the seller branch.
- Once a seller posts restricted lots, rolling back would hide them from that seller (SELECT) and block their edits (UPDATE). It would not delete anything.

## 4. If option 2 is chosen: exact rollback to run (needs explicit approval)
`supabase/migrations/rollback_0044.sql`:
1. `DROP TRIGGER IF EXISTS trg_prevent_self_company_change ON public.users;`
2. `DROP FUNCTION IF EXISTS public.prevent_self_company_change();`
3. Recreate the three `availabilities` policies exactly as before 0044.

All of it runs in one transaction, followed by a read-only check that the policy text equals the pre-0044 capture.

## 5. To make staging possible
Provide a staging Supabase project, or enable a branch, and pass its `DATABASE_URL` and URL out of band. Then:
1. Bring staging to the pre-0044 state.
2. `node scripts/apply-migration-0044.mjs --dry-run`, then the real run.
3. Device test against staging with a test seller account.

## 6. Not done in this sprint (as instructed)
- No production writes, no account changes, no rollback, no production write tests.
- The pending device test (one real listing) was **not** performed and is on hold until the owner decides.
