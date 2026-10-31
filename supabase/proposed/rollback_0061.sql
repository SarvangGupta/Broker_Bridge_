-- Rollback for 0061_trade_location_references.sql
ALTER TABLE public.availabilities
  DROP COLUMN IF EXISTS loading_location_snapshot,
  DROP COLUMN IF EXISTS loading_location_id;

ALTER TABLE public.requirements
  DROP COLUMN IF EXISTS notes,
  DROP COLUMN IF EXISTS delivery_location_snapshot,
  DROP COLUMN IF EXISTS delivery_location_id;

DROP INDEX IF EXISTS public.uq_company_warehouses_one_default;

ALTER TABLE public.company_warehouses
  DROP COLUMN IF EXISTS is_default;
