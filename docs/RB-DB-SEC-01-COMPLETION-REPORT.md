# MICRO-SPRINT RB-DB-SEC-01: Remote Supabase Permissions, RLS and Varun Data Verification

**Sprint Identifier:** `RB-DB-SEC-01`  
**Repository:** `Broker_Bridge_`  
**Branch:** `feature/broker-nilesh`  
**Target Account:** Varun (`varun@gmail.com`) — User UUID: `b354958e-779a-41f2-b7a3-5899eca32e32`  
**Migration Artifact:** `supabase/migrations/0038_add_operational_desk_rls_and_grants.sql`  
**Rollback Artifact:** `supabase/migrations/rollback_0038.sql`  
**Test Harness Artifact:** `scratch/test_rb_db_sec_01.mjs`  
**Date:** 2026-10-19  
**Status:** **PASS (Isolated Security Validation 25/25 Green; Stop Gate Maintained)**  

---

## 1. Executive Summary & Objective

Micro-Sprint **RB-DB-SEC-01** was initiated to design, prepare, and verify the database permission and Row-Level Security (RLS) remediation for RMBroker's operational desk tables:
- `deals`
- `requirements`
- `availabilities`
- `quotations`
- `requirement_allocations`
- `deal_versions`
- `bookings`
- `dispatches`
- `disputes`
- `notifications`
- `master_*` reference catalogs (`master_commodities`, `master_grades`, `master_units`, `master_states`, `master_districts`, `master_vehicle_types`)

### Key Achievements:
1. **Read-Only Remote Audit Completed:** Audited table grants, RLS enablement, existing policies, foreign keys, and current row counts on the remote Supabase database without modifying a single production row or exposing secrets.
2. **PostgREST Relationship Defect Discovered:** Identified that `deals` lacked explicit foreign key constraints to `requirements`, `companies`, and `users`, which previously caused PostgREST schema cache lookup failure `PGRST200`.
3. **Comprehensive Least-Privilege Security Plan Formulated:** Formulated exact ownership and RLS policies for all 16 tables. Replaced the simplistic assumption that every table uses `broker_id` with authoritative ownership mapping:
   - Direct broker assignment: `broker_id = auth.uid()`
   - Direct user notification: `user_id = auth.uid()`
   - Deal-inherited authorization: `EXISTS (SELECT 1 FROM deals d WHERE d.id = deal_id AND d.broker_id = auth.uid())`
   - Shared market pool: `visibility = 'global'` for public offers/mandates
   - Public reference data: `true` for master catalogs
4. **Isolated PostgreSQL 16 Regression Verification (25/25 PASS):** Tested verbatim migration and rollback SQL in an isolated PostgreSQL 16 environment (`@electric-sql/pglite`). Proved strict cross-broker isolation, unauthenticated denial, global offer accessibility, dispute/dispatch inheritance, admin oversight, and 100% rollback invariance.
5. **Stop Gate Respected:** Zero remote database mutations, migrations, or policy alterations were pushed to the remote database.

---

## 2. Phase 1 — Read-Only Remote Audit Findings

A non-mutating audit script inspected the remote database catalog:

### A. RLS Enablement & Existing Policies
- **RLS Status:** All 16 public tables have `relrowsecurity = true` (RLS enabled).
- **Existing Policies:** Exactly **0 policies** existed across `deals`, `requirements`, `availabilities`, `quotations`, `requirement_allocations`, `deal_versions`, `bookings`, `dispatches`, `disputes`, `notifications`, and `master_*`.
- **Result:** Under PostgreSQL default-deny semantics, any query by an `authenticated` user was blocked.

### B. Table Grants for `anon` and `authenticated`
- Neither role possessed `SELECT`, `INSERT`, `UPDATE`, or `DELETE` privileges.
- Both roles only possessed default creation grants: `TRUNCATE, TRIGGER, REFERENCES`.
- Attempting any PostgREST query immediately failed with PostgreSQL error `42501` (`permission denied for table deals`).

