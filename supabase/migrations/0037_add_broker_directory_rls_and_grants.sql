-- Migration: 0037_add_broker_directory_rls_and_grants.sql
-- Enables RLS, grants minimal table privileges, and establishes tenant isolation
-- for public.companies, public.users, public.crm_contacts, and public.crm_activities.
-- Depends on: 0036_add_crm_tasks_rls_and_grants.sql (for public.is_admin() and public.get_auth_role())

-- ============================================================================
-- 1. Schema Hardening: Tenant Ownership Columns
-- ============================================================================
-- Adds optional created_by tracking to companies and users to allow safe
-- INSERT ... RETURNING and strict cross-broker counterparty isolation.
ALTER TABLE public.companies 
  ADD COLUMN IF NOT EXISTS created_by UUID REFERENCES public.users(id) DEFAULT auth.uid();

ALTER TABLE public.users 
  ADD COLUMN IF NOT EXISTS created_by UUID REFERENCES public.users(id) DEFAULT auth.uid();

-- ============================================================================
-- 2. Helper Function: is_broker()
-- ============================================================================
-- Evaluates caller identity via trusted get_auth_role() without RLS recursion.
-- Cannot be fooled by client-side raw_user_meta_data modifications.
CREATE OR REPLACE FUNCTION public.is_broker()
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT public.get_auth_role() = 'broker';
$$;

-- Restrict execution strictly to authenticated role; revoke from PUBLIC/anon
REVOKE ALL ON FUNCTION public.is_broker() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.is_broker() TO authenticated;

-- ============================================================================
-- 3. Trusted Role Synchronization Trigger
-- ============================================================================
-- Automatically synchronizes trusted roles into auth.users.raw_app_meta_data
-- whenever an admin provisions or updates a privileged user in public.users.
CREATE OR REPLACE FUNCTION public.sync_privileged_role_to_auth()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_normalized_role TEXT;
BEGIN
  v_normalized_role := LOWER(TRIM(COALESCE(NEW.role, '')));

  IF v_normalized_role IN ('admin', 'broker', 'buyer', 'seller') THEN
    -- Synchronize supported role into trusted raw_app_meta_data, preserving all existing metadata keys
    UPDATE auth.users
    SET raw_app_meta_data = COALESCE(raw_app_meta_data, '{}'::jsonb) || jsonb_build_object('role', v_normalized_role)
    WHERE id = NEW.id;
  ELSE
    -- Null, empty, or unsupported role (e.g. deactivated/suspended):
    -- Explicitly strip the role key from raw_app_meta_data so no stale privileged access can persist!
    UPDATE auth.users
    SET raw_app_meta_data = COALESCE(raw_app_meta_data, '{}'::jsonb) - 'role'
    WHERE id = NEW.id;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_sync_privileged_role ON public.users;
CREATE TRIGGER trg_sync_privileged_role
AFTER INSERT OR UPDATE OF role ON public.users
FOR EACH ROW
EXECUTE FUNCTION public.sync_privileged_role_to_auth();

-- ============================================================================
-- 4. Table: public.crm_contacts
-- ============================================================================
ALTER TABLE public.crm_contacts ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.crm_contacts FROM anon;
GRANT SELECT, INSERT, UPDATE ON TABLE public.crm_contacts TO authenticated;

-- SELECT: Brokers can only view contacts assigned to their desk; admins can view all
DROP POLICY IF EXISTS "crm_contacts_select_policy" ON public.crm_contacts;
CREATE POLICY "crm_contacts_select_policy"
ON public.crm_contacts
FOR SELECT
TO authenticated
USING (
  broker_id = auth.uid() OR public.is_admin()
);

-- INSERT: Brokers can only link contacts to their own broker ID
DROP POLICY IF EXISTS "crm_contacts_insert_policy" ON public.crm_contacts;
CREATE POLICY "crm_contacts_insert_policy"
ON public.crm_contacts
FOR INSERT
TO authenticated
WITH CHECK (
  (broker_id = auth.uid() AND (public.is_broker() OR public.is_admin()))
  OR public.is_admin()
);

