-- Rollback for PROPOSED 0044: restores the exact 0038 policies (as verified live on
-- 2026-10-27) and removes the company_id guard.

BEGIN;

DROP TRIGGER IF EXISTS trg_prevent_self_company_change ON public.users;
DROP FUNCTION IF EXISTS public.prevent_self_company_change();

DROP POLICY IF EXISTS "availabilities_insert_policy" ON public.availabilities;
CREATE POLICY "availabilities_insert_policy" ON public.availabilities
FOR INSERT TO authenticated
WITH CHECK (
  (broker_id = auth.uid() AND (public.is_broker() OR public.is_admin()))
  OR public.is_admin()
);

DROP POLICY IF EXISTS "availabilities_select_policy" ON public.availabilities;
CREATE POLICY "availabilities_select_policy" ON public.availabilities
FOR SELECT TO authenticated
USING (
  broker_id = auth.uid()
  OR visibility = 'global'
  OR public.is_admin()
);

DROP POLICY IF EXISTS "availabilities_update_policy" ON public.availabilities;
CREATE POLICY "availabilities_update_policy" ON public.availabilities
FOR UPDATE TO authenticated
USING (broker_id = auth.uid() OR public.is_admin())
WITH CHECK (broker_id = auth.uid() OR public.is_admin());

COMMIT;
