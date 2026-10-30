-- Migration: 0060_crm_contacts_soft_removal.sql
-- Sprint: RMBROKER-VARUN-DIRECTORY-REMOVE-PERSISTENCE-01
--
-- Objective:
--   Add persistent soft-removal timestamp column to public.crm_contacts
--   so broker counterparty relationship removals persist across refresh/restarts
--   and prevent linkAssignedCounterparties from resurrecting explicitly removed contacts.

ALTER TABLE public.crm_contacts 
  ADD COLUMN IF NOT EXISTS removed_at TIMESTAMPTZ DEFAULT NULL;

CREATE INDEX IF NOT EXISTS idx_crm_contacts_broker_active 
  ON public.crm_contacts(broker_id, created_at DESC) 
  WHERE removed_at IS NULL;

