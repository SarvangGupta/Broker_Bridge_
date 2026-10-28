-- ==============================================================================
-- Migration: 0050_add_seller_bank_details_and_audit_history.sql
-- Application: RM Seller Mobile (Sprint RB-SELLER-PROFILE-INVOICE-01)
-- Description:
--   1. Adds bank detail columns to public.companies (strictly unverified by default).
--   2. Creates public.seller_profile_audit_logs for administrator-visible history.
--   3. Enforces strict Row Level Security (RLS):
--      - Audit history read access is restricted exclusively to 'admin' role.
--      - Audit records are immutable (no UPDATE, no DELETE).
--      - Sellers can only insert audit logs matching their own auth.uid().
--   4. Creates private storage bucket 'brokerbridge_seller_invoices'.
-- ==============================================================================

-- 1. Bank Details on public.companies
ALTER TABLE public.companies
ADD COLUMN IF NOT EXISTS bank_holder_name TEXT,
ADD COLUMN IF NOT EXISTS bank_name TEXT,
ADD COLUMN IF NOT EXISTS bank_account_number TEXT,
ADD COLUMN IF NOT EXISTS bank_ifsc TEXT,
ADD COLUMN IF NOT EXISTS bank_branch TEXT,
ADD COLUMN IF NOT EXISTS bank_is_verified BOOLEAN NOT NULL DEFAULT false,
ADD COLUMN IF NOT EXISTS bank_verification_status TEXT NOT NULL DEFAULT 'unverified';

CREATE INDEX IF NOT EXISTS idx_companies_bank_verification_status
ON public.companies(bank_verification_status);

-- 2. Seller Profile Audit Log Table
CREATE TABLE IF NOT EXISTS public.seller_profile_audit_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    seller_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    company_id UUID REFERENCES public.companies(id) ON DELETE SET NULL,
    actor_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    operation_type TEXT NOT NULL DEFAULT 'MANUAL_EDIT', -- 'MANUAL_EDIT' or 'INVOICE_ASSISTED_EDIT'
    changed_fields TEXT[] NOT NULL DEFAULT '{}',
    change_summary TEXT NOT NULL,
    source TEXT NOT NULL DEFAULT 'rmseller_mobile',
    request_id TEXT,
    document_url TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Indices for rapid administrative lookup
CREATE INDEX IF NOT EXISTS idx_profile_audit_seller_id 
ON public.seller_profile_audit_logs(seller_id);

CREATE INDEX IF NOT EXISTS idx_profile_audit_company_id 
ON public.seller_profile_audit_logs(company_id);

CREATE INDEX IF NOT EXISTS idx_profile_audit_created_at 
ON public.seller_profile_audit_logs(created_at DESC);

-- 3. Row-Level Security on seller_profile_audit_logs
ALTER TABLE public.seller_profile_audit_logs ENABLE ROW LEVEL SECURITY;

-- 3.1 Admins have SELECT access to inspect profile modification history
DROP POLICY IF EXISTS "Admins can view profile audit logs" ON public.seller_profile_audit_logs;
CREATE POLICY "Admins can view profile audit logs"
ON public.seller_profile_audit_logs
FOR SELECT
TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM public.users
        WHERE public.users.id = auth.uid()
        AND public.users.role = 'admin'
    )
);

-- 3.2 Authenticated sellers can INSERT their own audit records upon profile update
DROP POLICY IF EXISTS "Sellers can append own profile audit logs" ON public.seller_profile_audit_logs;
CREATE POLICY "Sellers can append own profile audit logs"
ON public.seller_profile_audit_logs
FOR INSERT
TO authenticated
WITH CHECK (
    auth.uid() IS NOT NULL
    AND actor_id = auth.uid()
    AND seller_id = auth.uid()
);

-- Note: UPDATE and DELETE policies are deliberately omitted to guarantee immutability.

-- 4. Private Storage Bucket for Seller Invoices
INSERT INTO storage.buckets (id, name, public)
VALUES ('brokerbridge_seller_invoices', 'brokerbridge_seller_invoices', false)
ON CONFLICT (id) DO NOTHING;

-- 4.1 Storage Policy: Upload to private seller invoices bucket
DROP POLICY IF EXISTS "Allow sellers to upload profile invoices" ON storage.objects;
CREATE POLICY "Allow sellers to upload profile invoices"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (
    bucket_id = 'brokerbridge_seller_invoices'
    AND auth.uid() IS NOT NULL
);

-- 4.2 Storage Policy: Scoped SELECT for owners and admins
DROP POLICY IF EXISTS "Allow authorized users to view profile invoices" ON storage.objects;
CREATE POLICY "Allow authorized users to view profile invoices"
ON storage.objects FOR SELECT
TO authenticated
USING (
    bucket_id = 'brokerbridge_seller_invoices'
    AND (
        -- Admin authorization
        EXISTS (
            SELECT 1 FROM public.users
            WHERE public.users.id = auth.uid()
            AND public.users.role = 'admin'
        )
        OR
        -- Seller owner authorization (matching company_id in storage path)
        EXISTS (
            SELECT 1 FROM public.users
            WHERE public.users.id = auth.uid()
            AND (regexp_split_to_array(storage.objects.name, '/'))[2] = public.users.company_id::text
        )
    )
);
