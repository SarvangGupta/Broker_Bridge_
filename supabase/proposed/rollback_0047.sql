-- Rollback for PROPOSED 0047. Restores the 0044 policies and NOT NULL company_id.
-- Pre-check: rollback is only safe if no individual-owned lots exist:
--   SELECT count(*) FROM public.availabilities WHERE company_id IS NULL;  -- must be 0
-- If > 0, those lots must be reassigned or removed first (needs a decision).

BEGIN;

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM public.availabilities WHERE company_id IS NULL) THEN
    RAISE EXCEPTION 'Aborting rollback_0047: individual-owned lots exist';
  END IF;
END
$$;

DROP POLICY IF EXISTS "availabilities_insert_policy" ON public.availabilities;
CREATE POLICY "availabilities_insert_policy" ON public.availabilities
FOR INSERT TO authenticated
WITH CHECK (
  (broker_id = auth.uid() AND (public.is_broker() OR public.is_admin()))
  OR public.is_admin()
  OR EXISTS (
    SELECT 1 FROM public.users u
    WHERE u.id = auth.uid() AND LOWER(u.role) = 'seller' AND u.status = true
      AND u.company_id IS NOT NULL AND u.company_id = availabilities.company_id
  )
);

DROP POLICY IF EXISTS "availabilities_select_policy" ON public.availabilities;
CREATE POLICY "availabilities_select_policy" ON public.availabilities
FOR SELECT TO authenticated
USING (
  broker_id = auth.uid()
  OR visibility = 'global'
  OR public.is_admin()
  OR EXISTS (
    SELECT 1 FROM public.users u
    WHERE u.id = auth.uid() AND LOWER(u.role) = 'seller' AND u.status = true
      AND u.company_id IS NOT NULL AND u.company_id = availabilities.company_id
  )
);

DROP POLICY IF EXISTS "availabilities_update_policy" ON public.availabilities;
CREATE POLICY "availabilities_update_policy" ON public.availabilities
FOR UPDATE TO authenticated
USING (
  broker_id = auth.uid()
  OR public.is_admin()
  OR EXISTS (
    SELECT 1 FROM public.users u
    WHERE u.id = auth.uid() AND LOWER(u.role) = 'seller' AND u.status = true
      AND u.company_id IS NOT NULL AND u.company_id = availabilities.company_id
  )
)
WITH CHECK (
  broker_id = auth.uid()
  OR public.is_admin()
  OR EXISTS (
    SELECT 1 FROM public.users u
    WHERE u.id = auth.uid() AND LOWER(u.role) = 'seller' AND u.status = true
      AND u.company_id IS NOT NULL AND u.company_id = availabilities.company_id
  )
);

DROP INDEX IF EXISTS public.availabilities_individual_lot_number_key;
ALTER TABLE public.availabilities DROP CONSTRAINT IF EXISTS availabilities_owner_check;
ALTER TABLE public.availabilities ALTER COLUMN company_id SET NOT NULL;
ALTER TABLE public.availabilities DROP COLUMN IF EXISTS seller_user_id;

COMMIT;
