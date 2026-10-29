-- Rollback for PROPOSED 0055_company_warehouses.sql

DROP TRIGGER IF EXISTS trg_notify_warehouse_change ON public.company_warehouses;
DROP FUNCTION IF EXISTS public.trg_notify_warehouse_change();

DROP POLICY IF EXISTS "company_warehouses_delete" ON public.company_warehouses;
DROP POLICY IF EXISTS "company_warehouses_update" ON public.company_warehouses;
DROP POLICY IF EXISTS "company_warehouses_insert" ON public.company_warehouses;
DROP POLICY IF EXISTS "company_warehouses_select" ON public.company_warehouses;

DROP TABLE IF EXISTS public.company_warehouses;

