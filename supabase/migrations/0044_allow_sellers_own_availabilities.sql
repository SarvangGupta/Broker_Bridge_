-- APPLIED 2026-10-27 to project imztlkvkxzeaekxvmcfe after owner approval (RB-SELLER-AVAILABILITY-RLS-FIX-01)
-- via scripts/apply-migration-0044.mjs (single transaction, 10/10 impersonated checks before COMMIT).
--
-- Problem (verified on the live project, read-only, 2026-10-27):
--   availabilities_insert_policy WITH CHECK
--     (((broker_id = auth.uid()) AND (is_broker() OR is_admin())) OR is_admin())
--   has no seller branch, so every seller INSERT fails with 42501.
--   SELECT / UPDATE likewise only cover broker_id = auth.uid() (+ global rows for SELECT).
--
-- Ownership model: a seller owns rows whose company_id equals the company on the
-- seller's own public.users row. users.role cannot be self-changed (users_update_policy
-- pins it to the trusted get_auth_role()); part D below makes company_id equally
-- immutable for non-admins, so a seller cannot re-point themselves at another company.

BEGIN;

-- A. INSERT: add "seller inserting for their own company". Broker and admin branches unchanged.
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

-- B. SELECT: sellers also read their own company's lots (incl. 'restricted' ones).
--    Required for INSERT ... RETURNING, which the app uses to confirm the new id.
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

-- C. UPDATE: sellers may update their own company's lots (price, status, broker),
--    and may not move a lot to another company (WITH CHECK re-checks the new row).
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

-- D. Guard the ownership anchor: non-admins cannot change their OWN company_id.
--    (Today users_update_policy lets a user update any column of their own row.)
--    Admin provisioning and broker-managed counterparties are unaffected.
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

-- No GRANT changes: authenticated already has SELECT/INSERT/UPDATE (0038); anon has none.
-- No DELETE policy is added (sellers still cannot delete lots).

COMMIT;
