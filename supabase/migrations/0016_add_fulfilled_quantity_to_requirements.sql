-- Migration: 0016_add_fulfilled_quantity_to_requirements.sql
-- Adds fulfilled_quantity column to requirements table for Partial Fulfillment math

ALTER TABLE public.requirements 
ADD COLUMN IF NOT EXISTS fulfilled_quantity DOUBLE PRECISION NOT NULL DEFAULT 0;
