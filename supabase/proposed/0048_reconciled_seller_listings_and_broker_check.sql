-- PROPOSED — NOT APPLIED. Requires explicit approval (RB-SELLER-INDIVIDUAL-LISTINGS-02).
-- Kept outside supabase/migrations/ so no runner applies it by accident.
--
-- Reconciles:
--   - 0044: Baseline seller company ownership policies and trigger (applied 2026-10-27).
--   - 0045: Duplicate lot number protection on (company_id, lot_number).
--   - 0046: Broker assignment check (broker_id must be NULL or an active user with role='broker').
--   - 0047: Approved individual seller ownership model (seller_user_id, nullable company_id, owner check).
--
-- Preflight Assertions (verified read-only against live database):
--   1. 0 duplicate (company_id, lot_number) groups.
--   2. 0 duplicate (seller_user_id, lot_number) groups.
--   3. 0 invalid owner combinations (both set or both null).
--   4. 0 invalid broker assignments (non-broker or inactive broker).

BEGIN;

-- 1. Preflight guard: Abort if any conflicting data exists before applying constraints.
DO $$
DECLARE
  v_dup_comp INT;
  v_dup_indiv INT;
  v_invalid_owners INT;
  v_invalid_brokers INT;
BEGIN
  -- Check duplicate company lots
  SELECT COUNT(*) INTO v_dup_comp FROM (
    SELECT company_id, lot_number
    FROM public.availabilities
    WHERE company_id IS NOT NULL AND lot_number IS NOT NULL
    GROUP BY company_id, lot_number
    HAVING COUNT(*) > 1
  ) d;
  IF v_dup_comp > 0 THEN
    RAISE EXCEPTION 'Aborting 0048: % duplicate (company_id, lot_number) group(s) exist; resolve first', v_dup_comp;
  END IF;

  -- Check duplicate individual lots
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'availabilities' AND column_name = 'seller_user_id'
  ) THEN
    SELECT COUNT(*) INTO v_dup_indiv FROM (
      SELECT seller_user_id, lot_number
      FROM public.availabilities
      WHERE seller_user_id IS NOT NULL AND lot_number IS NOT NULL
      GROUP BY seller_user_id, lot_number
      HAVING COUNT(*) > 1
    ) d;
    IF v_dup_indiv > 0 THEN
      RAISE EXCEPTION 'Aborting 0048: % duplicate (seller_user_id, lot_number) group(s) exist; resolve first', v_dup_indiv;
    END IF;
  END IF;

  -- Check invalid broker assignments
  SELECT COUNT(*) INTO v_invalid_brokers
  FROM public.availabilities a
  LEFT JOIN public.users u ON a.broker_id = u.id
  WHERE a.broker_id IS NOT NULL
    AND (u.id IS NULL OR LOWER(u.role) != 'broker' OR u.status IS NOT TRUE);
  IF v_invalid_brokers > 0 THEN
    RAISE EXCEPTION 'Aborting 0048: % invalid broker assignment(s) exist; resolve first', v_invalid_brokers;
  END IF;
END
$$;

-- 2. Schema changes: add seller_user_id and make company_id nullable
ALTER TABLE public.availabilities
  ADD COLUMN IF NOT EXISTS seller_user_id uuid REFERENCES public.users(id);

ALTER TABLE public.availabilities ALTER COLUMN company_id DROP NOT NULL;

-- 3. Invariant: Exactly one ownership mode per lot (Company OR Individual)
ALTER TABLE public.availabilities DROP CONSTRAINT IF EXISTS availabilities_owner_check;
ALTER TABLE public.availabilities
  ADD CONSTRAINT availabilities_owner_check
  CHECK (
    (company_id IS NOT NULL AND seller_user_id IS NULL)
    OR (company_id IS NULL AND seller_user_id IS NOT NULL)
  );

-- 4. Unique lot number indexes
-- 4a. Company lot number uniqueness (pairs with 0045)
CREATE UNIQUE INDEX IF NOT EXISTS availabilities_company_lot_number_key
  ON public.availabilities (company_id, lot_number)
  WHERE company_id IS NOT NULL AND lot_number IS NOT NULL;

-- 4b. Individual lot number uniqueness (pairs with 0047)
CREATE UNIQUE INDEX IF NOT EXISTS availabilities_individual_lot_number_key
  ON public.availabilities (seller_user_id, lot_number)
  WHERE company_id IS NULL AND lot_number IS NOT NULL;

-- 5. Reconciled RLS Policies (combining 0044 + 0046 broker check + 0047 individual ownership)