-- UPDATE: Brokers can only update their own contacts; prevents reassigning broker_id
DROP POLICY IF EXISTS "crm_contacts_update_policy" ON public.crm_contacts;
CREATE POLICY "crm_contacts_update_policy"
ON public.crm_contacts
FOR UPDATE
TO authenticated
USING (
  broker_id = auth.uid() OR public.is_admin()
)
WITH CHECK (
  broker_id = auth.uid() OR public.is_admin()
);

-- ============================================================================
-- 5. Table: public.crm_activities
-- ============================================================================
ALTER TABLE public.crm_activities ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.crm_activities FROM anon;
GRANT SELECT, INSERT, UPDATE ON TABLE public.crm_activities TO authenticated;

-- SELECT: Brokers can view activities for contacts belonging to their desk
DROP POLICY IF EXISTS "crm_activities_select_policy" ON public.crm_activities;
CREATE POLICY "crm_activities_select_policy"
ON public.crm_activities
FOR SELECT
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.crm_contacts
    WHERE crm_contacts.id = crm_activities.contact_id
      AND (crm_contacts.broker_id = auth.uid() OR public.is_admin())
  )
);

-- INSERT: Activities can only be logged against contacts owned by the calling broker
DROP POLICY IF EXISTS "crm_activities_insert_policy" ON public.crm_activities;
CREATE POLICY "crm_activities_insert_policy"
ON public.crm_activities
FOR INSERT
TO authenticated
WITH CHECK (
  EXISTS (
    SELECT 1 FROM public.crm_contacts
    WHERE crm_contacts.id = crm_activities.contact_id
      AND (crm_contacts.broker_id = auth.uid() OR public.is_admin())
  )
);

-- UPDATE: Activities can only be updated if owned by the calling broker
DROP POLICY IF EXISTS "crm_activities_update_policy" ON public.crm_activities;
CREATE POLICY "crm_activities_update_policy"
ON public.crm_activities
FOR UPDATE
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.crm_contacts
    WHERE crm_contacts.id = crm_activities.contact_id
      AND (crm_contacts.broker_id = auth.uid() OR public.is_admin())
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1 FROM public.crm_contacts
    WHERE crm_contacts.id = crm_activities.contact_id
      AND (crm_contacts.broker_id = auth.uid() OR public.is_admin())
  )
);

-- ============================================================================
-- 6. Table: public.companies
-- ============================================================================
ALTER TABLE public.companies ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.companies FROM anon;
GRANT SELECT, INSERT, UPDATE ON TABLE public.companies TO authenticated;

-- Note: Existing company policies ("Tier 0 admin users full access to companies",
-- "Users can select their own company", "Users can update their own company") are preserved.
-- The policies below extend access to broker counterparties without policy recursion.

-- SELECT: Brokers can only view companies they created or that are linked to their CRM contacts
DROP POLICY IF EXISTS "crm_companies_select_policy" ON public.companies;
CREATE POLICY "crm_companies_select_policy"
ON public.companies
FOR SELECT
TO authenticated
USING (
  public.is_admin()
  OR created_by = auth.uid()
  OR EXISTS (
    SELECT 1 FROM public.crm_contacts
    WHERE crm_contacts.company_id = companies.id
      AND crm_contacts.broker_id = auth.uid()
  )
);

-- INSERT: Authenticated brokers and admins can create new counterparty companies
DROP POLICY IF EXISTS "crm_companies_insert_policy" ON public.companies;
CREATE POLICY "crm_companies_insert_policy"
ON public.companies
FOR INSERT
TO authenticated
WITH CHECK (
  (public.is_broker() OR public.is_admin())
  AND (created_by IS NULL OR created_by = auth.uid())
);

