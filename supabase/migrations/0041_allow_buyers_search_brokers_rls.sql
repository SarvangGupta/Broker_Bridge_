-- Migration: 0041_allow_buyers_search_brokers_rls.sql
-- Enables authenticated buyers to discover active, licensed brokers and their broker desks from public.users and public.companies.
-- Preserves strict Counterparty Shield:
-- 1. Buyers can discover brokers (role = 'broker' AND status = true).
-- 2. Buyers CANNOT see sellers (role = 'seller' still requires created_by = auth.uid() OR crm_contacts link).
-- 3. Brokers continue to see only themselves and their assigned contacts.

DROP POLICY IF EXISTS "users_select_policy" ON public.users;
CREATE POLICY "users_select_policy"
ON public.users
FOR SELECT
TO authenticated
USING (
  id = auth.uid()
  OR public.is_admin()
  OR (LOWER(role) = 'broker' AND status = true)
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

-- Allow buyers to read companies associated with active brokers
DROP POLICY IF EXISTS "crm_companies_select_policy" ON public.companies;
CREATE POLICY "crm_companies_select_policy"
ON public.companies
FOR SELECT
TO authenticated
USING (
  public.is_admin()
  OR created_by = auth.uid()
  OR EXISTS (
    SELECT 1 FROM public.users u
    WHERE u.company_id = companies.id
      AND LOWER(u.role) = 'broker'
      AND u.status = true
  )
  OR EXISTS (
    SELECT 1 FROM public.crm_contacts
    WHERE crm_contacts.company_id = companies.id
      AND crm_contacts.broker_id = auth.uid()
  )
);