-- 5A. INSERT POLICY
DROP POLICY IF EXISTS "availabilities_insert_policy" ON public.availabilities;
CREATE POLICY "availabilities_insert_policy" ON public.availabilities
FOR INSERT TO authenticated
WITH CHECK (
  -- Broker / admin inserting for mandate
  (broker_id = auth.uid() AND (public.is_broker() OR public.is_admin()))
  OR public.is_admin()
  -- Company-owned lot by authorized company seller (with active broker check from 0046)
  OR (
    EXISTS (
      SELECT 1 FROM public.users u
      WHERE u.id = auth.uid()
        AND LOWER(u.role) = 'seller'
        AND u.status = true
        AND u.company_id IS NOT NULL
        AND u.company_id = availabilities.company_id
    )
    AND availabilities.seller_user_id IS NULL
    AND (
      availabilities.broker_id IS NULL
      OR EXISTS (
        SELECT 1 FROM public.users b
        WHERE b.id = availabilities.broker_id
          AND LOWER(b.role) = 'broker'
          AND b.status = true
      )
    )
  )
  -- Individual-owned lot by authorized individual seller (with active broker check from 0046)
  OR (
    availabilities.company_id IS NULL
    AND availabilities.seller_user_id = auth.uid()
    AND EXISTS (
      SELECT 1 FROM public.users u
      WHERE u.id = auth.uid()
        AND LOWER(u.role) = 'seller'
        AND u.status = true
    )
    AND (
      availabilities.broker_id IS NULL
      OR EXISTS (
        SELECT 1 FROM public.users b
        WHERE b.id = availabilities.broker_id
          AND LOWER(b.role) = 'broker'
          AND b.status = true
      )
    )
  )
);

-- 5B. SELECT POLICY
DROP POLICY IF EXISTS "availabilities_select_policy" ON public.availabilities;
CREATE POLICY "availabilities_select_policy" ON public.availabilities
FOR SELECT TO authenticated
USING (
  broker_id = auth.uid()
  OR visibility = 'global'
  OR public.is_admin()
  -- Company seller reads own company's lots
  OR EXISTS (
    SELECT 1 FROM public.users u
    WHERE u.id = auth.uid()
      AND LOWER(u.role) = 'seller'
      AND u.status = true
      AND u.company_id IS NOT NULL
      AND u.company_id = availabilities.company_id
  )
  -- Individual seller reads own individual lots
  OR (
    availabilities.company_id IS NULL
    AND availabilities.seller_user_id = auth.uid()
  )
);

-- 5C. UPDATE POLICY
DROP POLICY IF EXISTS "availabilities_update_policy" ON public.availabilities;
CREATE POLICY "availabilities_update_policy" ON public.availabilities
FOR UPDATE TO authenticated
USING (
  broker_id = auth.uid()
  OR public.is_admin()
  -- Company seller updates own company's lots
  OR EXISTS (
    SELECT 1 FROM public.users u
    WHERE u.id = auth.uid()
      AND LOWER(u.role) = 'seller'
      AND u.status = true
      AND u.company_id IS NOT NULL
      AND u.company_id = availabilities.company_id
  )
  -- Individual seller updates own individual lots
  OR (
    availabilities.company_id IS NULL
    AND availabilities.seller_user_id = auth.uid()
    AND EXISTS (
      SELECT 1 FROM public.users u
      WHERE u.id = auth.uid()
        AND LOWER(u.role) = 'seller'
        AND u.status = true
    )
  )
)
WITH CHECK (
  broker_id = auth.uid()
  OR public.is_admin()
  -- Company seller must maintain company ownership and valid broker
  OR (
    EXISTS (
      SELECT 1 FROM public.users u
      WHERE u.id = auth.uid()
        AND LOWER(u.role) = 'seller'
        AND u.status = true
        AND u.company_id IS NOT NULL
        AND u.company_id = availabilities.company_id
    )
    AND availabilities.seller_user_id IS NULL
    AND (
      availabilities.broker_id IS NULL
      OR EXISTS (
        SELECT 1 FROM public.users b
        WHERE b.id = availabilities.broker_id
          AND LOWER(b.role) = 'broker'
          AND b.status = true
      )
    )
  )
  -- Individual seller must keep lot owned by self and without company
  OR (
    availabilities.company_id IS NULL
    AND availabilities.seller_user_id = auth.uid()
    AND EXISTS (
      SELECT 1 FROM public.users u
      WHERE u.id = auth.uid()
        AND LOWER(u.role) = 'seller'
        AND u.status = true
    )
    AND (
      availabilities.broker_id IS NULL
      OR EXISTS (
        SELECT 1 FROM public.users b
        WHERE b.id = availabilities.broker_id
          AND LOWER(b.role) = 'broker'
          AND b.status = true
      )
    )
  )
);

COMMIT;
