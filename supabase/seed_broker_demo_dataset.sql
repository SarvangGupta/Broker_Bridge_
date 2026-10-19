-- ============================================================================
-- RMBROKER TEST DATASET SEED SCRIPT: RB-TEST-DATA-01
-- Target Environment: Isolated Test / Development Database ONLY
-- Idempotency: All statements use ON CONFLICT DO NOTHING or WHERE NOT EXISTS
-- Entity Prefix: 'RBTEST-' for clear synthetic identification
-- ============================================================================

BEGIN;

-- ----------------------------------------------------------------------------
-- 1. TEST USERS (Brokers, Buyers, Sellers)
-- ----------------------------------------------------------------------------
INSERT INTO public.users (id, name, email, mobile, role, status, created_at)
VALUES
  -- Dedicated Test Brokers
  ('00000000-0000-0000-0000-0000000000a1', 'RBTEST-BROKER-A (Primary)', 'rbtest.broker.a@example.com', '+919876500001', 'broker', true, now() - interval '60 days'),
  ('00000000-0000-0000-0000-0000000000b1', 'RBTEST-BROKER-B (Tenant Isolation)', 'rbtest.broker.b@example.com', '+919876500002', 'broker', true, now() - interval '60 days'),

  -- Buyer Contact Persons
  ('00000000-0000-0000-0000-000000000101', 'RBTEST-BUYER-01-USER (Aman Sharma)', 'rbtest.buyer01@example.com', '+919876500101', 'buyer', true, now() - interval '45 days'),
  ('00000000-0000-0000-0000-000000000102', 'RBTEST-BUYER-02-USER (Vikas Verma)', 'rbtest.buyer02@example.com', '+919876500102', 'buyer', true, now() - interval '40 days'),
  ('00000000-0000-0000-0000-000000000103', 'RBTEST-BUYER-03-USER (Pooja Agarwal)', 'rbtest.buyer03@example.com', '+919876500103', 'buyer', true, now() - interval '35 days'),
  ('00000000-0000-0000-0000-000000000104', 'RBTEST-BUYER-04-USER (Deepak Jain)', 'rbtest.buyer04@example.com', '+919876500104', 'buyer', true, now() - interval '30 days'),
  ('00000000-0000-0000-0000-000000000105', 'RBTEST-BUYER-05-USER (Ritu Singhania)', 'rbtest.buyer05@example.com', '+919876500105', 'buyer', true, now() - interval '25 days'),
  ('00000000-0000-0000-0000-000000000106', 'RBTEST-BUYER-06-USER (Broker-B Client)', 'rbtest.buyer06@example.com', '+919876500106', 'buyer', true, now() - interval '20 days'),

  -- Seller Contact Persons
  ('00000000-0000-0000-0000-000000000201', 'RBTEST-SELLER-01-USER (Rajesh Patidar)', 'rbtest.seller01@example.com', '+919876500201', 'seller', true, now() - interval '50 days'),
  ('00000000-0000-0000-0000-000000000202', 'RBTEST-SELLER-02-USER (Mahesh Choudhary)', 'rbtest.seller02@example.com', '+919876500202', 'seller', true, now() - interval '48 days'),
  ('00000000-0000-0000-0000-000000000203', 'RBTEST-SELLER-03-USER (Suresh Meena)', 'rbtest.seller03@example.com', '+919876500203', 'seller', true, now() - interval '42 days'),
  ('00000000-0000-0000-0000-000000000204', 'RBTEST-SELLER-04-USER (Broker-B Vendor)', 'rbtest.seller04@example.com', '+919876500204', 'seller', true, now() - interval '20 days')
ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name,
  email = EXCLUDED.email,
  mobile = EXCLUDED.mobile,
  role = EXCLUDED.role,
  status = EXCLUDED.status;

-- ----------------------------------------------------------------------------
-- 2. REFERENCE / MASTER DATA (States, Districts, Commodities, Grades, Units)
-- ----------------------------------------------------------------------------
INSERT INTO public.master_states (id, name, code)
VALUES
  ('10000000-0000-0000-0000-000000000001', 'Rajasthan', 'RJ'),
  ('10000000-0000-0000-0000-000000000002', 'Madhya Pradesh', 'MP')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.master_districts (id, name, state_id)
VALUES
  ('11000000-0000-0000-0000-000000000001', 'Kota', '10000000-0000-0000-0000-000000000001'),
  ('11000000-0000-0000-0000-000000000002', 'Jaipur', '10000000-0000-0000-0000-000000000001'),
  ('11000000-0000-0000-0000-000000000003', 'Baran', '10000000-0000-0000-0000-000000000001'),
  ('11000000-0000-0000-0000-000000000004', 'Ujjain', '10000000-0000-0000-0000-000000000002')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.master_units (id, name, symbol)
VALUES
  ('22000000-0000-0000-0000-000000000001', 'Metric Ton', 'MT'),
  ('22000000-0000-0000-0000-000000000002', 'Quintal', 'Qtl')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.master_commodities (id, name, code, status)
