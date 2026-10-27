-- PROPOSED — NOT APPLIED. Requires explicit approval (RB-SELLER-INDIVIDUAL-LISTINGS-02, Phase 1).
-- Safe, repeatable, idempotent identity-provisioning solution for individual sellers.
--
-- Background:
--   Unprovisioned accounts have an auth.users record, but no public.users record.
--   Their self-claimed user_metadata->>'role' is editable and untrusted by RLS.
--   This procedure authoritatively provisions trusted identity in public.users
--   with role = 'seller', status = true, company_id = NULL, triggering
--   trg_sync_privileged_role to write trusted app_metadata->>'role' = 'seller'.

BEGIN;

CREATE OR REPLACE FUNCTION public.provision_individual_seller(target_auth_user_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, pg_temp
AS $$
DECLARE
  v_auth_record RECORD;
  v_name TEXT;
  v_email TEXT;
  v_result jsonb;
BEGIN
  -- 1. Authorization check: Only superuser or platform admin can execute
  IF NOT (public.is_admin() OR CURRENT_USER = 'postgres') THEN
    RAISE EXCEPTION 'Only platform administrators can provision seller identities'
      USING ERRCODE = '42501';
  END IF;

  -- 2. Verify account exists in auth.users
  SELECT id, email, raw_user_meta_data, raw_app_meta_data
  INTO v_auth_record
  FROM auth.users
  WHERE id = target_auth_user_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Auth user with ID % does not exist', target_auth_user_id
      USING ERRCODE = 'P0002';
  END IF;

  -- 3. Resolve display name and email safely (sanitized, no company credentials trusted)
  v_name := COALESCE(
    NULLIF(TRIM(v_auth_record.raw_user_meta_data->>'full_name'), ''),
    NULLIF(TRIM(v_auth_record.raw_user_meta_data->>'name'), ''),
    'Individual Seller'
  );
  v_email := v_auth_record.email;

  -- 4. Idempotently insert or update trusted public.users record
  --    Never assign a company ID automatically; company_id remains NULL for individual sellers.
  INSERT INTO public.users (id, name, email, role, status, company_id, created_at)
  VALUES (target_auth_user_id, v_name, v_email, 'seller', true, NULL, NOW())
  ON CONFLICT (id) DO UPDATE
  SET
    role = 'seller',
    status = true,
    name = CASE WHEN public.users.name IS NULL OR public.users.name = '' THEN EXCLUDED.name ELSE public.users.name END,
    email = EXCLUDED.email;

  -- 5. Return success payload
  v_result := jsonb_build_object(
    'status', 'PROVISIONED',
    'user_id', target_auth_user_id,
    'role', 'seller',
    'has_company', false,
    'name', v_name
  );

  RETURN v_result;
END;
$$;

REVOKE ALL ON FUNCTION public.provision_individual_seller(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.provision_individual_seller(uuid) TO authenticated;

-- Example administrative usage (requires explicit approval before executing):
-- SELECT public.provision_individual_seller('4e21f195-2f3b-465d-94cc-e47eebd92800');
-- SELECT public.provision_individual_seller('49534f2f-ec4e-445f-84e8-7d09c7056b6a');

COMMIT;
