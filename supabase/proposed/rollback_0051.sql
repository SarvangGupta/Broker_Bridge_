-- ==============================================================================
-- Rollback Migration: rollback_0051.sql
-- Application: RM Seller Mobile (Sprint RB-SELLER-PROFILE-INVOICE-01 ADDENDUM)
-- ==============================================================================

DROP TABLE IF EXISTS public.seller_commodity_expertise CASCADE;

ALTER TABLE public.companies
DROP COLUMN IF EXISTS commodity_expertise;