VALUES
  ('20000000-0000-0000-0000-000000000001', 'Yellow Maize (Corn)', 'MAIZE-01', true),
  ('20000000-0000-0000-0000-000000000002', 'Sharbati Wheat', 'WHEAT-01', true),
  ('20000000-0000-0000-0000-000000000003', 'Soybean Seed', 'SOY-01', true)
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.master_grades (id, commodity_id, grade_name, parameters)
VALUES
  ('21000000-0000-0000-0000-000000000001', '20000000-0000-0000-0000-000000000001', 'Grade A Milling', '{"moisture_max": 13.0, "damaged_max": 2.0, "foreign_matter_max": 1.0}'::jsonb),
  ('21000000-0000-0000-0000-000000000002', '20000000-0000-0000-0000-000000000001', 'Feed Grade Premium', '{"moisture_max": 14.5, "damaged_max": 4.0, "foreign_matter_max": 2.0}'::jsonb),
  ('21000000-0000-0000-0000-000000000003', '20000000-0000-0000-0000-000000000002', 'Premium Sharbati', '{"moisture_max": 11.5, "foreign_matter_max": 0.5, "protein_min": 12.5}'::jsonb),
  ('21000000-0000-0000-0000-000000000004', '20000000-0000-0000-0000-000000000003', 'Standard Mandi Grade', '{"moisture_max": 10.0, "oil_content_min": 18.0}'::jsonb)
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.master_vehicle_types (id, name, status)
VALUES
  ('23000000-0000-0000-0000-000000000001', '32FT Multi-Axle Truck', true),
  ('23000000-0000-0000-0000-000000000002', '24FT Open Taurus Truck', true)
ON CONFLICT (id) DO NOTHING;

-- ----------------------------------------------------------------------------
-- 3. TEST ENTERPRISES / COMPANIES (Buyers & Sellers)
-- ----------------------------------------------------------------------------
INSERT INTO public.companies (id, name, gst, state_id, district_id, is_verified, trust_score, status)
VALUES
  -- Buyer Companies
  ('30000000-0000-0000-0000-000000000101', 'RBTEST AgrInnovate Feeds Pvt Ltd', '08AAAAA0001A1Z5', '10000000-0000-0000-0000-000000000001', '11000000-0000-0000-0000-000000000001', true, 95, true),
  ('30000000-0000-0000-0000-000000000102', 'RBTEST North Dairy Feed Corp', '08AAAAB0002B1Z6', '10000000-0000-0000-0000-000000000001', '11000000-0000-0000-0000-000000000003', true, 90, true),
  ('30000000-0000-0000-0000-000000000103', 'RBTEST Golden Harvest Flour Mills', '08AAAAC0003C1Z7', '10000000-0000-0000-0000-000000000001', '11000000-0000-0000-0000-000000000002', true, 98, true),
  ('30000000-0000-0000-0000-000000000104', 'RBTEST Frontier Starch Processing', '08AAAAD0004D1Z8', '10000000-0000-0000-0000-000000000001', '11000000-0000-0000-0000-000000000001', true, 88, true),
  ('30000000-0000-0000-0000-000000000105', 'RBTEST Malwa Solvent Extractions', '23AAAAE0005E1Z9', '10000000-0000-0000-0000-000000000002', '11000000-0000-0000-0000-000000000004', false, 82, true),
  ('30000000-0000-0000-0000-000000000106', 'RBTEST Mewar Grains Distributing', '08AAAAF0006F1ZA', '10000000-0000-0000-0000-000000000001', '11000000-0000-0000-0000-000000000002', true, 89, true),

  -- Seller Companies
  ('30000000-0000-0000-0000-000000000201', 'RBTEST Kota Agro Warehousing LLP', '08BAAAA0001A1Z1', '10000000-0000-0000-0000-000000000001', '11000000-0000-0000-0000-000000000001', true, 96, true),
  ('30000000-0000-0000-0000-000000000202', 'RBTEST Hadoti Grain Producers Co', '08BAAAB0002B1Z2', '10000000-0000-0000-0000-000000000001', '11000000-0000-0000-0000-000000000003', true, 92, true),
  ('30000000-0000-0000-0000-000000000203', 'RBTEST Shekhawati Wheat Traders', '08BAAAC0003C1Z3', '10000000-0000-0000-0000-000000000001', '11000000-0000-0000-0000-000000000002', true, 94, true),
  ('30000000-0000-0000-0000-000000000204', 'RBTEST Chambal Farm Suppliers', '08BAAAD0004D1Z4', '10000000-0000-0000-0000-000000000001', '11000000-0000-0000-0000-000000000001', true, 87, true)
ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name,
  gst = EXCLUDED.gst,
  is_verified = EXCLUDED.is_verified,
  trust_score = EXCLUDED.trust_score,
  status = EXCLUDED.status;

