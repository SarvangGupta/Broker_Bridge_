-- ============================================================================
-- Rollback Migration: rollback_0058.sql
-- Description: Drops counterparty_gst_filing_snapshots table and associated policies.
-- ============================================================================

DROP TABLE IF EXISTS public.counterparty_gst_filing_snapshots CASCADE;

