-- ============================================================================
-- Migration: 0061_trade_location_references.sql   (PROPOSED - not applied)
-- Sprint: RMBROKER-REQUIREMENT-OFFER-UI-E2E-02
-- Requires: 0055_company_warehouses.sql
--
-- Lets a requirement or offer keep a reference to the counterparty's saved
-- location, plus a text snapshot so later address edits never rewrite history.
-- Adds an optional default-location marker. Changes no RLS policy.
-- ============================================================================

ALTER TABLE public.company_warehouses
  ADD COLUMN IF NOT EXISTS is_default boolean NOT NULL DEFAULT false;

CREATE UNIQUE INDEX IF NOT EXISTS uq_company_warehouses_one_default
  ON public.company_warehouses (company_id)
  WHERE is_default AND is_active;

ALTER TABLE public.requirements
  ADD COLUMN IF NOT EXISTS delivery_location_id uuid REFERENCES public.company_warehouses(id),
  ADD COLUMN IF NOT EXISTS delivery_location_snapshot text,
  ADD COLUMN IF NOT EXISTS notes text;

ALTER TABLE public.availabilities
  ADD COLUMN IF NOT EXISTS loading_location_id uuid REFERENCES public.company_warehouses(id),
  ADD COLUMN IF NOT EXISTS loading_location_snapshot text;
