# RB-SELLER-AVAILABILITY-RLS-FIX-01 — Proposed SQL (Review Gate)

**Status: NOT APPLIED. Awaiting explicit approval of this exact SQL.**
SQL file: `supabase/proposed/0044_allow_sellers_own_availabilities.sql` · Rollback: `supabase/proposed/rollback_0044.sql`

## 1. Target environment
- **Supabase project ref:** `imztlkvkxzeaekxvmcfe` (from `NEXT_PUBLIC_SUPABASE_URL`). This is the project the Seller App talks to; the device log shows its policy errors.
- **Environment:** this is the **only** configured database, the live/shared project. No separate staging database is configured in the repo, so "staging first" is not available unless you provide one.
- **Migration workflow:** the database has **no migration ledger**: neither `supabase_migrations.schema_migrations` nor a drizzle table. Earlier migrations were applied by one-off scripts in a transaction (see `scripts/apply-migration-0035.ts`). Phase E would follow that pattern: one transaction with in-transaction checks, then commit or rollback.
- All evidence below comes from read-only transactions (`BEGIN READ ONLY … ROLLBACK`) on 2026-10-27. No secrets or personal data were printed.

## 2. Verified schema and ownership model
`public.availabilities`:
- `id uuid` PK, default `gen_random_uuid()`
- **`company_id uuid NOT NULL`**, FK to `companies(id)`. **This is the ownership/tenant column.** There is no `seller_id` or `user_id`.
- `broker_id uuid NULL`, FK to `users(id)` (the assigned broker)
- `visibility text NOT NULL`, default `'global'`. The app sends `'restricted'` when a broker is selected.
- **No triggers.** RLS is enabled (not forced).
- Grants to `authenticated`: SELECT, INSERT, UPDATE (+ REFERENCES, TRIGGER, TRUNCATE). `anon` has none.

How a user maps to a seller and a company: `auth.uid()` = `public.users.id`, and `public.users.company_id` points to `companies`. The **two live seller logins** both have:
- `users.role = 'seller'`
- a non-null `company_id` with an existing `companies` row
- the trusted `auth.users.raw_app_meta_data.role = 'seller'`

**App payload** (`CreateCommodityDto.toSupabaseInsert`): `company_id` plus product, grade, unit, quantities, prices, state, district, `visibility`, `status`, lot fields, and optionally `broker_id`. Since the previous change, `company_id` is read from the caller's own `users` row; there is no hard-coded fallback any more.

## 3. Current relevant policies (live)
```
availabilities_insert_policy  INSERT  WITH CHECK
  (((broker_id = auth.uid()) AND (is_broker() OR is_admin())) OR is_admin())
availabilities_select_policy  SELECT  USING
  ((broker_id = auth.uid()) OR (visibility = 'global') OR is_admin())
availabilities_update_policy  UPDATE  USING / WITH CHECK
  ((broker_id = auth.uid()) OR is_admin())
```
There are no other policies on `availabilities`, so each command's effective policy is exactly the single policy shown.

`public.users` (relied on by the proposal):
- **SELECT** allows `id = auth.uid()`, so a seller can read their own row inside a policy subquery.
- **UPDATE** WITH CHECK pins self-updates to `lower(role) = get_auth_role()`: a user cannot change their own role.
- But **`authenticated` holds UPDATE on `users.company_id`**, and nothing restricts self-changes to it.

## 4. Root cause
The INSERT policy has **no branch that a seller can satisfy**:
- Branch 1 needs `broker_id = auth.uid()` **and** the caller to be a broker or admin.
- Branch 2 needs an admin.

A seller is rejected (42501) for every payload. The app payload is not at fault: it already supplies the correct `company_id`. Ruled out: no triggers, constraints satisfied, the session is authenticated (requests reach the `authenticated` role), and it's the correct project.

**Why SELECT also needs a change:** the app inserts with `.select('id, created_at, status')`, which is `INSERT … RETURNING`. In PostgreSQL that requires the new row to pass the SELECT policy. A lot posted to a chosen broker has `visibility = 'restricted'`, which no current SELECT branch admits for the seller. That insert would still fail with 42501.

