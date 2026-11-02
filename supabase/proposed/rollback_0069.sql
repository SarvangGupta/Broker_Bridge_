-- Rollback for proposed 0069: restores the production policies exactly as read
-- (read-only) on 2026-11-02.
BEGIN;

DROP POLICY IF EXISTS "availabilities_select_policy" ON public.availabilities;
CREATE POLICY "availabilities_select_policy" ON public.availabilities
FOR SELECT TO authenticated
USING (
  (broker_id = auth.uid()) OR (visibility = 'global'::text) OR is_admin()
  OR (EXISTS (SELECT 1 FROM users u
      WHERE u.id = auth.uid() AND lower(u.role) = 'seller'::text AND u.status = true
        AND u.company_id IS NOT NULL AND u.company_id = availabilities.company_id))
  OR ((company_id IS NULL) AND (seller_user_id = auth.uid()))
);

DROP POLICY IF EXISTS "requirements_select_policy" ON public.requirements;
CREATE POLICY "requirements_select_policy" ON public.requirements
FOR SELECT TO authenticated
USING (
  (broker_id = auth.uid()) OR is_admin()
  OR (company_id IN (SELECT u.company_id FROM users u WHERE u.id = auth.uid()))
  OR ((visibility = 'global'::text) AND (status = ANY (ARRAY['Open'::text, 'Partially Fulfilled'::text, 'Allocated'::text])))
);

COMMIT;
