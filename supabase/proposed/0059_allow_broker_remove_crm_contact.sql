-- ==============================================================================
-- Migration: 0059_allow_broker_remove_crm_contact.sql (PROPOSED)
-- Sprint: RMBROKER-DIRECTORY-REMOVE-FIX-01
--
-- Objective:
--   Allow authenticated brokers to remove / delete their own counterparty
--   relationship records from public.crm_contacts without deleting shared master
--   company records, GST data, or deal history.
-- ==============================================================================

GRANT DELETE ON TABLE public.crm_contacts TO authenticated;

DROP POLICY IF EXISTS "crm_contacts_delete_policy" ON public.crm_contacts;
CREATE POLICY "crm_contacts_delete_policy"
ON public.crm_contacts
FOR DELETE
TO authenticated
USING (
  broker_id = auth.uid() OR public.is_admin()
);

