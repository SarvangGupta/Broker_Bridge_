-- Rollback for PROPOSED 0053: removes the trust-field guard. Restores the exact
-- pre-0053 grants (DELETE/TRUNCATE to authenticated, as verified live 2026-10-29).
DROP TRIGGER IF EXISTS trg_protect_company_trust_fields ON public.companies;
DROP FUNCTION IF EXISTS public.protect_company_trust_fields();
GRANT DELETE, TRUNCATE ON public.companies TO authenticated;
