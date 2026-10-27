-- PROPOSED — NOT APPLIED. Requires explicit approval (RB-SELLER-POST-INTEGRITY-02, OPEN-02).
-- Kept outside supabase/migrations/ so no runner applies it by accident.
--
-- Problem: the seller branches of availabilities INSERT / UPDATE (0044) check only
-- company ownership. broker_id is an FK to users(id), so a seller can set it to ANY
-- user id (a buyer, another seller, a deactivated broker). That user then gains
-- the existing "broker_id = auth.uid()" SELECT/UPDATE rights on the lot.
--
-- Existing schema evidence (read-only, 2026-10-27):
--   * No seller↔broker relationship table exists. The Seller App's "My Trusted
--     Brokers" list = all users with role 'broker' (SellerBrokerRepository).
--   * crm_contacts(broker_id, user_id, company_id) is the broker-side CRM link.
--   * users_select_policy lets any authenticated user read active broker rows.
--
-- Minimal fix (matches what the app offers): a seller may only set broker_id to
-- NULL or to an ACTIVE user whose role is 'broker'. Broker and admin branches are
-- unchanged. It does NOT require a CRM link, because the app does not require one
-- today; a stricter "trusted relationship" needs a product decision and a table.
--
-- Depends on 0044 (applied to production 2026-10-27). Rollback restores 0044 text.

BEGIN;

DROP POLICY IF EXISTS "availabilities_insert_policy" ON public.availabilities;
CREATE POLICY "availabilities_insert_policy" ON public.availabilities
FOR INSERT TO authenticated
WITH CHECK (
  (broker_id = auth.uid() AND (public.is_broker() OR public.is_admin()))
  OR public.is_admin()
  OR (
    EXISTS (
      SELECT 1 FROM public.users u
      WHERE u.id = auth.uid()
        AND LOWER(u.role) = 'seller'
        AND u.status = true
        AND u.company_id IS NOT NULL
        AND u.company_id = availabilities.company_id
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

DROP POLICY IF EXISTS "availabilities_update_policy" ON public.availabilities;
CREATE POLICY "availabilities_update_policy" ON public.availabilities
FOR UPDATE TO authenticated
USING (
  broker_id = auth.uid()
  OR public.is_admin()
  OR EXISTS (
    SELECT 1 FROM public.users u
    WHERE u.id = auth.uid()
      AND LOWER(u.role) = 'seller'
      AND u.status = true
      AND u.company_id IS NOT NULL
      AND u.company_id = availabilities.company_id
  )
)
WITH CHECK (
  broker_id = auth.uid()
  OR public.is_admin()
  OR (
    EXISTS (
      SELECT 1 FROM public.users u
      WHERE u.id = auth.uid()
        AND LOWER(u.role) = 'seller'
        AND u.status = true
        AND u.company_id IS NOT NULL
        AND u.company_id = availabilities.company_id
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

-- Validation (in a rolled-back transaction, impersonating a seller of company C):
--   1. INSERT lot company C, broker_id = active broker            -> succeeds
--   2. INSERT lot company C, broker_id = a buyer's user id         -> 42501
--   3. UPDATE own lot SET broker_id = another seller's user id     -> 42501
--   4. UPDATE own lot SET broker_id = NULL                         -> succeeds
--   5. Broker inserts with broker_id = self                        -> succeeds (unchanged)
--   6. Seller updates own lot price (broker unchanged, valid)      -> succeeds
-- Note: existing lots whose broker_id is not an active broker could no longer be
-- updated by the seller until reassigned; pre-check:
--   SELECT count(*) FROM availabilities a LEFT JOIN users b ON b.id = a.broker_id
--   WHERE a.broker_id IS NOT NULL AND (b.id IS NULL OR lower(b.role) <> 'broker' OR b.status IS NOT TRUE);
