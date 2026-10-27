-- PROPOSED DATABASE MIGRATION: 0049_allow_seller_self_provisioning.sql
-- Sprint: RMS-SELLER-PROVISIONING-FIX-01
--
-- Objective:
--   Allow legitimately registered and authenticated sellers to self-provision their trusted
--   public.users identity row safely and idempotently, resolving the "Your account is not yet
--   provisioned in the database" error during commodity posting.
--
-- Security Invariants:
--   1. An authenticated user can ONLY provision their own canonical auth.uid() ID.
--   2. Only accounts whose auth metadata specifies role = 'seller' (or admin) can be provisioned.
--   3. Prevents privilege escalation: hardcodes role to 'seller', never grants broker or admin.
--   4. Idempotent: repeated calls do not create duplicate profiles and preserve any existing company_id.
--   5. Triggers trg_sync_privileged_role to synchronize trusted app_metadata.

BEGIN;

CREATE OR REPLACE FUNCTION public.provision_individual_seller(target_auth_user_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, pg_temp
AS $$
DECLARE
  v_auth_record RECORD;
  v_role TEXT;
  v_name TEXT;
  v_email TEXT;
  v_result jsonb;
BEGIN
  -- 1. Authorization: Only platform admins, superusers, OR the authenticated user provisioning their own account
  IF NOT (public.is_admin() OR CURRENT_USER = 'postgres' OR auth.uid() = target_auth_user_id) THEN
    RAISE EXCEPTION 'Unauthorized: Users can only provision their own seller identity'
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

  -- 3. Verify role is authorized for seller portal
  v_role := LOWER(COALESCE(
    v_auth_record.raw_app_meta_data->>'role',
    v_auth_record.raw_user_meta_data->>'role',
    ''
  ));

  IF v_role NOT IN ('seller', 'admin', 'seller_admin') THEN
    RAISE EXCEPTION 'Only sellers can be provisioned as seller identities'
      USING ERRCODE = '42501';
  END IF;

  -- 4. Resolve display name and email safely (sanitized, no company credentials trusted)
  v_name := COALESCE(
    NULLIF(TRIM(v_auth_record.raw_user_meta_data->>'full_name'), ''),
    NULLIF(TRIM(v_auth_record.raw_user_meta_data->>'name'), ''),
    'Individual Seller'
  );
  v_email := v_auth_record.email;

  -- 5. Idempotently insert or update trusted public.users record
  --    Preserves existing company_id if the seller is already linked to an enterprise firm.
  INSERT INTO public.users (id, name, email, role, status, company_id, created_at, created_by)
  VALUES (target_auth_user_id, v_name, v_email, 'seller', true, NULL, NOW(), target_auth_user_id)
  ON CONFLICT (id) DO UPDATE
  SET
    role = 'seller',
    status = true,
    name = CASE WHEN public.users.name IS NULL OR public.users.name = '' THEN EXCLUDED.name ELSE public.users.name END,
    email = COALESCE(public.users.email, EXCLUDED.email);

  -- 6. Return success payload
  v_result := jsonb_build_object(
    'status', 'PROVISIONED',
    'user_id', target_auth_user_id,
    'role', 'seller',
    'has_company', (SELECT company_id IS NOT NULL FROM public.users WHERE id = target_auth_user_id),
    'name', v_name
  );

  RETURN v_result;
END;
$$;

REVOKE ALL ON FUNCTION public.provision_individual_seller(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.provision_individual_seller(uuid) TO authenticated;

-- Optional repair queries for existing unprovisioned staging/demo accounts:
-- SELECT public.provision_individual_seller('4e21f195-2f3b-465d-94cc-e47eebd92800'); -- seller.bikaner@gmail.com
-- SELECT public.provision_individual_seller('49534f2f-ec4e-445f-84e8-7d09c7056b6a'); -- seller@demo.com

COMMIT;
