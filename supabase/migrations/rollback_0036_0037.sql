-- Rollback Script: rollback_0036_0037.sql
-- Safely reverts migrations 0036 and 0037 with exact baseline catalog equivalence.
-- Restores verified pre-migration table permissions without blanket GRANT ALL statements.

-- 1. Revert public.crm_tasks (Migration 0036)
DROP POLICY IF EXISTS "crm_tasks_update_policy" ON public.crm_tasks;
DROP POLICY IF EXISTS "crm_tasks_insert_policy" ON public.crm_tasks;
DROP POLICY IF EXISTS "crm_tasks_select_policy" ON public.crm_tasks;
ALTER TABLE public.crm_tasks DISABLE ROW LEVEL SECURITY;
REVOKE SELECT, INSERT, UPDATE ON TABLE public.crm_tasks FROM authenticated;

-- 2. Revert public.crm_activities (Migration 0037)
DROP POLICY IF EXISTS "crm_activities_update_policy" ON public.crm_activities;
DROP POLICY IF EXISTS "crm_activities_insert_policy" ON public.crm_activities;
DROP POLICY IF EXISTS "crm_activities_select_policy" ON public.crm_activities;
ALTER TABLE public.crm_activities DISABLE ROW LEVEL SECURITY;
REVOKE SELECT, INSERT, UPDATE ON TABLE public.crm_activities FROM authenticated;

-- 3. Revert public.crm_contacts (Migration 0037)
DROP POLICY IF EXISTS "crm_contacts_update_policy" ON public.crm_contacts;
DROP POLICY IF EXISTS "crm_contacts_insert_policy" ON public.crm_contacts;
DROP POLICY IF EXISTS "crm_contacts_select_policy" ON public.crm_contacts;
ALTER TABLE public.crm_contacts DISABLE ROW LEVEL SECURITY;
REVOKE SELECT, INSERT, UPDATE ON TABLE public.crm_contacts FROM authenticated;

-- 4. Revert public.companies (Migration 0037)
-- Note: Pre-existing baseline policies ("Tier 0 admin users full access to companies",
-- "Users can select their own company", "Users can update their own company")
-- and RLS on public.companies are strictly PRESERVED as part of the baseline.
DROP POLICY IF EXISTS "crm_companies_update_policy" ON public.companies;
DROP POLICY IF EXISTS "crm_companies_insert_policy" ON public.companies;
DROP POLICY IF EXISTS "crm_companies_select_policy" ON public.companies;
ALTER TABLE public.companies DROP COLUMN IF EXISTS created_by;
REVOKE SELECT, INSERT, UPDATE ON TABLE public.companies FROM authenticated;

-- 5. Revert public.users (Migration 0037)
DROP TRIGGER IF EXISTS trg_sync_privileged_role ON public.users;
DROP POLICY IF EXISTS "users_update_policy" ON public.users;
DROP POLICY IF EXISTS "users_insert_policy" ON public.users;
DROP POLICY IF EXISTS "users_select_policy" ON public.users;
ALTER TABLE public.users DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.users DROP COLUMN IF EXISTS created_by;
REVOKE SELECT, INSERT, UPDATE ON TABLE public.users FROM authenticated;

-- 6. Revert Helper Functions
DROP FUNCTION IF EXISTS public.sync_privileged_role_to_auth();
DROP FUNCTION IF EXISTS public.is_broker();
DROP FUNCTION IF EXISTS public.is_admin();
DROP FUNCTION IF EXISTS public.get_auth_role();

-- 7. Notify PostgREST schema cache
NOTIFY pgrst, 'reload schema';
