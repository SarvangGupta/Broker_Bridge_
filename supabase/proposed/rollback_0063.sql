-- Rollback for 0063_broker_edit_counterparty_location.sql
DROP POLICY IF EXISTS "company_warehouses_broker_update" ON public.company_warehouses;