-- ----------------------------------------------------------------------------
-- 4. CRM CONTACT DIRECTORY (Broker counterparty assignments)
-- ----------------------------------------------------------------------------
INSERT INTO public.crm_contacts (id, broker_id, user_id, company_id, last_activity_at, created_at)
VALUES
  -- Broker A's Portfolio
  ('40000000-0000-0000-0000-000000000101', '00000000-0000-0000-0000-0000000000a1', '00000000-0000-0000-0000-000000000101', '30000000-0000-0000-0000-000000000101', now() - interval '1 hour', now() - interval '45 days'),
  ('40000000-0000-0000-0000-000000000102', '00000000-0000-0000-0000-0000000000a1', '00000000-0000-0000-0000-000000000102', '30000000-0000-0000-0000-000000000102', now() - interval '4 hours', now() - interval '40 days'),
  ('40000000-0000-0000-0000-000000000103', '00000000-0000-0000-0000-0000000000a1', '00000000-0000-0000-0000-000000000103', '30000000-0000-0000-0000-000000000103', now() - interval '12 hours', now() - interval '35 days'),
  ('40000000-0000-0000-0000-000000000104', '00000000-0000-0000-0000-0000000000a1', '00000000-0000-0000-0000-000000000104', '30000000-0000-0000-0000-000000000104', now() - interval '1 day', now() - interval '30 days'),
  ('40000000-0000-0000-0000-000000000105', '00000000-0000-0000-0000-0000000000a1', '00000000-0000-0000-0000-000000000105', '30000000-0000-0000-0000-000000000105', now() - interval '3 days', now() - interval '25 days'),

  ('40000000-0000-0000-0000-000000000201', '00000000-0000-0000-0000-0000000000a1', '00000000-0000-0000-0000-000000000201', '30000000-0000-0000-0000-000000000201', now() - interval '2 hours', now() - interval '50 days'),
  ('40000000-0000-0000-0000-000000000202', '00000000-0000-0000-0000-0000000000a1', '00000000-0000-0000-0000-000000000202', '30000000-0000-0000-0000-000000000202', now() - interval '5 hours', now() - interval '48 days'),
  ('40000000-0000-0000-0000-000000000203', '00000000-0000-0000-0000-0000000000a1', '00000000-0000-0000-0000-000000000203', '30000000-0000-0000-0000-000000000203', now() - interval '18 hours', now() - interval '42 days'),

  -- Broker B's Portfolio (Tenant Isolation Validation)
  ('40000000-0000-0000-0000-000000000106', '00000000-0000-0000-0000-0000000000b1', '00000000-0000-0000-0000-000000000106', '30000000-0000-0000-0000-000000000106', now() - interval '1 day', now() - interval '20 days'),
  ('40000000-0000-0000-0000-000000000204', '00000000-0000-0000-0000-0000000000b1', '00000000-0000-0000-0000-000000000204', '30000000-0000-0000-0000-000000000204', now() - interval '2 days', now() - interval '20 days')
ON CONFLICT (id) DO NOTHING;

-- ----------------------------------------------------------------------------
-- 5. SELLER AVAILABILITIES (Supply Offers with Lot Models)
-- ----------------------------------------------------------------------------
-- Offer 01: Seller 01, Maize, 60 MT. Allocated 60 MT to Buyer 01 -> Available 0 MT, Reserved 60 MT.
-- Offer 02: Seller 02, Maize, 80 MT. Allocated 40 MT to Buyer 01 -> Available 40 MT, Reserved 40 MT.
-- Offer 03: Seller 03, Wheat, 70 MT. Target match for Buyer 03 (50 MT) -> Available 70 MT.
INSERT INTO public.availabilities (
  id, company_id, commodity_id, grade_id, quantity, unit_id, price,
  state_id, district_id, valid_until, status, visibility, broker_id,
  lot_number, total_quantity, available_quantity, reserved_quantity, sold_quantity,
  minimum_order_quantity, asking_price, confidential_minimum_price, available_from, version, created_at
)
VALUES
  (
    '50000000-0000-0000-0000-000000000201',
    '30000000-0000-0000-0000-000000000201', -- Kota Agro Warehousing
    '20000000-0000-0000-0000-000000000001', -- Yellow Maize
    '21000000-0000-0000-0000-000000000001', -- Grade A Milling
    60,
    '22000000-0000-0000-0000-000000000001', -- MT
    22500,
    '10000000-0000-0000-0000-000000000001', -- Rajasthan
    '11000000-0000-0000-0000-000000000001', -- Kota
    now() + interval '30 days',
    'Reserved',
    'global',
    '00000000-0000-0000-0000-0000000000a1',
    'RBTEST-LOT-MZ-60',
    60, 0, 60, 0, 20, 22500, 22200, now() - interval '5 days', 1, now() - interval '5 days'
  ),
  (
    '50000000-0000-0000-0000-000000000202',
    '30000000-0000-0000-0000-000000000202', -- Hadoti Grain Producers
    '20000000-0000-0000-0000-000000000001', -- Yellow Maize
    '21000000-0000-0000-0000-000000000001', -- Grade A Milling
    80,
    '22000000-0000-0000-0000-000000000001', -- MT
    22700,
    '10000000-0000-0000-0000-000000000001', -- Rajasthan
    '11000000-0000-0000-0000-000000000003', -- Baran
    now() + interval '30 days',
    'Open',
    'global',
    '00000000-0000-0000-0000-0000000000a1',
    'RBTEST-LOT-MZ-80',
    80, 40, 40, 0, 20, 22700, 22400, now() - interval '4 days', 1, now() - interval '4 days'
  ),
  (
    '50000000-0000-0000-0000-000000000203',
    '30000000-0000-0000-0000-000000000203', -- Shekhawati Wheat Traders
    '20000000-0000-0000-0000-000000000002', -- Sharbati Wheat
    '21000000-0000-0000-0000-000000000003', -- Premium Sharbati
    70,
    '22000000-0000-0000-0000-000000000001', -- MT
    28000,
    '10000000-0000-0000-0000-000000000001', -- Rajasthan
    '11000000-0000-0000-0000-000000000002', -- Jaipur
    now() + interval '30 days',
    'Open',
    'global',
    '00000000-0000-0000-0000-0000000000a1',
    'RBTEST-LOT-WH-70',
    70, 70, 0, 0, 25, 28000, 27600, now() - interval '3 days', 1, now() - interval '3 days'
  )
