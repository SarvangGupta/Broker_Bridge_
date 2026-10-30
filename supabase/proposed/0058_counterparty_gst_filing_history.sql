-- ============================================================================
-- Migration: 0058_counterparty_gst_filing_history.sql
-- Description: Adds counterparty_gst_filing_snapshots table for caching and
--              auditing public GST return filing history and credibility data.
-- ============================================================================

-- Create counterparty_gst_filing_snapshots table
CREATE TABLE IF NOT EXISTS public.counterparty_gst_filing_snapshots (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID REFERENCES public.companies(id) ON DELETE CASCADE,
    broker_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    gstin VARCHAR(15) NOT NULL,
    snapshot_payload JSONB NOT NULL,
    data_source VARCHAR(120) NOT NULL,
    historical_coverage VARCHAR(120),
    total_filed INT DEFAULT 0,
    total_overdue INT DEFAULT 0,
    registration_status VARCHAR(50) DEFAULT 'Active',
    retrieved_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Indexes for efficient lookup and cache checks
CREATE INDEX IF NOT EXISTS idx_gst_filing_snapshots_gstin 
    ON public.counterparty_gst_filing_snapshots(gstin);

CREATE INDEX IF NOT EXISTS idx_gst_filing_snapshots_company 
    ON public.counterparty_gst_filing_snapshots(company_id);

CREATE INDEX IF NOT EXISTS idx_gst_filing_snapshots_broker 
    ON public.counterparty_gst_filing_snapshots(broker_id);

CREATE INDEX IF NOT EXISTS idx_gst_filing_snapshots_retrieved 
    ON public.counterparty_gst_filing_snapshots(retrieved_at DESC);

-- Enable Row Level Security (RLS)
ALTER TABLE public.counterparty_gst_filing_snapshots ENABLE ROW LEVEL SECURITY;

-- Broker Isolation Policy: A broker can only select filing snapshots they requested
-- or those associated with companies they manage.
CREATE POLICY "Brokers read own counterparty filing snapshots"
    ON public.counterparty_gst_filing_snapshots
    FOR SELECT
    TO authenticated
    USING (
        broker_id = auth.uid()
        OR company_id IN (
            SELECT id FROM public.companies WHERE broker_id = auth.uid()
        )
        OR EXISTS (
            SELECT 1 FROM public.users
            WHERE users.id = auth.uid() AND users.role = 'admin'
        )
    );

-- Brokers can insert snapshots for their counterparties
CREATE POLICY "Brokers insert own counterparty filing snapshots"
    ON public.counterparty_gst_filing_snapshots
    FOR INSERT
    TO authenticated
    WITH CHECK (
        broker_id = auth.uid()
        OR EXISTS (
            SELECT 1 FROM public.users
            WHERE users.id = auth.uid() AND users.role = 'admin'
        )
    );

-- Audit comments
COMMENT ON TABLE public.counterparty_gst_filing_snapshots IS 
    'Stores fetched public GST return filing history snapshots for counterparty credibility reviews.';
COMMENT ON COLUMN public.counterparty_gst_filing_snapshots.snapshot_payload IS 
    'Normalized JSON payload containing historical GSTR-1, GSTR-3B filings, dates, and taxpayer status.';