**Why UPDATE is included:** sellers cannot update their own lots today, so the price and status changes from RB-SELLER-PRICE-SYNC-FIX-01 can never be saved. *You may approve A, B and D without C*; see §8.

## 5. Exact proposed SQL
```sql
BEGIN;

-- A. INSERT
DROP POLICY IF EXISTS "availabilities_insert_policy" ON public.availabilities;
CREATE POLICY "availabilities_insert_policy" ON public.availabilities
FOR INSERT TO authenticated
WITH CHECK (
  (broker_id = auth.uid() AND (public.is_broker() OR public.is_admin()))
  OR public.is_admin()
  OR EXISTS (
    SELECT 1 FROM public.users u
    WHERE u.id = auth.uid()
      AND LOWER(u.role) = 'seller'
      AND u.status = true
      AND u.company_id IS NOT NULL
      AND u.company_id = availabilities.company_id
  )
);

-- B. SELECT
DROP POLICY IF EXISTS "availabilities_select_policy" ON public.availabilities;
CREATE POLICY "availabilities_select_policy" ON public.availabilities
FOR SELECT TO authenticated
USING (
  broker_id = auth.uid()
  OR visibility = 'global'
  OR public.is_admin()
  OR EXISTS (
    SELECT 1 FROM public.users u
    WHERE u.id = auth.uid()
      AND LOWER(u.role) = 'seller'
      AND u.status = true
      AND u.company_id IS NOT NULL
      AND u.company_id = availabilities.company_id
  )
);

-- C. UPDATE
DROP POLICY IF EXISTS "availabilities_update_policy" ON public.availabilities;
CREATE POLICY "availabilities_update_policy" ON public.availabilities
FOR UPDATE TO authenticated
USING (
  broker_id = auth.uid()
  OR public.is_admin()
  OR EXISTS (
    SELECT 1 FROM public.users u
    WHERE u.id = auth.uid()
      AND LOWER(u.role) = 'seller'
      AND u.status = true
      AND u.company_id IS NOT NULL
      AND u.company_id = availabilities.company_id
  )
)
WITH CHECK (
  broker_id = auth.uid()
  OR public.is_admin()
  OR EXISTS (
    SELECT 1 FROM public.users u
    WHERE u.id = auth.uid()
      AND LOWER(u.role) = 'seller'
      AND u.status = true
      AND u.company_id IS NOT NULL
      AND u.company_id = availabilities.company_id
  )
);

-- D. Ownership-anchor guard on users.company_id
CREATE OR REPLACE FUNCTION public.prevent_self_company_change()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  IF NEW.id = auth.uid()
     AND NEW.company_id IS DISTINCT FROM OLD.company_id
     AND NOT public.is_admin() THEN
    RAISE EXCEPTION 'company_id can only be changed by an administrator'
      USING ERRCODE = '42501';
  END IF;
  RETURN NEW;
END;
$$;

REVOKE ALL ON FUNCTION public.prevent_self_company_change() FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS trg_prevent_self_company_change ON public.users;
CREATE TRIGGER trg_prevent_self_company_change
BEFORE UPDATE OF company_id ON public.users
FOR EACH ROW
EXECUTE FUNCTION public.prevent_self_company_change();

COMMIT;
```

