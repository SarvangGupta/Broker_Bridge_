-- ============================================================================
-- Migration: 0039_allow_buyers_requirements_rls.sql
-- Description: Expand RLS policies on public.requirements to permit authenticated
--              buyers to insert, view, and cancel requirements for their own verified company.
-- ============================================================================

-- 1. SELECT Policy: Buyers can view their own company's requirements + global active requirements
DROP POLICY IF EXISTS "requirements_select_policy" ON public.requirements;
CREATE POLICY "requirements_select_policy" ON public.requirements
FOR SELECT TO authenticated
USING (
  broker_id = auth.uid()
  OR public.is_admin()
  OR company_id IN (
    SELECT u.company_id FROM public.users u
    WHERE u.id = auth.uid()
  )
  OR (visibility = 'global' AND status IN ('Open', 'Partially Fulfilled', 'Allocated'))
);

-- 2. INSERT Policy: Buyers can insert requirements for their own verified company
DROP POLICY IF EXISTS "requirements_insert_policy" ON public.requirements;
CREATE POLICY "requirements_insert_policy" ON public.requirements
FOR INSERT TO authenticated
WITH CHECK (
  (broker_id = auth.uid() AND (public.is_broker() OR public.is_admin()))
  OR public.is_admin()
  OR (
    company_id IN (
      SELECT u.company_id FROM public.users u
      WHERE u.id = auth.uid() AND (u.role = 'buyer' OR u.role = 'admin')
    )
  )
);

-- 3. UPDATE Policy: Buyers can update (e.g. cancel) requirements for their own verified company
DROP POLICY IF EXISTS "requirements_update_policy" ON public.requirements;
CREATE POLICY "requirements_update_policy" ON public.requirements
FOR UPDATE TO authenticated
USING (
  broker_id = auth.uid()
  OR public.is_admin()
  OR company_id IN (
    SELECT u.company_id FROM public.users u
    WHERE u.id = auth.uid()
  )
)
WITH CHECK (
  broker_id = auth.uid()
  OR public.is_admin()
  OR company_id IN (
    SELECT u.company_id FROM public.users u
    WHERE u.id = auth.uid()
  )
);
