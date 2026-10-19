-- Migration: rollback_0038.sql
-- Micro-Sprint: RB-DB-SEC-01
-- Reverts all changes applied by 0038_add_operational_desk_rls_and_grants.sql
-- Restores verified pre-migration baseline for table grants, foreign keys, and policies.

BEGIN;

-- 1. Drop Policies
DROP POLICY IF EXISTS "deals_select_policy" ON public.deals;
DROP POLICY IF EXISTS "deals_insert_policy" ON public.deals;
DROP POLICY IF EXISTS "deals_update_policy" ON public.deals;

DROP POLICY IF EXISTS "requirements_select_policy" ON public.requirements;
DROP POLICY IF EXISTS "requirements_insert_policy" ON public.requirements;
DROP POLICY IF EXISTS "requirements_update_policy" ON public.requirements;

DROP POLICY IF EXISTS "availabilities_select_policy" ON public.availabilities;
DROP POLICY IF EXISTS "availabilities_insert_policy" ON public.availabilities;
DROP POLICY IF EXISTS "availabilities_update_policy" ON public.availabilities;

DROP POLICY IF EXISTS "quotations_select_policy" ON public.quotations;
DROP POLICY IF EXISTS "quotations_insert_policy" ON public.quotations;
DROP POLICY IF EXISTS "quotations_update_policy" ON public.quotations;

DROP POLICY IF EXISTS "requirement_allocations_select_policy" ON public.requirement_allocations;
DROP POLICY IF EXISTS "requirement_allocations_insert_policy" ON public.requirement_allocations;
DROP POLICY IF EXISTS "requirement_allocations_update_policy" ON public.requirement_allocations;

DROP POLICY IF EXISTS "deal_versions_select_policy" ON public.deal_versions;
DROP POLICY IF EXISTS "deal_versions_insert_policy" ON public.deal_versions;

DROP POLICY IF EXISTS "bookings_select_policy" ON public.bookings;
DROP POLICY IF EXISTS "bookings_insert_policy" ON public.bookings;

DROP POLICY IF EXISTS "dispatches_select_policy" ON public.dispatches;
DROP POLICY IF EXISTS "dispatches_insert_policy" ON public.dispatches;
DROP POLICY IF EXISTS "dispatches_update_policy" ON public.dispatches;

DROP POLICY IF EXISTS "disputes_select_policy" ON public.disputes;
DROP POLICY IF EXISTS "disputes_insert_policy" ON public.disputes;
DROP POLICY IF EXISTS "disputes_update_policy" ON public.disputes;

DROP POLICY IF EXISTS "notifications_select_policy" ON public.notifications;
DROP POLICY IF EXISTS "notifications_update_policy" ON public.notifications;

DROP POLICY IF EXISTS "master_commodities_read" ON public.master_commodities;
DROP POLICY IF EXISTS "master_grades_read" ON public.master_grades;
DROP POLICY IF EXISTS "master_units_read" ON public.master_units;
DROP POLICY IF EXISTS "master_states_read" ON public.master_states;
DROP POLICY IF EXISTS "master_districts_read" ON public.master_districts;
DROP POLICY IF EXISTS "master_vehicle_types_read" ON public.master_vehicle_types;

-- 2. Revoke Grants (Restoring pre-migration baseline)
REVOKE SELECT, INSERT, UPDATE ON TABLE public.deals FROM authenticated;
REVOKE SELECT, INSERT, UPDATE ON TABLE public.requirements FROM authenticated;
REVOKE SELECT, INSERT, UPDATE ON TABLE public.availabilities FROM authenticated;
REVOKE SELECT, INSERT, UPDATE ON TABLE public.quotations FROM authenticated;
REVOKE SELECT, INSERT, UPDATE ON TABLE public.requirement_allocations FROM authenticated;
REVOKE SELECT, INSERT, UPDATE ON TABLE public.deal_versions FROM authenticated;
REVOKE SELECT, INSERT ON TABLE public.bookings FROM authenticated;
REVOKE SELECT, INSERT, UPDATE ON TABLE public.dispatches FROM authenticated;
REVOKE SELECT, INSERT, UPDATE ON TABLE public.disputes FROM authenticated;
REVOKE SELECT, UPDATE ON TABLE public.notifications FROM authenticated;

REVOKE SELECT ON TABLE public.master_commodities FROM authenticated, anon;
REVOKE SELECT ON TABLE public.master_grades FROM authenticated, anon;
REVOKE SELECT ON TABLE public.master_units FROM authenticated, anon;
REVOKE SELECT ON TABLE public.master_states FROM authenticated, anon;
REVOKE SELECT ON TABLE public.master_districts FROM authenticated, anon;
REVOKE SELECT ON TABLE public.master_vehicle_types FROM authenticated, anon;

-- 3. Drop Foreign Keys Added to deals
ALTER TABLE public.deals DROP CONSTRAINT IF EXISTS deals_requirement_id_fk;
ALTER TABLE public.deals DROP CONSTRAINT IF EXISTS deals_broker_id_fk;
ALTER TABLE public.deals DROP CONSTRAINT IF EXISTS deals_buyer_id_fk;
ALTER TABLE public.deals DROP CONSTRAINT IF EXISTS deals_seller_id_fk;

COMMIT;
