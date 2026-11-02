-- Migration: 0068_broker_allocate_lot.sql
-- Micro-Sprint: RM-CHAT-ALLOCATION-PRIVACY-E2E-02
--
-- Problem (verified read-only in production, 2026-11-02): a broker cannot
-- allocate an unassigned seller lot (broker_id IS NULL, visibility 'global').
-- availabilities_update_policy lets only the managing broker / admin / owning
-- seller UPDATE a lot, so the mobile allocation flow cannot reserve its stock.
-- The mobile flow is also 5 separate PostgREST writes with client-side
-- compensation, not one transaction.
--
-- Fix: one SECURITY DEFINER function that performs the whole allocation in a
-- single transaction with row locks. It does NOT change any RLS policy, and it
-- does NOT reassign the lot to the broker (the seller's broker choice stays as
-- the seller set it). Eligible lots: managed by the caller, or unassigned AND
-- globally visible. Lots managed by another broker stay blocked.
--
-- Rules enforced in the database (mirrors broker-allocation-actions.ts and the
-- mobile _allocateWithReservation):
--   * caller is an active broker; the requirement is assigned to the caller;
--   * requirement is matchable (status/target date) and has enough remaining;
--   * lot is active, valid, the same canonical commodity_id, enough stock;
--   * unit conversion MT / Qtl / Kg only, never guessed;
--   * no second active allocation of the same lot to the same requirement
--     (an identical retry returns the existing row instead).
-- NOT APPLIED. Requires owner approval.

BEGIN;

CREATE OR REPLACE FUNCTION public.rm_unit_to_mt(p_symbol TEXT)
RETURNS NUMERIC
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT CASE
    WHEN lower(btrim(p_symbol)) IN ('mt', 'ton', 'tonne', 'metric tonne') THEN 1.0
    WHEN lower(btrim(p_symbol)) IN ('qtl', 'quintal') THEN 0.1
    WHEN lower(btrim(p_symbol)) IN ('kg', 'kgs', 'kilogram') THEN 0.001
  END;