## 6. Statement-by-statement
| Statement | Effect |
|---|---|
| A. DROP/CREATE INSERT policy | Keeps both existing branches word for word. Adds: the caller is an **active seller** whose **own** `users.company_id` equals the new row's `company_id`. |
| B. DROP/CREATE SELECT policy | Keeps the existing branches. Adds: an active seller sees rows of **their own company** (any visibility). Makes `INSERT … RETURNING` work. |
| C. DROP/CREATE UPDATE policy | Keeps the existing branches. Adds the same own-company test in **USING** (which rows may be targeted) and **WITH CHECK** (the updated row must still belong to the seller's company, so a lot cannot be moved to another tenant). |
| D. Function and trigger | Before any update of `users.company_id`: if a non-admin is changing **their own** row's company, the update is rejected with 42501. `SECURITY DEFINER` and an empty `search_path` follow the existing helper functions. EXECUTE is revoked (triggers fire regardless). |

`DROP POLICY` + `CREATE POLICY` runs inside one transaction, so there is no moment with the policy missing.

## 7. Seller and tenant isolation analysis
- **Policy combination:** each command keeps one permissive policy. The new branch is OR-ed, so the effective rule is exactly "existing rights **or** own-company seller". No new grants and no `TO anon` or `PUBLIC`.
- **Seller A cannot create for company B:** the INSERT check compares `availabilities.company_id` with A's **own** `users` row, found by `auth.uid()`. The payload's `company_id` must match it.
- **A cannot become B:**
  - `role` is already pinned by `users_update_policy` (`lower(role) = get_auth_role()`, which comes from trusted app_metadata).
  - `company_id` gets pinned by **D**. Without D, A could `UPDATE users SET company_id = <B's company>` on their own row and then pass checks A, B and C for B. **D is required for isolation, not optional.**
- **Non-sellers:** buyers, brokers (beyond their existing `broker_id` branch) and deactivated sellers (`status = false`) gain nothing.
- **Reads:** sellers see only their own company's restricted lots; global lots stay visible to all signed-in users as today.
- **Delete:** no policy exists before or after, so it stays denied.
- **Residual risk (pre-existing, unchanged):** a broker may still edit `company_id` on seller users they manage (`created_by` or `crm_contacts`) through `users_update_policy`. That is existing broker trust and is out of scope here.
- **`broker_id` set by a seller:** a seller can assign any user ID as `broker_id` (FK to `users`). That user then gains update rights on that lot through the existing `broker_id = auth.uid()` branch. This is today's assignment semantics and is unchanged.

## 8. Options
- **Recommended:** A + B + C + D. Posting, viewing own lots and price/status updates all work.
- **Minimal:** A + B + D. Posting works; price/status updates by sellers stay blocked. To choose this, delete section C.

## 9. Rollback
`supabase/proposed/rollback_0044.sql` drops the trigger and function, then recreates the three policies exactly as currently live (§3). Rows created in the meantime stay, owned by their company.

## 10. Validation plan (Phase E, after approval)
Run in a single transaction, using `SET LOCAL ROLE authenticated` and `SET LOCAL request.jwt.claims` to impersonate. Synthetic rows are created **inside the transaction and rolled back**, so nothing persists. Only then would the migration itself be committed.

| # | As | Action | Expected |
|---|---|---|---|
| 1 | seller S (company C) | INSERT lot `company_id = C`, `visibility = 'restricted'`, RETURNING id | succeeds, returns id |
| 2 | S | INSERT lot `company_id = D` | 42501 |
| 3 | S | SELECT own restricted lot / another company's restricted lot | 1 row / 0 rows |
| 4 | S | UPDATE own lot price / another company's lot | 1 row / 0 rows |
| 5 | S | UPDATE own lot `SET company_id = D` | 42501 (WITH CHECK) |
| 6 | S | `UPDATE users SET company_id = D WHERE id = auth.uid()` | 42501 (trigger D) |
| 7 | buyer | INSERT any lot | 42501 |
| 8 | broker | INSERT with `broker_id = self` | succeeds (unchanged) |
| 9 | anon | INSERT / SELECT | permission denied (unchanged) |
| 10 | — | `pg_policies` for `availabilities` | exactly the 3 policies in §5 |

After commit: post a real lot from the app on the device, then confirm it appears on Home and in details and that a price update persists. That creates **one real listing** for your seller account, so please confirm you want that test listing.

## 11. Remaining uncertainties
1. There is **no staging database**: the change would go straight to the live project (inside a transaction, with the checks above and a ready rollback).
2. The SQL has **not been syntax-run** against the database. Doing so takes table locks even in a transaction that rolls back, so it waits for approval. It is checked against the live definitions above.
3. Sellers whose `users.company_id` is null still cannot post (both current seller logins do have one).
