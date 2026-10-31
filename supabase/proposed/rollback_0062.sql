-- Rollback for 0062_broker_add_counterparty_location.sql
DROP POLICY IF EXISTS "company_warehouses_broker_insert" ON public.company_warehouses;