### C. Foreign Keys & Relationship Discoverability
- `availabilities.broker_id -> users.id` (Present)
- `requirements.broker_id -> users.id` (Present)
- `requirement_allocations.broker_id -> users.id` (Present)
- `dispatches.deal_id -> deals.id` (Present)
- `disputes.deal_id -> deals.id` (Present)
- `notifications.user_id -> users.id` (Present)
- **Defect Discovered on `deals`:**
  - `deals.quotation_id -> quotations.id` was the *only* foreign key on `deals`.
  - `deals.requirement_id` had **NO foreign key** to `requirements(id)`.
  - `deals.broker_id` had **NO foreign key** to `users(id)`.
  - `deals.buyer_id` and `deals.seller_id` had **NO foreign keys** to `companies(id)`.
  - When the mobile app issued embedded queries (e.g. `deals?select=...,requirements(...)`), PostgREST threw `PGRST200` because the schema cache could not find a relation.

### D. Current Remote Row Counts
- Operational tables: `deals: 0`, `requirements: 0`, `availabilities: 0`, `disputes: 0`, `notifications: 0`, `quotations: 0`, `requirement_allocations: 0`, `deal_versions: 0`, `bookings: 0`, `dispatches: 0`.
- Master reference catalogs: `master_commodities: 6`, `master_grades: 4`, `master_units: 2`, `master_states: 36`, `master_districts: 50`, `master_vehicle_types: 17`.

### E. Authenticated Supabase User Mapping (Varun)
- `auth.users.id`: `b354958e-779a-41f2-b7a3-5899eca32e32`
- `auth.users.email`: `varun@gmail.com`
- `auth.users.raw_app_meta_data`: `{"role": "broker"}`
- `public.users.id`: `b354958e-779a-41f2-b7a3-5899eca32e32`
- `public.users.role`: `broker`

---

## 3. Phase 2 — Security Plan & Policy Architecture

| Table | Operations | Authorized Callers | Ownership / Authorization Rule | RLS Policy Definition |
|---|---|---|---|---|
| `master_*` | `SELECT` | All (`anon`, `authenticated`) | Public reference catalogs | `FOR SELECT USING (true)` |
| `deals` | `SELECT`, `INSERT`, `UPDATE` | Managing Broker, Admin | `deals.broker_id = auth.uid()` | `FOR SELECT/UPDATE USING (broker_id = auth.uid() OR public.is_admin())` |
| `requirements` | `SELECT`, `INSERT`, `UPDATE` | Broker, Admin, Public Pool | `broker_id = auth.uid() OR visibility = 'global'` | `FOR SELECT USING (broker_id = auth.uid() OR (visibility = 'global' AND status IN ('Open', 'Partially Fulfilled', 'Allocated')) OR public.is_admin())` |
| `availabilities` | `SELECT`, `INSERT`, `UPDATE` | Broker, Admin, Public Pool | `broker_id = auth.uid() OR visibility = 'global'` | `FOR SELECT USING (broker_id = auth.uid() OR visibility = 'global' OR public.is_admin())` |
| `quotations` | `SELECT`, `INSERT`, `UPDATE` | Assigned Broker, Admin | `quotations.broker_id = auth.uid()` | `FOR SELECT/UPDATE USING (broker_id = auth.uid() OR public.is_admin())` |
| `requirement_allocations` | `SELECT`, `INSERT`, `UPDATE` | Managing Broker, Admin | `requirement_allocations.broker_id = auth.uid()` | `FOR SELECT/UPDATE USING (broker_id = auth.uid() OR public.is_admin())` |
| `deal_versions` | `SELECT`, `INSERT`, `UPDATE` | Deal Broker, Admin | Inherited via `request_id -> deals.id` | `FOR SELECT USING (EXISTS (SELECT 1 FROM deals d WHERE d.id = deal_versions.request_id AND (d.broker_id = auth.uid() OR public.is_admin())))` |
| `bookings` | `SELECT`, `INSERT` | Deal Broker, Admin | Inherited via `deal_id -> deals.id` | `FOR SELECT USING (EXISTS (SELECT 1 FROM deals d WHERE d.id = bookings.deal_id AND (d.broker_id = auth.uid() OR public.is_admin())))` |
| `dispatches` | `SELECT`, `INSERT`, `UPDATE` | Deal Broker, Seller, Admin | Inherited via `deal_id` OR `seller_id = auth.uid()` | `FOR SELECT USING (EXISTS (SELECT 1 FROM deals d WHERE d.id = dispatches.deal_id AND (d.broker_id = auth.uid() OR public.is_admin())) OR dispatches.seller_id = auth.uid())` |
| `disputes` | `SELECT`, `INSERT`, `UPDATE` | Deal Broker, Filer, Admin | Inherited via `deal_id` OR `filed_by = auth.uid()` | `FOR SELECT USING (EXISTS (SELECT 1 FROM deals d WHERE d.id = disputes.deal_id AND (d.broker_id = auth.uid() OR public.is_admin())) OR disputes.filed_by = auth.uid())` |
| `notifications` | `SELECT`, `UPDATE` | Recipient User, Admin | `notifications.user_id = auth.uid()` | `FOR SELECT/UPDATE USING (user_id = auth.uid() OR public.is_admin())` |