ON CONFLICT (id) DO UPDATE SET
  status = EXCLUDED.status,
  total_quantity = EXCLUDED.total_quantity,
  available_quantity = EXCLUDED.available_quantity,
  reserved_quantity = EXCLUDED.reserved_quantity,
  asking_price = EXCLUDED.asking_price;

-- ----------------------------------------------------------------------------
-- 6. BUYER REQUIREMENTS (Purchase Mandates)
-- ----------------------------------------------------------------------------
INSERT INTO public.requirements (
  id, company_id, commodity_id, grade_id, quantity, unit_id, target_price,
  delivery_terms_id, target_date, status, fulfilled_quantity, visibility, broker_id, created_at
)
VALUES
  -- Req 01: Buyer 01, Maize 100 MT (Fully split-allocated 60 + 40)
  (
    '60000000-0000-0000-0000-000000000101',
    '30000000-0000-0000-0000-000000000101', -- AgrInnovate Feeds
    '20000000-0000-0000-0000-000000000001', -- Maize
    '21000000-0000-0000-0000-000000000001', -- Grade A Milling
    100,
    '22000000-0000-0000-0000-000000000001', -- MT
    23000,
    'FOR Mill Delivery, Kota Mandi',
    now() + interval '15 days',
    'Allocated',
    0,
    'global',
    '00000000-0000-0000-0000-0000000000a1',
    now() - interval '6 days'
  ),
  -- Req 02: Buyer 02, Maize 75 MT (Competes for Seller 02 remaining 40 MT -> Shortage of 35 MT)
  (
    '60000000-0000-0000-0000-000000000102',
    '30000000-0000-0000-0000-000000000102', -- North Dairy Feed Corp
    '20000000-0000-0000-0000-000000000001', -- Maize
    '21000000-0000-0000-0000-000000000001', -- Grade A Milling
    75,
    '22000000-0000-0000-0000-000000000001', -- MT
    22600,
    'FOR Warehouse Baran Mandi',
    now() + interval '20 days',
    'Open',
    0,
    'global',
    '00000000-0000-0000-0000-0000000000a1',
    now() - interval '4 days'
  ),
  -- Req 03: Buyer 03, Wheat 50 MT (Matches Seller 03 Wheat 70 MT)
  (
    '60000000-0000-0000-0000-000000000103',
    '30000000-0000-0000-0000-000000000103', -- Golden Harvest Flour Mills
    '20000000-0000-0000-0000-000000000002', -- Sharbati Wheat
    '21000000-0000-0000-0000-000000000003', -- Premium Sharbati
    50,
    '22000000-0000-0000-0000-000000000001', -- MT
    28500,
    'Ex-Warehouse Jaipur Depot',
    now() + interval '10 days',
    'Open',
    0,
    'global',
    '00000000-0000-0000-0000-0000000000a1',
    now() - interval '3 days'
  ),
  -- Req 04: Buyer 04, Wheat 120 MT (Partial match only: Seller 03 has only 70 MT total)
  (
    '60000000-0000-0000-0000-000000000104',
    '30000000-0000-0000-0000-000000000104', -- Frontier Starch Processing
    '20000000-0000-0000-0000-000000000002', -- Wheat
    '21000000-0000-0000-0000-000000000003', -- Premium Sharbati
    120,
    '22000000-0000-0000-0000-000000000001', -- MT
    27500,
    'FOR Delivery Kota Plant',
    now() + interval '25 days',
    'Open',
    0,
    'global',
    '00000000-0000-0000-0000-0000000000a1',
    now() - interval '2 days'
  ),
  -- Req 05: Buyer 05, Soybean 100 MT (NO MATCH available in supply pool)
  (
    '60000000-0000-0000-0000-000000000105',
    '30000000-0000-0000-0000-000000000105', -- Malwa Solvent Extractions
    '20000000-0000-0000-0000-000000000003', -- Soybean Seed
    '21000000-0000-0000-0000-000000000004', -- Standard Mandi Grade
    100,
    '22000000-0000-0000-0000-000000000001', -- MT
    45000,
    'FOR Factory Ujjain',
    now() + interval '30 days',
    'Open',
    0,
    'global',
    '00000000-0000-0000-0000-0000000000a1',
    now() - interval '2 days'
  ),
  -- Req 06: Buyer 06, Maize 50 MT (Expired mandate)
  (
    '60000000-0000-0000-0000-000000000106',
    '30000000-0000-0000-0000-000000000106', -- Mewar Grains
    '20000000-0000-0000-0000-000000000001', -- Maize
    '21000000-0000-0000-0000-000000000002', -- Feed Grade Premium
    50,
    '22000000-0000-0000-0000-000000000001', -- MT
    21500,
    'Ex-Mandi Delivery',
    now() - interval '2 days',
    'Expired',
    0,
    'global',
    '00000000-0000-0000-0000-0000000000a1',
    now() - interval '30 days'
  )
