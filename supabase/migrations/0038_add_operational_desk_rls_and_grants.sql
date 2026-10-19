-- Migration: 0038_add_operational_desk_rls_and_grants.sql
-- Micro-Sprint: RB-DB-SEC-01
-- Enables RLS, grants minimal table privileges, and establishes tenant isolation
-- for deals, requirements, availabilities, quotations, requirement_allocations,
-- deal_versions, bookings, dispatches, disputes, notifications, and master reference tables.
-- Depends on: 0036 and 0037 (for get_auth_role, is_admin, is_broker).

BEGIN;

-- ============================================================================
-- 1. Helper Function Verification & Fallback Definitions
-- ============================================================================
CREATE OR REPLACE FUNCTION public.get_auth_role()
RETURNS TEXT
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT COALESCE(
    NULLIF(LOWER(raw_app_meta_data->>'role'), ''),
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

CREATE OR REPLACE FUNCTION public.is_broker()
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT public.get_auth_role() = 'broker';
$$;

REVOKE ALL ON FUNCTION public.is_broker() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.is_broker() TO authenticated;

-- ============================================================================
-- 2. Foreign Key Hardening on deals (PostgREST Relationship Resolution)
-- ============================================================================
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'deals_requirement_id_fk'
  ) THEN
    ALTER TABLE public.deals 
      ADD CONSTRAINT deals_requirement_id_fk 
      FOREIGN KEY (requirement_id) REFERENCES public.requirements(id) ON DELETE RESTRICT;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'deals_broker_id_fk'
  ) THEN
    ALTER TABLE public.deals 
      ADD CONSTRAINT deals_broker_id_fk 
      FOREIGN KEY (broker_id) REFERENCES public.users(id) ON DELETE SET NULL;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'deals_buyer_id_fk'
  ) THEN
    ALTER TABLE public.deals 
      ADD CONSTRAINT deals_buyer_id_fk 
      FOREIGN KEY (buyer_id) REFERENCES public.companies(id) ON DELETE RESTRICT;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'deals_seller_id_fk'
  ) THEN
    ALTER TABLE public.deals 
      ADD CONSTRAINT deals_seller_id_fk 
      FOREIGN KEY (seller_id) REFERENCES public.companies(id) ON DELETE RESTRICT;
  END IF;
END $$;

-- ============================================================================
-- 3. Master Reference Tables (Read-Only Catalogs)
-- ============================================================================
ALTER TABLE public.master_commodities ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.master_grades ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.master_units ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.master_states ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.master_districts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.master_vehicle_types ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE public.master_commodities FROM anon;
REVOKE ALL ON TABLE public.master_grades FROM anon;
REVOKE ALL ON TABLE public.master_units FROM anon;
REVOKE ALL ON TABLE public.master_states FROM anon;
REVOKE ALL ON TABLE public.master_districts FROM anon;
REVOKE ALL ON TABLE public.master_vehicle_types FROM anon;

GRANT SELECT ON TABLE public.master_commodities TO authenticated, anon;
GRANT SELECT ON TABLE public.master_grades TO authenticated, anon;
GRANT SELECT ON TABLE public.master_units TO authenticated, anon;
GRANT SELECT ON TABLE public.master_states TO authenticated, anon;
GRANT SELECT ON TABLE public.master_districts TO authenticated, anon;
GRANT SELECT ON TABLE public.master_vehicle_types TO authenticated, anon;

DROP POLICY IF EXISTS "master_commodities_read" ON public.master_commodities;
CREATE POLICY "master_commodities_read" ON public.master_commodities FOR SELECT TO authenticated, anon USING (true);

DROP POLICY IF EXISTS "master_grades_read" ON public.master_grades;
CREATE POLICY "master_grades_read" ON public.master_grades FOR SELECT TO authenticated, anon USING (true);

DROP POLICY IF EXISTS "master_units_read" ON public.master_units;
CREATE POLICY "master_units_read" ON public.master_units FOR SELECT TO authenticated, anon USING (true);

DROP POLICY IF EXISTS "master_states_read" ON public.master_states;
CREATE POLICY "master_states_read" ON public.master_states FOR SELECT TO authenticated, anon USING (true);

DROP POLICY IF EXISTS "master_districts_read" ON public.master_districts;
CREATE POLICY "master_districts_read" ON public.master_districts FOR SELECT TO authenticated, anon USING (true);