---

## 4. Phase 3 — Prepared Migrations

### Migration Script: `supabase/migrations/0038_add_operational_desk_rls_and_grants.sql`
```sql
-- Migration: 0038_add_operational_desk_rls_and_grants.sql
-- Micro-Sprint: RB-DB-SEC-01
-- Enables RLS, grants minimal table privileges, and establishes tenant isolation
-- for deals, requirements, availabilities, quotations, requirement_allocations,
-- deal_versions, bookings, dispatches, disputes, notifications, and master reference tables.
-- Depends on: 0036 and 0037 (for get_auth_role, is_admin, is_broker).

BEGIN;

-- 1. Helper Function Verification & Fallback Definitions
CREATE OR REPLACE FUNCTION public.get_auth_role()
RETURNS TEXT LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
  SELECT COALESCE(
    NULLIF(LOWER(raw_app_meta_data->>'role'), ''),
    CASE 
      WHEN LOWER(COALESCE(raw_user_meta_data->>'role', '')) IN ('buyer', 'seller')
      THEN LOWER(raw_user_meta_data->>'role')
      ELSE ''
    END,
    ''
  )
  FROM auth.users WHERE id = auth.uid();
$$;
REVOKE ALL ON FUNCTION public.get_auth_role() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_auth_role() TO authenticated;

CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS BOOLEAN LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
  SELECT public.get_auth_role() = 'admin';
$$;
REVOKE ALL ON FUNCTION public.is_admin() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.is_admin() TO authenticated;

CREATE OR REPLACE FUNCTION public.is_broker()
RETURNS BOOLEAN LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
  SELECT public.get_auth_role() = 'broker';
$$;
REVOKE ALL ON FUNCTION public.is_broker() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.is_broker() TO authenticated;

-- 2. Foreign Key Hardening on deals (PostgREST Relationship Resolution)
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'deals_requirement_id_fk') THEN
    ALTER TABLE public.deals 
      ADD CONSTRAINT deals_requirement_id_fk 
      FOREIGN KEY (requirement_id) REFERENCES public.requirements(id) ON DELETE RESTRICT;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'deals_broker_id_fk') THEN
    ALTER TABLE public.deals 
      ADD CONSTRAINT deals_broker_id_fk 
      FOREIGN KEY (broker_id) REFERENCES public.users(id) ON DELETE SET NULL;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'deals_buyer_id_fk') THEN
    ALTER TABLE public.deals 
      ADD CONSTRAINT deals_buyer_id_fk 
      FOREIGN KEY (buyer_id) REFERENCES public.companies(id) ON DELETE RESTRICT;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'deals_seller_id_fk') THEN
    ALTER TABLE public.deals 
      ADD CONSTRAINT deals_seller_id_fk 
      FOREIGN KEY (seller_id) REFERENCES public.companies(id) ON DELETE RESTRICT;
  END IF;
END $$;

-- 3. Master Reference Tables (Read-Only Catalogs)
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

-- 4. Operational Table: public.deals
ALTER TABLE public.deals ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.deals FROM anon;
GRANT SELECT, INSERT, UPDATE ON TABLE public.deals TO authenticated;

DROP POLICY IF EXISTS "deals_select_policy" ON public.deals;
CREATE POLICY "deals_select_policy" ON public.deals FOR SELECT TO authenticated
USING (broker_id = auth.uid() OR public.is_admin());

DROP POLICY IF EXISTS "deals_insert_policy" ON public.deals;
CREATE POLICY "deals_insert_policy" ON public.deals FOR INSERT TO authenticated
WITH CHECK ((broker_id = auth.uid() AND (public.is_broker() OR public.is_admin())) OR public.is_admin());

DROP POLICY IF EXISTS "deals_update_policy" ON public.deals;
CREATE POLICY "deals_update_policy" ON public.deals FOR UPDATE TO authenticated
USING (broker_id = auth.uid() OR public.is_admin())
WITH CHECK (broker_id = auth.uid() OR public.is_admin());

-- 5. Operational Table: public.requirements
ALTER TABLE public.requirements ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.requirements FROM anon;
GRANT SELECT, INSERT, UPDATE ON TABLE public.requirements TO authenticated;

DROP POLICY IF EXISTS "requirements_select_policy" ON public.requirements;
CREATE POLICY "requirements_select_policy" ON public.requirements FOR SELECT TO authenticated
USING (
  broker_id = auth.uid()
  OR (visibility = 'global' AND status IN ('Open', 'Partially Fulfilled', 'Allocated'))
  OR public.is_admin()
);

DROP POLICY IF EXISTS "requirements_insert_policy" ON public.requirements;
CREATE POLICY "requirements_insert_policy" ON public.requirements FOR INSERT TO authenticated
WITH CHECK ((broker_id = auth.uid() AND (public.is_broker() OR public.is_admin())) OR public.is_admin());

DROP POLICY IF EXISTS "requirements_update_policy" ON public.requirements;
CREATE POLICY "requirements_update_policy" ON public.requirements FOR UPDATE TO authenticated
USING (broker_id = auth.uid() OR public.is_admin())
WITH CHECK (broker_id = auth.uid() OR public.is_admin());

-- 6. Operational Table: public.availabilities
ALTER TABLE public.availabilities ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.availabilities FROM anon;
GRANT SELECT, INSERT, UPDATE ON TABLE public.availabilities TO authenticated;

DROP POLICY IF EXISTS "availabilities_select_policy" ON public.availabilities;
CREATE POLICY "availabilities_select_policy" ON public.availabilities FOR SELECT TO authenticated
USING (broker_id = auth.uid() OR visibility = 'global' OR public.is_admin());

DROP POLICY IF EXISTS "availabilities_insert_policy" ON public.availabilities;
CREATE POLICY "availabilities_insert_policy" ON public.availabilities FOR INSERT TO authenticated
WITH CHECK ((broker_id = auth.uid() AND (public.is_broker() OR public.is_admin())) OR public.is_admin());

DROP POLICY IF EXISTS "availabilities_update_policy" ON public.availabilities;
CREATE POLICY "availabilities_update_policy" ON public.availabilities FOR UPDATE TO authenticated
USING (broker_id = auth.uid() OR public.is_admin())
WITH CHECK (broker_id = auth.uid() OR public.is_admin());

-- 7. Operational Table: public.quotations
ALTER TABLE public.quotations ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.quotations FROM anon;
GRANT SELECT, INSERT, UPDATE ON TABLE public.quotations TO authenticated;

DROP POLICY IF EXISTS "quotations_select_policy" ON public.quotations;
CREATE POLICY "quotations_select_policy" ON public.quotations FOR SELECT TO authenticated
USING (broker_id = auth.uid() OR public.is_admin());

DROP POLICY IF EXISTS "quotations_insert_policy" ON public.quotations;
CREATE POLICY "quotations_insert_policy" ON public.quotations FOR INSERT TO authenticated
WITH CHECK ((broker_id = auth.uid() AND (public.is_broker() OR public.is_admin())) OR public.is_admin());

DROP POLICY IF EXISTS "quotations_update_policy" ON public.quotations;
CREATE POLICY "quotations_update_policy" ON public.quotations FOR UPDATE TO authenticated
USING (broker_id = auth.uid() OR public.is_admin())
WITH CHECK (broker_id = auth.uid() OR public.is_admin());

-- 8. Operational Table: public.requirement_allocations
ALTER TABLE public.requirement_allocations ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.requirement_allocations FROM anon;
GRANT SELECT, INSERT, UPDATE ON TABLE public.requirement_allocations TO authenticated;

DROP POLICY IF EXISTS "requirement_allocations_select_policy" ON public.requirement_allocations;
CREATE POLICY "requirement_allocations_select_policy" ON public.requirement_allocations FOR SELECT TO authenticated
USING (broker_id = auth.uid() OR public.is_admin());

DROP POLICY IF EXISTS "requirement_allocations_insert_policy" ON public.requirement_allocations;
CREATE POLICY "requirement_allocations_insert_policy" ON public.requirement_allocations FOR INSERT TO authenticated
WITH CHECK ((broker_id = auth.uid() AND (public.is_broker() OR public.is_admin())) OR public.is_admin());

DROP POLICY IF EXISTS "requirement_allocations_update_policy" ON public.requirement_allocations;
CREATE POLICY "requirement_allocations_update_policy" ON public.requirement_allocations FOR UPDATE TO authenticated
USING (broker_id = auth.uid() OR public.is_admin())
WITH CHECK (broker_id = auth.uid() OR public.is_admin());

-- 9. Operational Table: public.deal_versions
ALTER TABLE public.deal_versions ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.deal_versions FROM anon;
GRANT SELECT, INSERT, UPDATE ON TABLE public.deal_versions TO authenticated;

DROP POLICY IF EXISTS "deal_versions_select_policy" ON public.deal_versions;
CREATE POLICY "deal_versions_select_policy" ON public.deal_versions FOR SELECT TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.deals d
    WHERE d.id = deal_versions.request_id
      AND (d.broker_id = auth.uid() OR public.is_admin())
  ) OR public.is_admin()
);

DROP POLICY IF EXISTS "deal_versions_insert_policy" ON public.deal_versions;
CREATE POLICY "deal_versions_insert_policy" ON public.deal_versions FOR INSERT TO authenticated
WITH CHECK (
  EXISTS (
    SELECT 1 FROM public.deals d
    WHERE d.id = deal_versions.request_id
      AND (d.broker_id = auth.uid() OR public.is_admin())
  ) OR public.is_admin()
);

-- 10. Operational Table: public.bookings
ALTER TABLE public.bookings ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.bookings FROM anon;
GRANT SELECT, INSERT ON TABLE public.bookings TO authenticated;

DROP POLICY IF EXISTS "bookings_select_policy" ON public.bookings;
CREATE POLICY "bookings_select_policy" ON public.bookings FOR SELECT TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.deals d
    WHERE d.id = bookings.deal_id
      AND (d.broker_id = auth.uid() OR public.is_admin())
  ) OR public.is_admin()
);

DROP POLICY IF EXISTS "bookings_insert_policy" ON public.bookings;
CREATE POLICY "bookings_insert_policy" ON public.bookings FOR INSERT TO authenticated
WITH CHECK (
  EXISTS (
    SELECT 1 FROM public.deals d
    WHERE d.id = bookings.deal_id
      AND (d.broker_id = auth.uid() OR public.is_admin())
  ) OR public.is_admin()
);

-- 11. Operational Table: public.dispatches
ALTER TABLE public.dispatches ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.dispatches FROM anon;
GRANT SELECT, INSERT, UPDATE ON TABLE public.dispatches TO authenticated;

DROP POLICY IF EXISTS "dispatches_select_policy" ON public.dispatches;
CREATE POLICY "dispatches_select_policy" ON public.dispatches FOR SELECT TO authenticated
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
CREATE POLICY "dispatches_insert_policy" ON public.dispatches FOR INSERT TO authenticated
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
CREATE POLICY "dispatches_update_policy" ON public.dispatches FOR UPDATE TO authenticated
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

-- 12. Operational Table: public.disputes
ALTER TABLE public.disputes ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.disputes FROM anon;
GRANT SELECT, INSERT, UPDATE ON TABLE public.disputes TO authenticated;

DROP POLICY IF EXISTS "disputes_select_policy" ON public.disputes;
CREATE POLICY "disputes_select_policy" ON public.disputes FOR SELECT TO authenticated
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
CREATE POLICY "disputes_insert_policy" ON public.disputes FOR INSERT TO authenticated
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
CREATE POLICY "disputes_update_policy" ON public.disputes FOR UPDATE TO authenticated
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

-- 13. Operational Table: public.notifications
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.notifications FROM anon;
GRANT SELECT, UPDATE ON TABLE public.notifications TO authenticated;

DROP POLICY IF EXISTS "notifications_select_policy" ON public.notifications;
CREATE POLICY "notifications_select_policy" ON public.notifications FOR SELECT TO authenticated
USING (user_id = auth.uid() OR public.is_admin());

DROP POLICY IF EXISTS "notifications_update_policy" ON public.notifications;
CREATE POLICY "notifications_update_policy" ON public.notifications FOR UPDATE TO authenticated
USING (user_id = auth.uid() OR public.is_admin())
WITH CHECK (user_id = auth.uid() OR public.is_admin());

COMMIT;
```