$$;
REVOKE ALL ON FUNCTION public.rm_unit_to_mt(TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.rm_unit_to_mt(TEXT) TO authenticated;

CREATE OR REPLACE FUNCTION public.broker_allocate_lot(
  p_requirement_id UUID,
  p_availability_id UUID,
  p_quantity NUMERIC,          -- in the requirement's unit
  p_price NUMERIC DEFAULT NULL,
  p_price_basis TEXT DEFAULT 'FOR_DESTINATION',
  p_notes TEXT DEFAULT NULL
)
RETURNS public.requirement_allocations
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid UUID := auth.uid();
  v_req RECORD;
  v_lot RECORD;
  v_req_unit TEXT;
  v_lot_unit TEXT;
  v_lot_qty NUMERIC;
  v_alloc public.requirement_allocations;
  v_stamp TEXT;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Authentication required' USING ERRCODE = '28000';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.users WHERE id = v_uid AND lower(role) = 'broker' AND status = true) THEN
    RAISE EXCEPTION 'Only an active broker can allocate' USING ERRCODE = '42501';
  END IF;
  IF p_quantity IS NULL OR p_quantity <= 0 THEN
    RAISE EXCEPTION 'Allocation quantity must be greater than zero' USING ERRCODE = '22023';
  END IF;

  -- Lock order: requirement, then lot (same order everywhere avoids deadlocks).
  SELECT r.*, u.symbol AS unit_symbol INTO v_req
  FROM public.requirements r LEFT JOIN public.master_units u ON u.id = r.unit_id
  WHERE r.id = p_requirement_id
  FOR UPDATE OF r;
  IF v_req.id IS NULL OR v_req.broker_id IS DISTINCT FROM v_uid THEN
    RAISE EXCEPTION 'Requirement not found or not assigned to your desk' USING ERRCODE = '42501';
  END IF;
  IF lower(btrim(v_req.status)) IN ('fully allocated', 'allocated', 'fulfilled', 'closed', 'expired', 'cancelled')
     OR (v_req.target_date IS NOT NULL AND v_req.target_date < now()) THEN
    RAISE EXCEPTION 'Requirement cannot take new allocations' USING ERRCODE = '22023';
  END IF;

  SELECT a.*, u.symbol AS unit_symbol INTO v_lot
  FROM public.availabilities a LEFT JOIN public.master_units u ON u.id = a.unit_id
  WHERE a.id = p_availability_id
  FOR UPDATE OF a;
  -- IS NOT DISTINCT FROM: a NULL broker_id must not make this check fail open.
  IF v_lot.id IS NULL
     OR NOT (v_lot.broker_id IS NOT DISTINCT FROM v_uid
             OR (v_lot.broker_id IS NULL AND v_lot.visibility IS NOT DISTINCT FROM 'global')) THEN
    -- Same error for missing, private and other-desk lots (no probing).
    RAISE EXCEPTION 'Seller lot not available to your desk' USING ERRCODE = '42501';
  END IF;
  IF v_lot.commodity_id IS DISTINCT FROM v_req.commodity_id THEN
    RAISE EXCEPTION 'Seller lot is a different product from the requirement' USING ERRCODE = '22023';
  END IF;
  IF lower(btrim(v_lot.status)) NOT IN ('open', 'active', 'partially available')
     OR (v_lot.valid_until IS NOT NULL AND v_lot.valid_until <= now()) THEN
    RAISE EXCEPTION 'Seller lot is no longer active or its validity has expired' USING ERRCODE = '22023';
  END IF;

  -- Idempotent retry / duplicate prevention.
  SELECT * INTO v_alloc FROM public.requirement_allocations
  WHERE requirement_id = p_requirement_id AND availability_id = p_availability_id
    AND status IN ('PROPOSED', 'CONFIRMED', 'COMMITTED_TO_DEAL')
  ORDER BY allocated_at DESC
  LIMIT 1;
  IF v_alloc.id IS NOT NULL THEN
    IF v_alloc.status = 'CONFIRMED' AND v_alloc.deal_id IS NULL
       AND abs(v_alloc.allocated_quantity - p_quantity) < 1e-9 THEN
      RETURN v_alloc;
    END IF;
    RAISE EXCEPTION 'This seller lot is already allocated to this requirement' USING ERRCODE = '23505';
  END IF;

  IF p_quantity > (v_req.quantity - coalesce(v_req.fulfilled_quantity, 0)) + 1e-9 THEN
    RAISE EXCEPTION 'Allocation exceeds the remaining requirement quantity' USING ERRCODE = '22023';
  END IF;

  v_req_unit := coalesce(v_req.unit_symbol, 'MT');
  v_lot_unit := coalesce(v_lot.unit_symbol, v_req_unit);
  IF lower(btrim(v_req_unit)) = lower(btrim(v_lot_unit)) THEN
    v_lot_qty := p_quantity;
  ELSIF public.rm_unit_to_mt(v_req_unit) IS NULL OR public.rm_unit_to_mt(v_lot_unit) IS NULL THEN
    RAISE EXCEPTION 'Cannot convert % to the lot unit %', v_req_unit, v_lot_unit USING ERRCODE = '22023';
  ELSE
    v_lot_qty := p_quantity * public.rm_unit_to_mt(v_req_unit) / public.rm_unit_to_mt(v_lot_unit);
  END IF;
  IF v_lot_qty > v_lot.available_quantity + 1e-9 THEN
    RAISE EXCEPTION 'Allocation exceeds the seller lot balance' USING ERRCODE = '22023';
  END IF;

  UPDATE public.availabilities SET
    available_quantity = available_quantity - v_lot_qty,
    reserved_quantity = reserved_quantity + v_lot_qty,
    version = version + 1
  WHERE id = p_availability_id;

  UPDATE public.requirements SET fulfilled_quantity = coalesce(fulfilled_quantity, 0) + p_quantity
  WHERE id = p_requirement_id;

  v_stamp := to_char(clock_timestamp(), 'YYMMDDHH24MISSUS');
  INSERT INTO public.requirement_allocations (
    allocation_reference, requirement_id, availability_id, broker_id, allocated_quantity,
    unit_id, price_basis, allocated_price, status, notes, version, confirmed_at
  ) VALUES (
    'ALC-' || right(v_stamp, 12), p_requirement_id, p_availability_id, v_uid, p_quantity,
    v_req.unit_id, coalesce(p_price_basis, 'FOR_DESTINATION'), p_price, 'CONFIRMED', p_notes, 2, now()
  )
  RETURNING * INTO v_alloc;

  RETURN v_alloc;
END;
$$;
REVOKE ALL ON FUNCTION public.broker_allocate_lot(UUID, UUID, NUMERIC, NUMERIC, TEXT, TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.broker_allocate_lot(UUID, UUID, NUMERIC, NUMERIC, TEXT, TEXT) TO authenticated;

COMMIT;
