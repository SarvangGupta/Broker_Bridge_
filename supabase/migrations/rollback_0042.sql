-- Rollback Migration: rollback_0042.sql
-- Restores the pre-0042 state: authenticated has no SELECT on master_categories and no read policy exists.

DROP POLICY IF EXISTS "master_categories_read" ON public.master_categories;
REVOKE SELECT ON TABLE public.master_categories FROM authenticated;
