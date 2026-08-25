-- Migration: 0015_add_company_trust_scores.sql
-- Adds is_verified and trust_score columns to companies table for B2B Trust Layer

ALTER TABLE public.companies 
ADD COLUMN IF NOT EXISTS is_verified BOOLEAN NOT NULL DEFAULT false,
ADD COLUMN IF NOT EXISTS trust_score INTEGER NOT NULL DEFAULT 100;

CREATE INDEX IF NOT EXISTS idx_companies_is_verified ON public.companies(is_verified);
CREATE INDEX IF NOT EXISTS idx_companies_trust_score ON public.companies(trust_score);
