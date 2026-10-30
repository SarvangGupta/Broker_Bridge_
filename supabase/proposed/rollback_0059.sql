-- ==============================================================================
-- Rollback for 0059_allow_broker_remove_crm_contact.sql
-- ==============================================================================

DROP POLICY IF EXISTS "crm_contacts_delete_policy" ON public.crm_contacts;

