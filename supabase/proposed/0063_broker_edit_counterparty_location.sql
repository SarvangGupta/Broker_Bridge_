-- ============================================================================
-- Migration: 0063_broker_edit_counterparty_location.sql   (PROPOSED - not applied)
-- Sprint: RMBROKER-LOCATION-PERSISTENCE-E2E-03
-- Requires: 0055_company_warehouses.sql, 0060_crm_contacts_soft_removal.sql
--
-- A broker may edit a saved location only for a company in their active CRM
-- contacts, and may not move it to a company outside them. Delete is not granted.
-- ============================================================================

DROP POLICY IF EXISTS "company_warehouses_broker_update" ON public.company_warehouses;
CREATE POLICY "company_warehouses_broker_update" ON public.company_warehouses
FOR UPDATE TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.crm_contacts cc
    WHERE cc.broker_id = auth.uid()
      AND cc.company_id = company_warehouses.company_id
      AND cc.removed_at IS NULL
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1 FROM public.crm_contacts cc
    WHERE cc.broker_id = auth.uid()
      AND cc.company_id = company_warehouses.company_id
      AND cc.removed_at IS NULL
  )
);
