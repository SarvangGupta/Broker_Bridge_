-- ==============================================================================
-- Migration: 0051_add_seller_commodity_expertise.sql
-- Application: RM Seller Mobile (Sprint RB-SELLER-PROFILE-INVOICE-01 ADDENDUM)
-- Description:
--   1. Adds commodity_expertise JSONB column to public.companies for enterprise/firm sellers.
--   2. Creates public.seller_commodity_expertise table for individual and firm sellers
--      to store verified and seller-suggested custom commodity expertise entries.
--   3. Enforces strict Row Level Security (RLS):
--      - Sellers can only read and manage their own expertise records.
--      - Unapproved (custom) commodities are visible only to the owning seller and admins.
--      - Platform-wide master_commodities table is strictly unmodified.
-- ==============================================================================

-- 1. Add commodity_expertise JSONB column to public.companies
ALTER TABLE public.companies
ADD COLUMN IF NOT EXISTS commodity_expertise JSONB NOT NULL DEFAULT '[]'::jsonb;

-- 2. Create seller_commodity_expertise table
CREATE TABLE IF NOT EXISTS public.seller_commodity_expertise (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    seller_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    company_id UUID REFERENCES public.companies(id) ON DELETE SET NULL,
    commodity_id UUID REFERENCES public.master_commodities(id) ON DELETE SET NULL,
    commodity_name TEXT NOT NULL,
    commodity_code TEXT,
    category_name TEXT,
    is_approved BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT uq_seller_commodity_normalized UNIQUE (seller_id, commodity_name)
);

-- Indices for rapid lookup by seller and posting priority
CREATE INDEX IF NOT EXISTS idx_seller_expertise_seller_id 
ON public.seller_commodity_expertise(seller_id);

CREATE INDEX IF NOT EXISTS idx_seller_expertise_company_id 
ON public.seller_commodity_expertise(company_id);

CREATE INDEX IF NOT EXISTS idx_seller_expertise_commodity_id 
ON public.seller_commodity_expertise(commodity_id);

-- 3. Row-Level Security
ALTER TABLE public.seller_commodity_expertise ENABLE ROW LEVEL SECURITY;

-- 3.1 Sellers can read their own expertise
DROP POLICY IF EXISTS "Sellers can view own commodity expertise" ON public.seller_commodity_expertise;
CREATE POLICY "Sellers can view own commodity expertise"
ON public.seller_commodity_expertise
FOR SELECT
TO authenticated
USING (
    seller_id = auth.uid()
    OR EXISTS (
        SELECT 1 FROM public.users
        WHERE id = auth.uid() AND role = 'admin'
    )
);

-- 3.2 Sellers can insert expertise for their own identity
DROP POLICY IF EXISTS "Sellers can insert own commodity expertise" ON public.seller_commodity_expertise;
CREATE POLICY "Sellers can insert own commodity expertise"
ON public.seller_commodity_expertise
FOR INSERT
TO authenticated
WITH CHECK (
    seller_id = auth.uid()
);

-- 3.3 Sellers can update their own expertise
DROP POLICY IF EXISTS "Sellers can update own commodity expertise" ON public.seller_commodity_expertise;
CREATE POLICY "Sellers can update own commodity expertise"
ON public.seller_commodity_expertise
FOR UPDATE
TO authenticated
USING (
    seller_id = auth.uid()
    OR EXISTS (
        SELECT 1 FROM public.users
        WHERE id = auth.uid() AND role = 'admin'
    )
)
WITH CHECK (
    seller_id = auth.uid()
    OR EXISTS (
        SELECT 1 FROM public.users
        WHERE id = auth.uid() AND role = 'admin'
    )
);

-- 3.4 Sellers can delete their own expertise
DROP POLICY IF EXISTS "Sellers can delete own commodity expertise" ON public.seller_commodity_expertise;
CREATE POLICY "Sellers can delete own commodity expertise"
ON public.seller_commodity_expertise
FOR DELETE
TO authenticated
USING (
    seller_id = auth.uid()
    OR EXISTS (
        SELECT 1 FROM public.users
        WHERE id = auth.uid() AND role = 'admin'
    )
);
