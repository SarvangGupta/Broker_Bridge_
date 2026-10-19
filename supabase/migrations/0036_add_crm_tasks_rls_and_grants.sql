-- Migration: 0036_add_crm_tasks_rls_and_grants.sql
-- Enables RLS, grants minimal table privileges, and establishes broker ownership policies for public.crm_tasks.
-- Implements trusted role authorization to prevent user-editable metadata privilege escalation.

-- 1. Sync any existing trusted admin/broker roles from public.users into auth.users.raw_app_meta_data
-- Note: raw_app_meta_data is protected by Supabase Auth and cannot be modified by client requests.
UPDATE auth.users
SET raw_app_meta_data = COALESCE(raw_app_meta_data, '{}'::jsonb) || jsonb_build_object('role', LOWER(public.users.role))
FROM public.users
WHERE auth.users.id = public.users.id
  AND LOWER(public.users.role) IN ('admin', 'broker', 'buyer', 'seller')
  AND (raw_app_meta_data->>'role' IS NULL OR raw_app_meta_data->>'role' = '');

-- 2. Helper function for authoritative, tamper-proof role lookup
-- Configured as SECURITY DEFINER with fixed empty search_path.
-- Reads directly from auth.users to eliminate any RLS recursion with public.users.
-- User-editable metadata (raw_user_meta_data) can NEVER confer privileged roles ('admin', 'broker').
CREATE OR REPLACE FUNCTION public.get_auth_role()
RETURNS TEXT
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT COALESCE(
    -- 1. Trusted app_metadata (managed exclusively by server/admin via service_role):
    -- Can confer ANY valid role including privileged roles ('admin', 'broker')
    NULLIF(LOWER(raw_app_meta_data->>'role'), ''),
    -- 2. User-editable metadata (raw_user_meta_data):
    -- STRICTLY RESTRICTED to unprivileged counterparty roles ('buyer', 'seller') only!
    -- Privileged roles ('admin', 'broker') are explicitly blocked and cannot be claimed via user_metadata.
    CASE 
      WHEN LOWER(COALESCE(raw_user_meta_data->>'role', '')) IN ('buyer', 'seller')
      THEN LOWER(raw_user_meta_data->>'role')
      ELSE ''
    END,
    ''
  )
  FROM auth.users
  WHERE id = auth.uid();
$$;

REVOKE ALL ON FUNCTION public.get_auth_role() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_auth_role() TO authenticated;

-- 3. Helper function for admin check
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT public.get_auth_role() = 'admin';
$$;

REVOKE ALL ON FUNCTION public.is_admin() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.is_admin() TO authenticated;

-- 4. Grant minimum required table privileges (SELECT, INSERT, UPDATE only)
-- DELETE is intentionally omitted as tasks in RMBroker are audited historical records.
REVOKE ALL ON TABLE public.crm_tasks FROM anon;
GRANT SELECT, INSERT, UPDATE ON TABLE public.crm_tasks TO authenticated;

-- 5. Ensure RLS is active on public.crm_tasks
ALTER TABLE public.crm_tasks ENABLE ROW LEVEL SECURITY;

-- 6. SELECT Policy: Brokers can only view their own tasks; admins can view all tasks
DROP POLICY IF EXISTS "crm_tasks_select_policy" ON public.crm_tasks;
CREATE POLICY "crm_tasks_select_policy"
ON public.crm_tasks
FOR SELECT
TO authenticated
USING (
  broker_id = auth.uid() OR public.is_admin()
);

-- 7. INSERT Policy: Brokers can only create tasks assigned to themselves; admins can create tasks for any broker
DROP POLICY IF EXISTS "crm_tasks_insert_policy" ON public.crm_tasks;
CREATE POLICY "crm_tasks_insert_policy"
ON public.crm_tasks
FOR INSERT
TO authenticated
WITH CHECK (
  broker_id = auth.uid() OR public.is_admin()
);

-- 8. UPDATE Policy: Brokers can only update their own tasks; prevents reassigning broker_id
DROP POLICY IF EXISTS "crm_tasks_update_policy" ON public.crm_tasks;
CREATE POLICY "crm_tasks_update_policy"
ON public.crm_tasks
FOR UPDATE
TO authenticated
USING (
  broker_id = auth.uid() OR public.is_admin()
)
WITH CHECK (
  broker_id = auth.uid() OR public.is_admin()
);

-- 9. Notify PostgREST to reload schema cache immediately
NOTIFY pgrst, 'reload schema';
