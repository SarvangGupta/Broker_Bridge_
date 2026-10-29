-- ============================================================================
-- Migration: 0053_protect_company_trust_fields.sql   (PROPOSED — not applied)
-- Sprint: RMBUYER-GST-BACKEND-01
--
-- Problem (live, verified read-only 2026-10-29): `authenticated` holds table-wide
-- UPDATE on public.companies and the policy "Users can update their own company"
-- has no column limit, so any company member can set is_verified, trust_score,
-- status and the bank-verification flags on their own company through PostgREST.
-- crm_companies_insert_policy also lets brokers INSERT a pre-verified company.
--
-- Fix: an INVOKER-rights trigger that only constrains API sessions
-- (current_user = authenticated/anon). Admins (trusted app_metadata role via
-- public.is_admin()) and server-side paths (postgres / SECURITY DEFINER RPCs)
-- are unaffected. A column-grant split was rejected: RMBroker's directory edit
-- writes `status` and its directory insert sends is_verified/trust_score.
--
-- SECURITY INVOKER is essential: under SECURITY DEFINER, current_user would be
-- the owner and the guard would never fire (test G-1 proves it fires).
-- ============================================================================

CREATE OR REPLACE FUNCTION public.protect_company_trust_fields()
RETURNS trigger
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = ''
AS $$
BEGIN
  -- coalesce: is_admin() is NULL (not false) for a user with no role.
  IF current_user NOT IN ('authenticated', 'anon') OR coalesce(public.is_admin(), false) THEN
    RETURN NEW;
  END IF;

  IF TG_OP = 'INSERT' THEN
    -- Broker-created counterparties always start unverified, whatever the client sent.
    NEW.is_verified := false;
    NEW.trust_score := 100;
    NEW.bank_is_verified := false;
    NEW.bank_verification_status := 'unverified';
    RETURN NEW;
  END IF;

  IF NEW.id IS DISTINCT FROM OLD.id
     OR NEW.is_verified IS DISTINCT FROM OLD.is_verified
     OR NEW.trust_score IS DISTINCT FROM OLD.trust_score
     OR NEW.bank_is_verified IS DISTINCT FROM OLD.bank_is_verified
     OR NEW.bank_verification_status IS DISTINCT FROM OLD.bank_verification_status
     OR NEW.created_by IS DISTINCT FROM OLD.created_by THEN
    RAISE EXCEPTION 'protected company field' USING ERRCODE = '42501';
  END IF;

  -- status: only the established RMBroker directory workflow (a broker editing a
  -- counterparty it created or holds as a CRM contact). Never the company's own members.
  -- Every operand is NULL-safe: a NULL here would make the IF false and fail open
  -- (caught by offline test G-4 on a company with created_by IS NULL).
  IF NEW.status IS DISTINCT FROM OLD.status AND NOT coalesce(
       public.is_broker()
       AND (OLD.created_by IS NOT DISTINCT FROM auth.uid() AND OLD.created_by IS NOT NULL
            OR EXISTS (SELECT 1 FROM public.crm_contacts cc
                       WHERE cc.company_id = OLD.id AND cc.broker_id = auth.uid())),
       false) THEN
    RAISE EXCEPTION 'protected company field' USING ERRCODE = '42501';
  END IF;

  RETURN NEW;
END;
$$;

REVOKE ALL ON FUNCTION public.protect_company_trust_fields() FROM PUBLIC, anon;

DROP TRIGGER IF EXISTS trg_protect_company_trust_fields ON public.companies;
CREATE TRIGGER trg_protect_company_trust_fields
BEFORE INSERT OR UPDATE ON public.companies
FOR EACH ROW EXECUTE FUNCTION public.protect_company_trust_fields();

-- Hardening: no policy permits DELETE; TRUNCATE ignores RLS. Neither is used by any client.
REVOKE DELETE, TRUNCATE ON public.companies FROM authenticated;