DROP POLICY IF EXISTS "master_vehicle_types_read" ON public.master_vehicle_types;
CREATE POLICY "master_vehicle_types_read" ON public.master_vehicle_types FOR SELECT TO authenticated, anon USING (true);

-- ============================================================================
-- 4. Operational Table: public.deals
-- ============================================================================
ALTER TABLE public.deals ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.deals FROM anon;
GRANT SELECT, INSERT, UPDATE ON TABLE public.deals TO authenticated;

DROP POLICY IF EXISTS "deals_select_policy" ON public.deals;
CREATE POLICY "deals_select_policy" ON public.deals
FOR SELECT TO authenticated
USING (
  broker_id = auth.uid() OR public.is_admin()
);

DROP POLICY IF EXISTS "deals_insert_policy" ON public.deals;
CREATE POLICY "deals_insert_policy" ON public.deals
FOR INSERT TO authenticated
WITH CHECK (
  (broker_id = auth.uid() AND (public.is_broker() OR public.is_admin()))
  OR public.is_admin()
);

DROP POLICY IF EXISTS "deals_update_policy" ON public.deals;
CREATE POLICY "deals_update_policy" ON public.deals
FOR UPDATE TO authenticated
USING (
  broker_id = auth.uid() OR public.is_admin()
)
WITH CHECK (
  broker_id = auth.uid() OR public.is_admin()
);

-- ============================================================================
-- 5. Operational Table: public.requirements
-- ============================================================================
ALTER TABLE public.requirements ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.requirements FROM anon;
GRANT SELECT, INSERT, UPDATE ON TABLE public.requirements TO authenticated;

DROP POLICY IF EXISTS "requirements_select_policy" ON public.requirements;
CREATE POLICY "requirements_select_policy" ON public.requirements
FOR SELECT TO authenticated
USING (
  broker_id = auth.uid()
  OR (visibility = 'global' AND status IN ('Open', 'Partially Fulfilled', 'Allocated'))
  OR public.is_admin()
);

DROP POLICY IF EXISTS "requirements_insert_policy" ON public.requirements;
CREATE POLICY "requirements_insert_policy" ON public.requirements
FOR INSERT TO authenticated
WITH CHECK (
  (broker_id = auth.uid() AND (public.is_broker() OR public.is_admin()))
  OR public.is_admin()
);

DROP POLICY IF EXISTS "requirements_update_policy" ON public.requirements;
CREATE POLICY "requirements_update_policy" ON public.requirements
FOR UPDATE TO authenticated
USING (
  broker_id = auth.uid() OR public.is_admin()
)
WITH CHECK (
  broker_id = auth.uid() OR public.is_admin()
);

-- ============================================================================
-- 6. Operational Table: public.availabilities
-- ============================================================================
ALTER TABLE public.availabilities ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.availabilities FROM anon;
GRANT SELECT, INSERT, UPDATE ON TABLE public.availabilities TO authenticated;

DROP POLICY IF EXISTS "availabilities_select_policy" ON public.availabilities;
CREATE POLICY "availabilities_select_policy" ON public.availabilities
FOR SELECT TO authenticated
USING (
  broker_id = auth.uid()
  OR visibility = 'global'
  OR public.is_admin()
);

DROP POLICY IF EXISTS "availabilities_insert_policy" ON public.availabilities;
CREATE POLICY "availabilities_insert_policy" ON public.availabilities
FOR INSERT TO authenticated
WITH CHECK (
  (broker_id = auth.uid() AND (public.is_broker() OR public.is_admin()))
  OR public.is_admin()
);

DROP POLICY IF EXISTS "availabilities_update_policy" ON public.availabilities;
CREATE POLICY "availabilities_update_policy" ON public.availabilities
FOR UPDATE TO authenticated
USING (
  broker_id = auth.uid() OR public.is_admin()
)
WITH CHECK (
  broker_id = auth.uid() OR public.is_admin()
);

-- ============================================================================
-- 7. Operational Table: public.quotations
-- ============================================================================
ALTER TABLE public.quotations ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.quotations FROM anon;
GRANT SELECT, INSERT, UPDATE ON TABLE public.quotations TO authenticated;

