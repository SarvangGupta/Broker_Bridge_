-- ============================================================================
-- Rollback for PROPOSED 0056_warehouse_gps_coordinates.sql
-- ============================================================================

-- Revert columns if needed
ALTER TABLE IF EXISTS public.company_warehouses
  DROP CONSTRAINT IF EXISTS chk_warehouse_coordinates_pair,
  DROP COLUMN IF EXISTS location_captured_at,
  DROP COLUMN IF EXISTS gps_accuracy,
  DROP COLUMN IF EXISTS longitude,
  DROP COLUMN IF EXISTS latitude;