ON CONFLICT (id) DO UPDATE SET
  status = EXCLUDED.status,
  quantity = EXCLUDED.quantity,
  target_price = EXCLUDED.target_price,
  fulfilled_quantity = EXCLUDED.fulfilled_quantity;

-- ----------------------------------------------------------------------------
-- 7. CONTROLLED ALLOCATIONS (Split Allocation Engine - Sprint 35)
-- ----------------------------------------------------------------------------
-- Buyer 01's 100 MT Maize requirement split into:
-- 1. 60 MT from Seller 01 (Offer 01)
-- 2. 40 MT from Seller 02 (Offer 02)
-- Total = 100 MT allocated (0 MT double-allocated)
INSERT INTO public.requirement_allocations (
  id, allocation_reference, requirement_id, availability_id, broker_id,
  allocated_quantity, unit_id, price_basis, allocated_price, status, notes, allocated_at, confirmed_at
)
VALUES
  (
    '70000000-0000-0000-0000-000000000001',
    'RBTEST-ALLOC-REQ01-SEL01',
    '60000000-0000-0000-0000-000000000101', -- Req 01
    '50000000-0000-0000-0000-000000000201', -- Offer 01 (Seller 01, 60 MT)
    '00000000-0000-0000-0000-0000000000a1',
    60,
    '22000000-0000-0000-0000-000000000001', -- MT
    'FOR_DESTINATION',
    22500.00,
    'CONFIRMED',
    'Split Lot 1: 60 MT allocated from Kota Agro Warehousing.',
    now() - interval '2 days',
    now() - interval '1 day'
  ),
  (
    '70000000-0000-0000-0000-000000000002',
    'RBTEST-ALLOC-REQ01-SEL02',
    '60000000-0000-0000-0000-000000000101', -- Req 01
    '50000000-0000-0000-0000-000000000202', -- Offer 02 (Seller 02, 80 MT total, 40 MT allocated)
    '00000000-0000-0000-0000-0000000000a1',
    40,
    '22000000-0000-0000-0000-000000000001', -- MT
    'FOR_DESTINATION',
    22700.00,
    'CONFIRMED',
    'Split Lot 2: 40 MT allocated from Hadoti Grain Producers (leaves 40 MT remaining available).',
    now() - interval '2 days',
    now() - interval '1 day'
  )
ON CONFLICT (id) DO UPDATE SET
  status = EXCLUDED.status,
  allocated_quantity = EXCLUDED.allocated_quantity,
  allocated_price = EXCLUDED.allocated_price;

-- ----------------------------------------------------------------------------
-- 8. QUOTATIONS (Required for Deals Foreign Key Constraint)
-- ----------------------------------------------------------------------------
INSERT INTO public.quotations (
  id, requirement_id, broker_id, seller_availability_id, offered_price, status, valid_until, created_at
)
VALUES
  ('80000000-0000-0000-0000-000000000001', '60000000-0000-0000-0000-000000000101', '00000000-0000-0000-0000-0000000000a1', '50000000-0000-0000-0000-000000000201', 22500, 'Accepted', now() + interval '10 days', now() - interval '4 days'),
  ('80000000-0000-0000-0000-000000000002', '60000000-0000-0000-0000-000000000101', '00000000-0000-0000-0000-0000000000a1', '50000000-0000-0000-0000-000000000202', 22700, 'Accepted', now() + interval '10 days', now() - interval '4 days'),
  ('80000000-0000-0000-0000-000000000003', '60000000-0000-0000-0000-000000000103', '00000000-0000-0000-0000-0000000000a1', '50000000-0000-0000-0000-000000000203', 28200, 'Sent', now() + interval '5 days', now() - interval '2 days'),
  ('80000000-0000-0000-0000-000000000004', '60000000-0000-0000-0000-000000000102', '00000000-0000-0000-0000-0000000000a1', '50000000-0000-0000-0000-000000000202', 22650, 'Sent', now() + interval '7 days', now() - interval '2 days'),
  ('80000000-0000-0000-0000-000000000005', '60000000-0000-0000-0000-000000000101', '00000000-0000-0000-0000-0000000000a1', '50000000-0000-0000-0000-000000000201', 22500, 'Accepted', now() + interval '20 days', now() - interval '15 days'),
  ('80000000-0000-0000-0000-000000000006', '60000000-0000-0000-0000-000000000101', '00000000-0000-0000-0000-0000000000a1', '50000000-0000-0000-0000-000000000201', 22500, 'Accepted', now() + interval '12 days', now() - interval '10 days'),
  ('80000000-0000-0000-0000-000000000007', '60000000-0000-0000-0000-000000000103', '00000000-0000-0000-0000-0000000000a1', '50000000-0000-0000-0000-000000000203', 28000, 'Accepted', now() - interval '5 days', now() - interval '20 days'),
  ('80000000-0000-0000-0000-000000000008', '60000000-0000-0000-0000-000000000102', '00000000-0000-0000-0000-0000000000a1', '50000000-0000-0000-0000-000000000201', 22000, 'Rejected', now() - interval '2 days', now() - interval '8 days'),
  ('80000000-0000-0000-0000-000000000009', '60000000-0000-0000-0000-000000000101', '00000000-0000-0000-0000-0000000000a1', '50000000-0000-0000-0000-000000000202', 22700, 'Accepted', now() + interval '5 days', now() - interval '14 days')
