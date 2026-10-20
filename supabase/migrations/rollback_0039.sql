-- ============================================================================
-- Rollback Migration: rollback_0039.sql
-- Description: Revert requirements RLS policies back to 0038 state
-- ============================================================================

DROP POLICY IF EXISTS "requirements_select_policy" ON public.requirements;
CREATE POLICY "requirements_select_policy" ON public.requirements
FOR SELECT TO authenticated
USING (
  broker_id = auth.uid()
  OR (visibility = 'global' AND status IN ('Open', 'Partially Fulfilled', 'Allocated'))
  OR public.is_admin()
);

DROP POLICY IF EXISTS "requirements_insert_policy" ON public.requirements;
CREATE POLICY "requirements_insert_policy" ON public.requirements
FOR INSERT TO authenticated
WITH CHECK (
  (broker_id = auth.uid() AND (public.is_broker() OR public.is_admin()))
  OR public.is_admin()
);

DROP POLICY IF EXISTS "requirements_update_policy" ON public.requirements;
CREATE POLICY "requirements_update_policy" ON public.requirements
FOR UPDATE TO authenticated
USING (
  broker_id = auth.uid() OR public.is_admin()
)
WITH CHECK (
  broker_id = auth.uid() OR public.is_admin()
);
