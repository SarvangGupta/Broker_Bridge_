-- Rollback for proposed 0068_broker_allocate_lot.sql. Allocations already
-- created through the function are ordinary rows and are kept.
BEGIN;
DROP FUNCTION IF EXISTS public.broker_allocate_lot(UUID, UUID, NUMERIC, NUMERIC, TEXT, TEXT);
DROP FUNCTION IF EXISTS public.rm_unit_to_mt(TEXT);
COMMIT;