ON CONFLICT (id) DO NOTHING;

-- ----------------------------------------------------------------------------
-- 9. DEALS (Comprehensive Lifecycle States)
-- ----------------------------------------------------------------------------
INSERT INTO public.deals (
  id, requirement_id, quotation_id, buyer_id, seller_id, broker_id,
  agreed_price, agreed_quantity, status, created_at, closed_at
)
VALUES
  -- 1. Draft Deal
  ('90000000-0000-0000-0000-000000000001', '60000000-0000-0000-0000-000000000101', '80000000-0000-0000-0000-000000000001', '30000000-0000-0000-0000-000000000101', '30000000-0000-0000-0000-000000000201', '00000000-0000-0000-0000-0000000000a1', 22500, 60, 'Draft', now() - interval '1 hour', null),

  -- 2. Negotiation Deal
  ('90000000-0000-0000-0000-000000000002', '60000000-0000-0000-0000-000000000101', '80000000-0000-0000-0000-000000000002', '30000000-0000-0000-0000-000000000101', '30000000-0000-0000-0000-000000000202', '00000000-0000-0000-0000-0000000000a1', 22700, 40, 'Negotiation', now() - interval '6 hours', null),

  -- 3. Awaiting Buyer Confirmation
  ('90000000-0000-0000-0000-000000000003', '60000000-0000-0000-0000-000000000103', '80000000-0000-0000-0000-000000000003', '30000000-0000-0000-0000-000000000103', '30000000-0000-0000-0000-000000000203', '00000000-0000-0000-0000-0000000000a1', 28200, 50, 'Awaiting Buyer Confirmation', now() - interval '12 hours', null),

  -- 4. Awaiting Seller Confirmation
  ('90000000-0000-0000-0000-000000000004', '60000000-0000-0000-0000-000000000102', '80000000-0000-0000-0000-000000000004', '30000000-0000-0000-0000-000000000102', '30000000-0000-0000-0000-000000000202', '00000000-0000-0000-0000-0000000000a1', 22650, 40, 'Awaiting Seller Confirmation', now() - interval '18 hours', null),

  -- 5. Finalized Deal (Ready for Logistics)
  ('90000000-0000-0000-0000-000000000005', '60000000-0000-0000-0000-000000000101', '80000000-0000-0000-0000-000000000005', '30000000-0000-0000-0000-000000000101', '30000000-0000-0000-0000-000000000201', '00000000-0000-0000-0000-0000000000a1', 22500, 50, 'Finalized', now() - interval '2 days', null),

  -- 6. Deal In Fulfillment (Partial Delivery: 30 MT delivered, 30 MT in transit)
  ('90000000-0000-0000-0000-000000000006', '60000000-0000-0000-0000-000000000101', '80000000-0000-0000-0000-000000000006', '30000000-0000-0000-0000-000000000101', '30000000-0000-0000-0000-000000000201', '00000000-0000-0000-0000-0000000000a1', 22500, 60, 'Dispatch Pending', now() - interval '5 days', null),

  -- 7. Completed Deal (Fully Delivered, Settled & Closed)
  ('90000000-0000-0000-0000-000000000007', '60000000-0000-0000-0000-000000000103', '80000000-0000-0000-0000-000000000007', '30000000-0000-0000-0000-000000000103', '30000000-0000-0000-0000-000000000203', '00000000-0000-0000-0000-0000000000a1', 28000, 50, 'Completed', now() - interval '15 days', now() - interval '3 days'),

  -- 8. Cancelled Deal (Pricing Impasse)
  ('90000000-0000-0000-0000-000000000008', '60000000-0000-0000-0000-000000000102', '80000000-0000-0000-0000-000000000008', '30000000-0000-0000-0000-000000000102', '30000000-0000-0000-0000-000000000201', '00000000-0000-0000-0000-0000000000a1', 22000, 20, 'Cancelled', now() - interval '7 days', now() - interval '6 days'),

  -- 9. Disputed Deal (Quality Variance Reported)
  ('90000000-0000-0000-0000-000000000009', '60000000-0000-0000-0000-000000000101', '80000000-0000-0000-0000-000000000009', '30000000-0000-0000-0000-000000000101', '30000000-0000-0000-0000-000000000202', '00000000-0000-0000-0000-0000000000a1', 22700, 40, 'Disputed', now() - interval '10 days', null)
ON CONFLICT (id) DO UPDATE SET
  status = EXCLUDED.status,
  agreed_price = EXCLUDED.agreed_price,
  agreed_quantity = EXCLUDED.agreed_quantity,
  closed_at = EXCLUDED.closed_at;