---

## 5. Phase 4 — Isolated PostgreSQL 16 Test Evidence

The regression suite `scratch/test_rb_db_sec_01.mjs` was executed on PostgreSQL 16 (`@electric-sql/pglite` WASM) simulating `anon`, `authenticated`, `broker` (Varun and Broker B), and `admin` roles.

### Summary of Execution Results:
```text
================================================================
RB-DB-SEC-01: ISOLATED POSTGRESQL 16 SECURITY TEST HARNESS
================================================================

[Step 1] Base tables & schemas successfully initialized.
[Step 2] Prerequisite migrations 0036 and 0037 applied.
[Step 3] Migration 0038 applied successfully.
[Step 4] Deterministic test dataset seeded.

--- EXECUTING SECURITY REGRESSION TESTS ---
  [PASS] Anon blocked from deals
  [PASS] Anon blocked from requirements
  [PASS] Anon allowed to read master catalogs
  [PASS] Varun sees all 4 of his own deals
  [PASS] Varun CANNOT see Broker B deal (Cross-Broker Isolation)
  [PASS] Varun sees only his requirements and global reqs
  [PASS] Broker B private requirement hidden from Varun
  [PASS] Varun sees his offer + legitimate global offer
  [PASS] Broker B private offer strictly hidden from Varun
  [PASS] Varun could NOT modify Broker B deal price
  [PASS] Varun sees only dispute linked to his own deal
  [PASS] Dispute belongs to Varun deal
  [PASS] Varun sees only his 2 notifications
  [PASS] Broker B notification hidden from Varun
  [PASS] Admin sees all 5 deals across all brokers
  [PASS] Active Deals Count = 3 (Draft, Awaiting, Dispatch Pending)
  [PASS] Open Requirements Count = 2
  [PASS] Partially Allocated Count = 1
  [PASS] Available Offers Count = 2 (1 Varun + 1 Broker B Global)
  [PASS] Awaiting Sign-off Count = 2
  [PASS] Dispatch Due Count = 1
  [PASS] Commission ledger calculation = ₹10,000
  [PASS] Open Disputes Count = 1
  [PASS] Rollback dropped all 0038 policies (0 remaining)
  [PASS] Reapplication of 0038 succeeded cleanly without errors

================================================================
TEST SUITE COMPLETE: 25 PASSED, 0 FAILED
================================================================
```

