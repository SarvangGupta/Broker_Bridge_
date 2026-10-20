-- Rollback Migration: rollback_0041.sql
-- Restores previous users_select_policy and crm_companies_select_policy from migration 0037.

DROP POLICY IF EXISTS "users_select_policy" ON public.users;
CREATE POLICY "users_select_policy"
ON public.users
FOR SELECT
TO authenticated
USING (
  id = auth.uid()
  OR public.is_admin()
  OR (
    LOWER(role) IN ('buyer', 'seller')
    AND (
      created_by = auth.uid()
      OR EXISTS (
        SELECT 1 FROM public.crm_contacts
        WHERE crm_contacts.user_id = users.id
          AND crm_contacts.broker_id = auth.uid()
      )
    )
  )
);

DROP POLICY IF EXISTS "crm_companies_select_policy" ON public.companies;
CREATE POLICY "crm_companies_select_policy"
ON public.companies
FOR SELECT
TO authenticated
USING (
  public.is_admin()
  OR created_by = auth.uid()
  OR EXISTS (
    SELECT 1 FROM public.crm_contacts
    WHERE crm_contacts.company_id = companies.id
      AND crm_contacts.broker_id = auth.uid()
  )
);