DROP POLICY IF EXISTS "quotations_select_policy" ON public.quotations;
CREATE POLICY "quotations_select_policy" ON public.quotations
FOR SELECT TO authenticated
USING (
  broker_id = auth.uid() OR public.is_admin()
);

DROP POLICY IF EXISTS "quotations_insert_policy" ON public.quotations;
CREATE POLICY "quotations_insert_policy" ON public.quotations
FOR INSERT TO authenticated
WITH CHECK (
  (broker_id = auth.uid() AND (public.is_broker() OR public.is_admin()))
  OR public.is_admin()
);

DROP POLICY IF EXISTS "quotations_update_policy" ON public.quotations;
CREATE POLICY "quotations_update_policy" ON public.quotations
FOR UPDATE TO authenticated
USING (
  broker_id = auth.uid() OR public.is_admin()
)
WITH CHECK (
  broker_id = auth.uid() OR public.is_admin()
);

-- ============================================================================
-- 8. Operational Table: public.requirement_allocations
-- ============================================================================
ALTER TABLE public.requirement_allocations ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.requirement_allocations FROM anon;
GRANT SELECT, INSERT, UPDATE ON TABLE public.requirement_allocations TO authenticated;

DROP POLICY IF EXISTS "requirement_allocations_select_policy" ON public.requirement_allocations;
CREATE POLICY "requirement_allocations_select_policy" ON public.requirement_allocations
FOR SELECT TO authenticated
USING (
  broker_id = auth.uid() OR public.is_admin()
);

DROP POLICY IF EXISTS "requirement_allocations_insert_policy" ON public.requirement_allocations;
CREATE POLICY "requirement_allocations_insert_policy" ON public.requirement_allocations
FOR INSERT TO authenticated
WITH CHECK (
  (broker_id = auth.uid() AND (public.is_broker() OR public.is_admin()))
  OR public.is_admin()
);

DROP POLICY IF EXISTS "requirement_allocations_update_policy" ON public.requirement_allocations;
CREATE POLICY "requirement_allocations_update_policy" ON public.requirement_allocations
FOR UPDATE TO authenticated
USING (
  broker_id = auth.uid() OR public.is_admin()
)
WITH CHECK (
  broker_id = auth.uid() OR public.is_admin()
);

-- ============================================================================
-- 9. Operational Table: public.deal_versions
-- ============================================================================
ALTER TABLE public.deal_versions ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.deal_versions FROM anon;
GRANT SELECT, INSERT, UPDATE ON TABLE public.deal_versions TO authenticated;

DROP POLICY IF EXISTS "deal_versions_select_policy" ON public.deal_versions;
CREATE POLICY "deal_versions_select_policy" ON public.deal_versions
FOR SELECT TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.deals d
    WHERE d.id = deal_versions.request_id
      AND (d.broker_id = auth.uid() OR public.is_admin())
  ) OR public.is_admin()
);

DROP POLICY IF EXISTS "deal_versions_insert_policy" ON public.deal_versions;
CREATE POLICY "deal_versions_insert_policy" ON public.deal_versions
FOR INSERT TO authenticated
WITH CHECK (
  EXISTS (
    SELECT 1 FROM public.deals d
    WHERE d.id = deal_versions.request_id
      AND (d.broker_id = auth.uid() OR public.is_admin())
  ) OR public.is_admin()
);

-- ============================================================================
-- 10. Operational Table: public.bookings
-- ============================================================================
ALTER TABLE public.bookings ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.bookings FROM anon;
GRANT SELECT, INSERT ON TABLE public.bookings TO authenticated;

DROP POLICY IF EXISTS "bookings_select_policy" ON public.bookings;
CREATE POLICY "bookings_select_policy" ON public.bookings
FOR SELECT TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.deals d
    WHERE d.id = bookings.deal_id
      AND (d.broker_id = auth.uid() OR public.is_admin())
  ) OR public.is_admin()
);

DROP POLICY IF EXISTS "bookings_insert_policy" ON public.bookings;
CREATE POLICY "bookings_insert_policy" ON public.bookings
FOR INSERT TO authenticated
WITH CHECK (
  EXISTS (
    SELECT 1 FROM public.deals d
    WHERE d.id = bookings.deal_id
      AND (d.broker_id = auth.uid() OR public.is_admin())
  ) OR public.is_admin()
);

