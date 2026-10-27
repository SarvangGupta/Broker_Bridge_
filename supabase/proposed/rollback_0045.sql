-- Rollback for PROPOSED 0045: removes only the uniqueness index. No data changes.
BEGIN;
DROP INDEX IF EXISTS public.availabilities_company_lot_number_key;
COMMIT;
