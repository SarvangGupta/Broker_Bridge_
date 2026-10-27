-- PROPOSED — NOT APPLIED. Requires explicit approval (RB-SELLER-POST-INTEGRITY-02, OPEN-01).
-- Kept outside supabase/migrations/ so no runner applies it by accident.
--
-- Problem: availabilities has no uniqueness beyond the primary key. If the server
-- saves a listing but the response is lost, the seller's retry (same form, same
-- lot number) creates a second row.
--
-- Scope: unique per (company_id, lot_number). Lot numbers are generated client-side
-- per form (LOT-<timestamp digits>) and are NOT globally unique, so the key must
-- include the owning company. Rows with a NULL lot_number are not constrained.
--
-- Evidence (read-only, 2026-10-27, project imztlkvkxzeaekxvmcfe):
--   3 rows; 0 duplicate (company_id, lot_number) groups; 0 NULL lot_number;
--   0 lot numbers shared across companies.
--
-- App readiness: CommoditiesRepository.createCommodity already maps 23505 to
-- "Lot <n> is already listed. Check My Commodities…" (no app change needed).
--
-- Locking note: CREATE UNIQUE INDEX (non-concurrent) takes a SHARE lock on
-- availabilities for its build; with 3 rows this is milliseconds. For a large
-- table use CREATE UNIQUE INDEX CONCURRENTLY outside a transaction instead.

BEGIN;

-- Guard: abort (no change) if duplicates exist at apply time.
DO $$
DECLARE
  dup_groups INT;
BEGIN
  SELECT COUNT(*) INTO dup_groups FROM (
    SELECT company_id, lot_number
    FROM public.availabilities
    WHERE lot_number IS NOT NULL
    GROUP BY company_id, lot_number
    HAVING COUNT(*) > 1
  ) d;
  IF dup_groups > 0 THEN
    RAISE EXCEPTION
      'Aborting 0045: % duplicate (company_id, lot_number) group(s) exist; resolve them first',
      dup_groups;
  END IF;
END
$$;

CREATE UNIQUE INDEX IF NOT EXISTS availabilities_company_lot_number_key
  ON public.availabilities (company_id, lot_number)
  WHERE lot_number IS NOT NULL;

COMMIT;

-- Pre-check query (run first, read-only):
--   SELECT company_id, lot_number, COUNT(*)
--   FROM public.availabilities WHERE lot_number IS NOT NULL
--   GROUP BY 1, 2 HAVING COUNT(*) > 1;
-- Expected: 0 rows.