-- UPDATE: Brokers can update companies they created or that are linked to their CRM contacts
DROP POLICY IF EXISTS "crm_companies_update_policy" ON public.companies;
CREATE POLICY "crm_companies_update_policy"
ON public.companies
FOR UPDATE
TO authenticated
USING (
  public.is_admin()
  OR created_by = auth.uid()
  OR EXISTS (
    SELECT 1 FROM public.crm_contacts
    WHERE crm_contacts.company_id = companies.id
      AND crm_contacts.broker_id = auth.uid()
  )
)
WITH CHECK (
  public.is_admin()
  OR created_by = auth.uid()
  OR EXISTS (
    SELECT 1 FROM public.crm_contacts
    WHERE crm_contacts.company_id = companies.id
      AND crm_contacts.broker_id = auth.uid()
  )
);

-- ============================================================================
-- 7. Table: public.users
-- ============================================================================
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.users FROM anon;
GRANT SELECT, INSERT, UPDATE ON TABLE public.users TO authenticated;

-- SELECT:
-- 1. Self: id = auth.uid()
-- 2. Admin: public.is_admin()
-- 3. Counterparties: role IN ('buyer', 'seller') ONLY IF created by this broker OR linked to this broker's contacts!
DROP POLICY IF EXISTS "users_select_policy" ON public.users;
CREATE POLICY "users_select_policy"
ON public.users
FOR SELECT
TO authenticated
USING (
  id = auth.uid()
  OR public.is_admin()
  OR (
    LOWER(role) IN ('buyer', 'seller')
    AND (
      created_by = auth.uid()
      OR EXISTS (
        SELECT 1 FROM public.crm_contacts
        WHERE crm_contacts.user_id = users.id
          AND crm_contacts.broker_id = auth.uid()
      )
    )
  )
);

-- INSERT (Anti-Privilege Escalation):
-- Brokers can ONLY create users with role 'buyer' or 'seller', with created_by bound to auth.uid().
-- Creating 'broker' or 'admin' roles is strictly restricted to admins.
DROP POLICY IF EXISTS "users_insert_policy" ON public.users;
CREATE POLICY "users_insert_policy"
ON public.users
FOR INSERT
TO authenticated
WITH CHECK (
  public.is_admin()
  OR (
    public.is_broker()
    AND LOWER(role) IN ('buyer', 'seller')
    AND (created_by IS NULL OR created_by = auth.uid())
  )
);

-- UPDATE (Self-Role Escalation Protection & Cross-Broker Shield):
-- 1. Admins can update any user.
-- 2. Self-update: CANNOT change own role! Must match immutable get_auth_role().
-- 3. Broker updating counterparty: Explicitly applies to counterparties only (id != auth.uid()),
--    caller must be broker, role must strictly remain 'buyer' or 'seller',
--    and target must be created by or linked to this broker desk.
DROP POLICY IF EXISTS "users_update_policy" ON public.users;
CREATE POLICY "users_update_policy"
ON public.users
FOR UPDATE
TO authenticated
USING (
  id = auth.uid()
  OR public.is_admin()
  OR (
    LOWER(role) IN ('buyer', 'seller')
    AND (
      created_by = auth.uid()
      OR EXISTS (
        SELECT 1 FROM public.crm_contacts
        WHERE crm_contacts.user_id = users.id
          AND crm_contacts.broker_id = auth.uid()
      )
    )
  )
)
WITH CHECK (
  public.is_admin()
  OR (
    -- 1. Self-update: Caller updates own profile, role MUST match authoritative auth role (no self-promotion!)
    id = auth.uid()
    AND LOWER(role) = public.get_auth_role()
  )
  OR (
    -- 2. Broker updating counterparty: Explicitly applies to counterparties only (id != auth.uid()),
    -- caller must be an authorized broker, target role must strictly remain 'buyer' or 'seller',
    -- and target must be created by or linked to this broker desk.
    id != auth.uid()
    AND public.is_broker()
    AND LOWER(role) IN ('buyer', 'seller')
    AND (created_by IS NULL OR created_by = auth.uid())
    AND (
      created_by = auth.uid()
      OR EXISTS (
        SELECT 1 FROM public.crm_contacts
        WHERE crm_contacts.user_id = users.id
          AND crm_contacts.broker_id = auth.uid()
      )
    )
  )
);

-- ============================================================================
-- 8. Reload PostgREST Schema Cache
-- ============================================================================
NOTIFY pgrst, 'reload schema';