-- ----------------------------------------------------------------------------
-- 10. DEAL VERSIONS & NEGOTIATION SNAPSHOTS (Append-Only / Immutable Rules)
-- ----------------------------------------------------------------------------
-- Note: deal_versions trigger prevents update/delete of snapshots once written.
-- We use WHERE NOT EXISTS to guarantee idempotent initial insertion without triggers erroring.
INSERT INTO public.deal_versions (id, request_id, version_number, actor_id, status, snapshot_payload, created_at)
SELECT
  v.id, v.request_id, v.version_number, v.actor_id, v.status, v.snapshot_payload::jsonb, v.created_at
FROM (VALUES
  ('a0000000-0000-0000-0000-000000000001'::uuid, '90000000-0000-0000-0000-000000000002'::uuid, 1, '00000000-0000-0000-0000-0000000000a1'::uuid, 'Proposed', '{"price": 22800, "quantity": 40, "deliveryTerms": "FOR Kota"}'::text, now() - interval '6 hours'),
  ('a0000000-0000-0000-0000-000000000002'::uuid, '90000000-0000-0000-0000-000000000002'::uuid, 2, '00000000-0000-0000-0000-000000000101'::uuid, 'Proposed', '{"price": 22700, "quantity": 40, "deliveryTerms": "FOR Kota"}'::text, now() - interval '5 hours'),
  ('a0000000-0000-0000-0000-000000000003'::uuid, '90000000-0000-0000-0000-000000000003'::uuid, 1, '00000000-0000-0000-0000-000000000203'::uuid, 'Seller Confirmed', '{"price": 28200, "quantity": 50, "deliveryTerms": "Ex-Jaipur"}'::text, now() - interval '12 hours'),
  ('a0000000-0000-0000-0000-000000000004'::uuid, '90000000-0000-0000-0000-000000000004'::uuid, 1, '00000000-0000-0000-0000-000000000102'::uuid, 'Buyer Confirmed', '{"price": 22650, "quantity": 40, "deliveryTerms": "FOR Baran"}'::text, now() - interval '18 hours'),
  ('a0000000-0000-0000-0000-000000000005'::uuid, '90000000-0000-0000-0000-000000000005'::uuid, 1, '00000000-0000-0000-0000-0000000000a1'::uuid, 'Confirmed', '{"price": 22500, "quantity": 50, "deliveryTerms": "FOR Kota"}'::text, now() - interval '2 days'),
  ('a0000000-0000-0000-0000-000000000007'::uuid, '90000000-0000-0000-0000-000000000007'::uuid, 1, '00000000-0000-0000-0000-0000000000a1'::uuid, 'Confirmed', '{"price": 28000, "quantity": 50, "deliveryTerms": "Ex-Jaipur"}'::text, now() - interval '15 days')
) AS v(id, request_id, version_number, actor_id, status, snapshot_payload, created_at)
WHERE NOT EXISTS (
  SELECT 1 FROM public.deal_versions WHERE public.deal_versions.id = v.id
);

-- ----------------------------------------------------------------------------
-- 11. BOOKINGS (Finalized Deal References)
-- ----------------------------------------------------------------------------
INSERT INTO public.bookings (id, booking_reference, deal_id, locked_version_id, status, created_at)
VALUES
  (
    'b0000000-0000-0000-0000-000000000005',
    'RBTEST-BKG-2026-0005',
    '90000000-0000-0000-0000-000000000005',
    'a0000000-0000-0000-0000-000000000005',
    'Confirmed',
    now() - interval '2 days'
  ),
  (
    'b0000000-0000-0000-0000-000000000007',
    'RBTEST-BKG-2026-0007',
    '90000000-0000-0000-0000-000000000007',
    'a0000000-0000-0000-0000-000000000007',
    'Confirmed',
    now() - interval '15 days'
  )
ON CONFLICT (booking_reference) DO NOTHING;

-- ----------------------------------------------------------------------------
-- 12. LOGISTICS & DISPATCHES (Delivery Tracking)
-- ----------------------------------------------------------------------------
INSERT INTO public.dispatches (
  id, deal_id, seller_id, vehicle_type_id, vehicle_number, driver_name, driver_mobile,
  dispatch_date, expected_delivery_date, status, created_at
)
VALUES
  -- Deal 06: In Fulfillment (Partial Delivery: Batch 1 Delivered 30 MT, Batch 2 Dispatched 30 MT)
  (
    'c0000000-0000-0000-0000-000000000061',
    '90000000-0000-0000-0000-000000000006',
    '00000000-0000-0000-0000-000000000201', -- Rajesh Patidar (Seller 01)
    '23000000-0000-0000-0000-000000000001', -- 32FT Truck
    'RJ-20-GA-1122',
    'Ram Singh',
    '+919876599001',
    now() - interval '3 days',
    now() - interval '2 days',
    'Delivered',
    now() - interval '3 days'
  ),
  (
    'c0000000-0000-0000-0000-000000000062',
    '90000000-0000-0000-0000-000000000006',
    '00000000-0000-0000-0000-000000000201', -- Rajesh Patidar (Seller 01)
    '23000000-0000-0000-0000-000000000001', -- 32FT Truck
    'RJ-20-GA-3344',
    'Shyam Lal',
    '+919876599002',
    now() - interval '1 day',
    now() + interval '1 day',
    'Dispatched',
    now() - interval '1 day'
  ),
  -- Deal 07: Completed Deal (Fully Delivered 50 MT)
  (
    'c0000000-0000-0000-0000-000000000071',
    '90000000-0000-0000-0000-000000000007',
    '00000000-0000-0000-0000-000000000203', -- Suresh Meena (Seller 03)
    '23000000-0000-0000-0000-000000000001', -- 32FT Truck
    'RJ-14-UB-8899',
    'Mohan Gurjar',
    '+919876599003',
    now() - interval '10 days',
    now() - interval '8 days',
    'Delivered',
    now() - interval '10 days'
  )
