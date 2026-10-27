-- PROPOSED — NOT APPLIED. Requires explicit approval (RB-SELLER-INDIVIDUAL-ACCESS-FIX-01).
-- Kept outside supabase/migrations/ so no runner applies it by accident.
--
-- Goal: let a provisioned seller WITHOUT a company own listings, without
-- inventing company ids and without weakening company isolation.
--
-- Verified live (read-only, 2026-10-27, imztlkvkxzeaekxvmcfe):
--   * availabilities.company_id is NOT NULL; there is no owner/user column.
--   * 0044 policies are applied (seller branch = own company only).
--   * 2 auth accounts claim 'seller' only in user_metadata and have NO
--     public.users row. user_metadata is self-editable, so it is NOT trusted
--     here: such accounts must first be provisioned (a users row with
--     role 'seller', status true) by an admin — a separate, approved data change.
--
-- Builds on 0044 (applied). If 0046 is approved too, merge its broker check
-- into the seller branches below (see review report). 0045's index ignores
-- rows with company_id NULL (NULLs are distinct), so a separate index is added.

BEGIN;

-- 1. Ownership column for individual sellers.
ALTER TABLE public.availabilities
  ADD COLUMN IF NOT EXISTS seller_user_id uuid REFERENCES public.users(id);

-- 2. A lot is owned by a company OR by an individual seller (exactly one model
--    per row; existing rows all have company_id, so they stay valid).
ALTER TABLE public.availabilities ALTER COLUMN company_id DROP NOT NULL;
ALTER TABLE public.availabilities
  ADD CONSTRAINT availabilities_owner_check
  CHECK (
    (company_id IS NOT NULL AND seller_user_id IS NULL)
    OR (company_id IS NULL AND seller_user_id IS NOT NULL)
  );

-- 3. Duplicate protection for individual lots (pairs with proposed 0045).
CREATE UNIQUE INDEX IF NOT EXISTS availabilities_individual_lot_number_key
  ON public.availabilities (seller_user_id, lot_number)
  WHERE company_id IS NULL AND lot_number IS NOT NULL;

-- 4. Policies = 0044 text + an individual-seller branch.
--    Branch: the row has no company, is owned by the caller, and the caller is
--    a provisioned, active seller (trusted users row, not metadata).
DROP POLICY IF EXISTS "availabilities_insert_policy" ON public.availabilities;
CREATE POLICY "availabilities_insert_policy" ON public.availabilities
FOR INSERT TO authenticated
WITH CHECK (
  (broker_id = auth.uid() AND (public.is_broker() OR public.is_admin()))
  OR public.is_admin()
  OR EXISTS (
    SELECT 1 FROM public.users u
    WHERE u.id = auth.uid() AND LOWER(u.role) = 'seller' AND u.status = true
      AND u.company_id IS NOT NULL AND u.company_id = availabilities.company_id
  )
  OR (
    availabilities.company_id IS NULL
    AND availabilities.seller_user_id = auth.uid()
    AND EXISTS (
      SELECT 1 FROM public.users u
      WHERE u.id = auth.uid() AND LOWER(u.role) = 'seller' AND u.status = true
    )
  )
);

DROP POLICY IF EXISTS "availabilities_select_policy" ON public.availabilities;
CREATE POLICY "availabilities_select_policy" ON public.availabilities
FOR SELECT TO authenticated
USING (
  broker_id = auth.uid()
  OR visibility = 'global'
  OR public.is_admin()
  OR EXISTS (
    SELECT 1 FROM public.users u
    WHERE u.id = auth.uid() AND LOWER(u.role) = 'seller' AND u.status = true
      AND u.company_id IS NOT NULL AND u.company_id = availabilities.company_id
  )
  OR (availabilities.company_id IS NULL AND availabilities.seller_user_id = auth.uid())
);

DROP POLICY IF EXISTS "availabilities_update_policy" ON public.availabilities;
CREATE POLICY "availabilities_update_policy" ON public.availabilities
FOR UPDATE TO authenticated
USING (
  broker_id = auth.uid()
  OR public.is_admin()
  OR EXISTS (
    SELECT 1 FROM public.users u
    WHERE u.id = auth.uid() AND LOWER(u.role) = 'seller' AND u.status = true
      AND u.company_id IS NOT NULL AND u.company_id = availabilities.company_id
  )
  OR (
    availabilities.company_id IS NULL
    AND availabilities.seller_user_id = auth.uid()
    AND EXISTS (
      SELECT 1 FROM public.users u
      WHERE u.id = auth.uid() AND LOWER(u.role) = 'seller' AND u.status = true
    )
  )
)
WITH CHECK (
  broker_id = auth.uid()
  OR public.is_admin()
  OR EXISTS (
    SELECT 1 FROM public.users u
    WHERE u.id = auth.uid() AND LOWER(u.role) = 'seller' AND u.status = true
      AND u.company_id IS NOT NULL AND u.company_id = availabilities.company_id
  )
  -- Individual rows must stay owned by the caller with no company
  -- (cannot be handed to another user or moved into a company).
  OR (
    availabilities.company_id IS NULL
    AND availabilities.seller_user_id = auth.uid()
    AND EXISTS (
      SELECT 1 FROM public.users u
      WHERE u.id = auth.uid() AND LOWER(u.role) = 'seller' AND u.status = true
    )
  )
);

-- 5. Seller cannot change their own role or company (0044 trigger) — unchanged.
-- No DELETE policy; no new grants; RLS stays enabled.

COMMIT;

-- Validation (rolled-back transaction, impersonating):
--   provisioned individual seller I (users row, company_id NULL):
--     1. INSERT company_id NULL, seller_user_id = I            -> ok, RETURNING ok
--     2. INSERT company_id NULL, seller_user_id = other user   -> 42501
--     3. INSERT company_id = any company                       -> 42501
--     4. SELECT own restricted lot / other individual's lot    -> 1 / 0 rows
--     5. UPDATE own price -> 1 row; SET seller_user_id = other -> 42501;
--        SET company_id = X -> 23514 (owner check) or 42501
--   company seller S: 0044 behaviour unchanged (own company only).
--   unprovisioned account (metadata-only seller, no users row): INSERT -> 42501.
--   broker (broker_id = self) and admin: unchanged.
