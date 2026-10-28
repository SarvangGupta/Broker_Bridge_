-- ==============================================================================
-- Rollback Migration: rollback_0050.sql
-- Application: RM Seller Mobile (Sprint RB-SELLER-PROFILE-INVOICE-01)
-- Description:
--   Rolls back migration 0050:
--   1. Drops storage policies and bucket 'brokerbridge_seller_invoices'.
--   2. Drops RLS policies and table public.seller_profile_audit_logs.
--   3. Drops bank columns added to public.companies.
-- ==============================================================================

-- 1. Storage Policies & Bucket Rollback
DROP POLICY IF EXISTS "Allow authorized users to view profile invoices" ON storage.objects;
DROP POLICY IF EXISTS "Allow sellers to upload profile invoices" ON storage.objects;
DELETE FROM storage.buckets WHERE id = 'brokerbridge_seller_invoices';

-- 2. Audit Table & RLS Rollback
DROP POLICY IF EXISTS "Sellers can append own profile audit logs" ON public.seller_profile_audit_logs;
DROP POLICY IF EXISTS "Admins can view profile audit logs" ON public.seller_profile_audit_logs;
DROP TABLE IF EXISTS public.seller_profile_audit_logs;

-- 3. Company Bank Details Rollback
DROP INDEX IF EXISTS public.idx_companies_bank_verification_status;

ALTER TABLE public.companies
DROP COLUMN IF EXISTS bank_verification_status,
DROP COLUMN IF EXISTS bank_is_verified,
DROP COLUMN IF EXISTS bank_branch,
DROP COLUMN IF EXISTS bank_ifsc,
DROP COLUMN IF EXISTS bank_account_number,
DROP COLUMN IF EXISTS bank_name,
DROP COLUMN IF EXISTS bank_holder_name;