ON CONFLICT (id) DO UPDATE SET
  status = EXCLUDED.status,
  vehicle_number = EXCLUDED.vehicle_number;

-- ----------------------------------------------------------------------------
-- 13. COMMERCIAL DISPUTES
-- ----------------------------------------------------------------------------
INSERT INTO public.disputes (
  id, deal_id, filed_by, reason, description, resolution_notes, status, created_at
)
VALUES
  (
    'd0000000-0000-0000-0000-000000000009',
    '90000000-0000-0000-0000-000000000009',
    '00000000-0000-0000-0000-000000000101', -- Aman Sharma (Buyer 01)
    'Quality Variance - Moisture Limit Exceeded',
    'Independent laboratory testing revealed average moisture content of 16.2%, exceeding the agreed maximum specification of 13.0%. Buyer requested a ₹450/MT settlement discount or replacement batch.',
    'Broker mediation in progress. Awaiting joint inspection report from Kota Mandi testing facility.',
    'Open',
    now() - interval '8 days'
  )
ON CONFLICT (id) DO UPDATE SET
  reason = EXCLUDED.reason,
  status = EXCLUDED.status;

-- ----------------------------------------------------------------------------
-- 14. CRM TASKS & BROKER ACTION ITEMS
-- ----------------------------------------------------------------------------
INSERT INTO public.crm_tasks (
  id, broker_id, contact_id, title, due_date, priority, status, created_at
)
VALUES
  (
    'e0000000-0000-0000-0000-000000000001',
    '00000000-0000-0000-0000-0000000000a1',
    '40000000-0000-0000-0000-000000000101',
    'Follow up on Deal #09 dispute joint sampling with AgrInnovate QA team',
    now() + interval '1 day',
    'High',
    'Pending',
    now() - interval '2 days'
  ),
  (
    'e0000000-0000-0000-0000-000000000002',
    '00000000-0000-0000-0000-0000000000a1',
    '40000000-0000-0000-0000-000000000102',
    'Source remaining 35 MT Maize shortfall for North Dairy Feed mandate',
    now() + interval '2 days',
    'High',
    'Pending',
    now() - interval '1 day'
  ),
  (
    'e0000000-0000-0000-0000-000000000003',
    '00000000-0000-0000-0000-0000000000a1',
    '40000000-0000-0000-0000-000000000103',
    'Verify final delivery weighbridge slip on Completed Deal #07',
    now() - interval '1 day',
    'Medium',
    'Completed',
    now() - interval '4 days'
  )
ON CONFLICT (id) DO UPDATE SET
  title = EXCLUDED.title,
  due_date = EXCLUDED.due_date,
  priority = EXCLUDED.priority,
  status = EXCLUDED.status;

-- ----------------------------------------------------------------------------
-- 15. CRM ACTIVITIES (Chronological History Trail)
-- ----------------------------------------------------------------------------
INSERT INTO public.crm_activities (
  id, contact_id, type, notes, follow_up_date, created_at
)
VALUES
  (
    'f0000000-0000-0000-0000-000000000001',
    '40000000-0000-0000-0000-000000000101',
    'Call',
    'Mandate recorded: 100 MT Yellow Maize at target ₹23,000/MT for Kota flour mill processing.',
    now() + interval '3 days',
    now() - interval '6 days'
  ),
  (
    'f0000000-0000-0000-0000-000000000002',
    '40000000-0000-0000-0000-000000000101',
    'Note',
    'Executed split allocation: 60 MT via Kota Agro (Lot MZ-60) and 40 MT via Hadoti Grain (Lot MZ-80). Both allocations confirmed.',
    null,
    now() - interval '2 days'
  ),
  (
    'f0000000-0000-0000-0000-000000000003',
    '40000000-0000-0000-0000-000000000102',
    'Meeting',
    'Informed client of market tightness in Kota belt: only 40 MT available immediately - negotiating additional 35 MT from Baran mandi.',
    now() + interval '2 days',
    now() - interval '1 day'
  ),
  (
    'f0000000-0000-0000-0000-000000000004',
    '40000000-0000-0000-0000-000000000103',
    'Deal',
    'Finalized 50 MT Wheat deal at ₹28,000/MT with Shekhawati Wheat Traders. Full delivery completed and verified.',
    null,
    now() - interval '3 days'
  )
ON CONFLICT (id) DO NOTHING;

COMMIT;
