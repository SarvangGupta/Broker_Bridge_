-- Migration: 0069_marketplace_visibility_privacy.sql
-- Micro-Sprint: RM-CHAT-ALLOCATION-PRIVACY-E2E-02
--
-- Problem (verified read-only in production, 2026-11-02, using a SYNTHETIC
-- authenticated user id that has no users row; counts only):
--   * availabilities_select_policy has a bare (visibility = 'global') branch:
--     ANY authenticated session reads 10 of 17 seller lots, including
--     confidential_minimum_price (4 lots) and the seller company_id (4 lots).
--     Buyers can therefore discover sellers and their floor prices.
--   * requirements_select_policy has a bare global-open branch: any
--     authenticated session reads 28 of 35 buyer requirements, including the
--     buyer company_id. Sellers can therefore discover buyers.
--
-- Fix: keep both policies exactly as they are in production and only require
-- that the global branch is used by brokers (or admins). Buyers keep their own
-- company's requirements; sellers keep their own lots; brokers keep the global
-- marketplace they need for matching. RMBuyer and RMSeller only query their own
-- rows (checked in app code), so no app flow depends on the removed access.
--
-- Not changed here: column-level exposure of confidential_minimum_price to
-- brokers (brokers are the intended audience of the floor price).
-- NOT APPLIED. Requires owner approval.

BEGIN;

DROP POLICY IF EXISTS "availabilities_select_policy" ON public.availabilities;
CREATE POLICY "availabilities_select_policy" ON public.availabilities
FOR SELECT TO authenticated
USING (
  (broker_id = auth.uid())
  OR ((visibility = 'global'::text) AND (public.is_broker() OR public.is_admin()))
  OR public.is_admin()
  OR (EXISTS (
    SELECT 1 FROM public.users u
    WHERE u.id = auth.uid() AND lower(u.role) = 'seller'::text AND u.status = true
      AND u.company_id IS NOT NULL AND u.company_id = availabilities.company_id))
  OR ((company_id IS NULL) AND (seller_user_id = auth.uid()))
);

DROP POLICY IF EXISTS "requirements_select_policy" ON public.requirements;
CREATE POLICY "requirements_select_policy" ON public.requirements
FOR SELECT TO authenticated
USING (
  (broker_id = auth.uid())
  OR public.is_admin()
  OR (company_id IN (SELECT u.company_id FROM public.users u WHERE u.id = auth.uid()))
  OR ((visibility = 'global'::text)
      AND (status = ANY (ARRAY['Open'::text, 'Partially Fulfilled'::text, 'Allocated'::text]))
      AND (public.is_broker() OR public.is_admin()))
);

COMMIT;
