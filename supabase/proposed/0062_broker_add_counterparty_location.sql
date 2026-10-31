-- ============================================================================
-- Migration: 0062_broker_add_counterparty_location.sql
-- Sprint: RMBROKER-REQUIREMENT-OFFER-UI-E2E-02
-- Requires: 0055_company_warehouses.sql, 0060_crm_contacts_soft_removal.sql
--
-- A broker may add a saved location only for a company in their active CRM
-- contacts. Grants insert only: update and delete stay with the company and admins.
-- ============================================================================

DROP POLICY IF EXISTS "company_warehouses_broker_insert" ON public.company_warehouses;
CREATE POLICY "company_warehouses_broker_insert" ON public.company_warehouses
FOR INSERT TO authenticated
WITH CHECK (
  created_by = auth.uid()
  AND EXISTS (
    SELECT 1 FROM public.crm_contacts cc
    WHERE cc.broker_id = auth.uid()
      AND cc.company_id = company_warehouses.company_id
      AND cc.removed_at IS NULL
  )
);