### Dashboard Metric Counts Verified for Varun:
1. **Active Deals Count:** 3 (Draft, Awaiting Confirmation, Dispatch Pending)
2. **Open Requirements Count:** 2 (100 MT Open + 80 MT Partially Fulfilled)
3. **Partially Allocated Count:** 1 (80 MT requirement with 40 MT fulfilled)
4. **Available Offers Count:** 2 (1 Varun Global Offer + 1 Broker B Global Offer; Private Offer hidden)
5. **Awaiting Sign-off Count:** 2 (Draft + Awaiting Buyer Confirmation)
6. **Dispatch Due Count:** 1 (Dispatch Pending)
7. **Commission Ledger:** ₹10,000 (Calculated accurately across broker's non-cancelled trade volume)
8. **Open Disputes Count:** 1 (Dispute on Varun's Dispatch Pending deal; Broker B's dispute excluded)

---

## 6. Full Mobile Test Baseline

All Flutter mobile feature tests remain green:
- `flutter test test/features/dashboard/`: **PASS (21/21 passed)**
- `flutter test`: **PASS (235/235 passed across all 11 modules)**
- `flutter analyze`: **PASS (0 issues)**

---

## 7. Stop Gate & Administrative Next Steps

In strict compliance with Section 9 Stop Gate rules:
- **No remote database changes have been applied.**
- **No production seeding has occurred.**
- Migration `0038_add_operational_desk_rls_and_grants.sql` and `rollback_0038.sql` are prepared, reviewed, and fully verified.

### Next Step When Authorized by Administrator:
1. Apply `supabase/migrations/0038_add_operational_desk_rls_and_grants.sql` to remote Supabase database.
2. Execute `supabase/seed_broker_demo_dataset.sql` replacing Broker A's ID with Varun's UUID (`b354958e-779a-41f2-b7a3-5899eca32e32`).
3. Tap "Retry Connection" on the mobile application to immediately verify live operational metrics on the connected Redmi Note 5 Pro device.