-- ============================================================================
-- 11. Operational Table: public.dispatches
-- ============================================================================
ALTER TABLE public.dispatches ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.dispatches FROM anon;
GRANT SELECT, INSERT, UPDATE ON TABLE public.dispatches TO authenticated;

DROP POLICY IF EXISTS "dispatches_select_policy" ON public.dispatches;
CREATE POLICY "dispatches_select_policy" ON public.dispatches
FOR SELECT TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.deals d
    WHERE d.id = dispatches.deal_id
      AND (d.broker_id = auth.uid() OR public.is_admin())
  )
  OR dispatches.seller_id = auth.uid()
  OR public.is_admin()
);

DROP POLICY IF EXISTS "dispatches_insert_policy" ON public.dispatches;
CREATE POLICY "dispatches_insert_policy" ON public.dispatches
FOR INSERT TO authenticated
WITH CHECK (
  EXISTS (
    SELECT 1 FROM public.deals d
    WHERE d.id = dispatches.deal_id
      AND (d.broker_id = auth.uid() OR public.is_admin())
  )
  OR dispatches.seller_id = auth.uid()
  OR public.is_admin()
);

DROP POLICY IF EXISTS "dispatches_update_policy" ON public.dispatches;
CREATE POLICY "dispatches_update_policy" ON public.dispatches
FOR UPDATE TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.deals d
    WHERE d.id = dispatches.deal_id
      AND (d.broker_id = auth.uid() OR public.is_admin())
  )
  OR dispatches.seller_id = auth.uid()
  OR public.is_admin()
)
WITH CHECK (
  EXISTS (
    SELECT 1 FROM public.deals d
    WHERE d.id = dispatches.deal_id
      AND (d.broker_id = auth.uid() OR public.is_admin())
  )
  OR dispatches.seller_id = auth.uid()
  OR public.is_admin()
);

-- ============================================================================
-- 12. Operational Table: public.disputes
-- ============================================================================
ALTER TABLE public.disputes ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.disputes FROM anon;
GRANT SELECT, INSERT, UPDATE ON TABLE public.disputes TO authenticated;

DROP POLICY IF EXISTS "disputes_select_policy" ON public.disputes;
CREATE POLICY "disputes_select_policy" ON public.disputes
FOR SELECT TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.deals d
    WHERE d.id = disputes.deal_id
      AND (d.broker_id = auth.uid() OR public.is_admin())
  )
  OR disputes.filed_by = auth.uid()
  OR public.is_admin()
);

DROP POLICY IF EXISTS "disputes_insert_policy" ON public.disputes;
CREATE POLICY "disputes_insert_policy" ON public.disputes
FOR INSERT TO authenticated
WITH CHECK (
  EXISTS (
    SELECT 1 FROM public.deals d
    WHERE d.id = disputes.deal_id
      AND (d.broker_id = auth.uid() OR public.is_admin())
  )
  OR disputes.filed_by = auth.uid()
  OR public.is_admin()
);

DROP POLICY IF EXISTS "disputes_update_policy" ON public.disputes;
CREATE POLICY "disputes_update_policy" ON public.disputes
FOR UPDATE TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.deals d
    WHERE d.id = disputes.deal_id
      AND (d.broker_id = auth.uid() OR public.is_admin())
  )
  OR disputes.filed_by = auth.uid()
  OR public.is_admin()
)
WITH CHECK (
  EXISTS (
    SELECT 1 FROM public.deals d
    WHERE d.id = disputes.deal_id
      AND (d.broker_id = auth.uid() OR public.is_admin())
  )
  OR disputes.filed_by = auth.uid()
  OR public.is_admin()
);

-- ============================================================================
-- 13. Operational Table: public.notifications
-- ============================================================================
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.notifications FROM anon;
GRANT SELECT, UPDATE ON TABLE public.notifications TO authenticated;

DROP POLICY IF EXISTS "notifications_select_policy" ON public.notifications;
CREATE POLICY "notifications_select_policy" ON public.notifications
FOR SELECT TO authenticated
USING (
  user_id = auth.uid() OR public.is_admin()
);

DROP POLICY IF EXISTS "notifications_update_policy" ON public.notifications;
CREATE POLICY "notifications_update_policy" ON public.notifications
FOR UPDATE TO authenticated
USING (
  user_id = auth.uid() OR public.is_admin()
)
WITH CHECK (
  user_id = auth.uid() OR public.is_admin()
);

COMMIT;
