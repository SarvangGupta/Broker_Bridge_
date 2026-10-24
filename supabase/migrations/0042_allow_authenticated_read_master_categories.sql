-- Migration: 0042_allow_authenticated_read_master_categories.sql
-- RB-PRODUCT-MASTER-07 (owner-approved 2026-10-24, decision D11: authenticated only).
-- Lets RMBuyer, RMSeller and RMBroker show each product's authoritative category label.
-- Read-only: category names are non-sensitive reference data. anon stays without access;
-- no INSERT/UPDATE/DELETE is granted, so only the catalogue owner can change categories.

GRANT SELECT ON TABLE public.master_categories TO authenticated;

DROP POLICY IF EXISTS "master_categories_read" ON public.master_categories;
CREATE POLICY "master_categories_read" ON public.master_categories FOR SELECT TO authenticated USING (true);
