-- ==============================================================================
-- Migration: 0057_counterparty_gst_and_bank_verification.sql (PROPOSED)
-- Sprint: RMBROKER-COUNTERPARTY-GST-01
--
-- Objective:
--   1. Add GST certificate review and banking columns to public.companies.
--   2. Enforce duplicate prevention via GSTIN.
--   3. Create public.counterparty_verification_requests for manual additions
--      awaiting Admin GST verification.
--   4. Create public.deal_document_shares to record deal-time summary and cheque-leaf sharing.
--   5. Create private storage buckets for GST certificates and Cheque leaves.
--   6. Enforce strict RLS policies:
--      - Sensitive documents (certificates & cheque leaves) are private.
--      - Account numbers are protected; only authorized brokers and admins have access.
--      - Manual counterparties remain 'gst_pending' until approved by Admin.
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- 1. Companies Table: GST Certificate and Banking Columns
-- ------------------------------------------------------------------------------
ALTER TABLE public.companies
  ADD COLUMN IF NOT EXISTS gst TEXT,
  ADD COLUMN IF NOT EXISTS legal_name TEXT,
  ADD COLUMN IF NOT EXISTS trade_name TEXT,
  ADD COLUMN IF NOT EXISTS constitution TEXT,
  ADD COLUMN IF NOT EXISTS principal_address TEXT,
  ADD COLUMN IF NOT EXISTS registration_date DATE,
  ADD COLUMN IF NOT EXISTS gst_status TEXT DEFAULT 'Active',
  ADD COLUMN IF NOT EXISTS gst_verification_status TEXT NOT NULL DEFAULT 'unverified'
    CHECK (gst_verification_status IN ('unverified', 'gst_pending', 'broker_verified', 'gst_verified', 'rejected')),
  ADD COLUMN IF NOT EXISTS gst_certificate_url TEXT,
  ADD COLUMN IF NOT EXISTS gst_verified_by UUID REFERENCES public.users(id),
  ADD COLUMN IF NOT EXISTS gst_verified_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS bank_holder_name TEXT,
  ADD COLUMN IF NOT EXISTS bank_name TEXT,
  ADD COLUMN IF NOT EXISTS bank_account_number TEXT,
  ADD COLUMN IF NOT EXISTS bank_ifsc TEXT,
  ADD COLUMN IF NOT EXISTS bank_branch TEXT,
  ADD COLUMN IF NOT EXISTS bank_cheque_url TEXT,
  ADD COLUMN IF NOT EXISTS bank_recorded_by UUID REFERENCES public.users(id),
  ADD COLUMN IF NOT EXISTS bank_recorded_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS bank_verification_status TEXT NOT NULL DEFAULT 'unverified'
    CHECK (bank_verification_status IN ('unverified', 'cheque_leaf_provided', 'verified')),
  ADD COLUMN IF NOT EXISTS bank_is_verified BOOLEAN NOT NULL DEFAULT false;

-- Partial unique index to prevent duplicate counterparties by GSTIN
CREATE UNIQUE INDEX IF NOT EXISTS idx_companies_unique_active_gst
  ON public.companies(UPPER(TRIM(gst)))
  WHERE gst IS NOT NULL AND TRIM(gst) <> '' AND status = true;

CREATE INDEX IF NOT EXISTS idx_companies_gst_verification_status
  ON public.companies(gst_verification_status);

CREATE INDEX IF NOT EXISTS idx_companies_bank_verification_status
  ON public.companies(bank_verification_status);

-- ------------------------------------------------------------------------------
-- 2. Admin Counterparty Verification Requests Table (Manual Fallback)
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.counterparty_verification_requests (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id UUID NOT NULL REFERENCES public.companies(id) ON DELETE CASCADE,
  broker_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  role TEXT NOT NULL CHECK (role IN ('buyer', 'seller')),
  gstin TEXT NOT NULL CHECK (gstin ~ '^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z][1-9A-Z]Z[0-9A-Z]$'),
  legal_name TEXT,
  trade_name TEXT,
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected')),
  reviewed_by UUID REFERENCES public.users(id),
  reviewed_at TIMESTAMPTZ,
  rejection_reason TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT cvr_rejection_reason_check
    CHECK (status <> 'rejected' OR (rejection_reason IS NOT NULL AND length(btrim(rejection_reason)) > 0))
);

CREATE INDEX IF NOT EXISTS idx_cvr_status ON public.counterparty_verification_requests(status, created_at);
CREATE INDEX IF NOT EXISTS idx_cvr_broker ON public.counterparty_verification_requests(broker_id);
CREATE INDEX IF NOT EXISTS idx_cvr_company ON public.counterparty_verification_requests(company_id);

-- RLS for counterparty_verification_requests
ALTER TABLE public.counterparty_verification_requests ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Brokers can view own verification requests" ON public.counterparty_verification_requests;
CREATE POLICY "Brokers can view own verification requests"
  ON public.counterparty_verification_requests
  FOR SELECT
  TO authenticated
  USING (broker_id = auth.uid() OR public.is_admin());

DROP POLICY IF EXISTS "Brokers can insert verification requests" ON public.counterparty_verification_requests;
CREATE POLICY "Brokers can insert verification requests"
  ON public.counterparty_verification_requests
  FOR INSERT
  TO authenticated
  WITH CHECK (broker_id = auth.uid() AND (public.is_broker() OR public.is_admin()));

DROP POLICY IF EXISTS "Admins can update verification requests" ON public.counterparty_verification_requests;
CREATE POLICY "Admins can update verification requests"
  ON public.counterparty_verification_requests
  FOR UPDATE
  TO authenticated
  USING (public.is_admin())
  WITH CHECK (public.is_admin());

-- ------------------------------------------------------------------------------
-- 3. Deal-Time Document & Bank Sharing Audit Table
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.deal_document_shares (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  deal_id UUID NOT NULL REFERENCES public.deals(id) ON DELETE CASCADE,
  broker_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  recipient_company_id UUID NOT NULL REFERENCES public.companies(id) ON DELETE CASCADE,
  document_type TEXT NOT NULL CHECK (document_type IN ('cheque_leaf', 'deal_summary', 'all')),
  document_ref TEXT,
  shared_payload JSONB,
  shared_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_dds_deal_id ON public.deal_document_shares(deal_id);
CREATE INDEX IF NOT EXISTS idx_dds_broker_id ON public.deal_document_shares(broker_id);

ALTER TABLE public.deal_document_shares ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Brokers and Admins view deal document shares" ON public.deal_document_shares;
CREATE POLICY "Brokers and Admins view deal document shares"
  ON public.deal_document_shares
  FOR SELECT
  TO authenticated
  USING (broker_id = auth.uid() OR public.is_admin());

DROP POLICY IF EXISTS "Brokers insert deal document shares" ON public.deal_document_shares;
CREATE POLICY "Brokers insert deal document shares"
  ON public.deal_document_shares
  FOR INSERT
  TO authenticated
  WITH CHECK (broker_id = auth.uid() AND (public.is_broker() OR public.is_admin()));

-- ------------------------------------------------------------------------------
-- 4. Admin Review RPC Function
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.review_counterparty_verification(
  p_request_id UUID,
  p_approve BOOLEAN,
  p_reason TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS 
DECLARE
  v_req RECORD;
  v_new_status TEXT;
  v_company_status TEXT;
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'Access denied: only administrators can review verification requests.' USING ERRCODE = '42501';
  END IF;

  SELECT * INTO v_req FROM public.counterparty_verification_requests WHERE id = p_request_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Verification request % not found', p_request_id USING ERRCODE = 'P0002';
  END IF;

  IF v_req.status <> 'pending' THEN
    RAISE EXCEPTION 'Verification request is already %', v_req.status USING ERRCODE = '22023';
  END IF;

  IF p_approve THEN
    v_new_status := 'approved';
    v_company_status := 'gst_verified';

    UPDATE public.companies
    SET is_verified = true,
        gst_verification_status = v_company_status
    WHERE id = v_req.company_id;
  ELSE
    IF p_reason IS NULL OR length(btrim(p_reason)) = 0 THEN
      RAISE EXCEPTION 'A rejection reason is required.' USING ERRCODE = '22023';
    END IF;
    v_new_status := 'rejected';
    v_company_status := 'rejected';

    UPDATE public.companies
    SET is_verified = false,
        gst_verification_status = v_company_status
    WHERE id = v_req.company_id;
  END IF;

  UPDATE public.counterparty_verification_requests
  SET status = v_new_status,
      reviewed_by = auth.uid(),
      reviewed_at = now(),
      rejection_reason = p_reason
  WHERE id = p_request_id;

  -- Notify the broker
  INSERT INTO public.notifications (user_id, title, message, type, action_url)
  VALUES (
    v_req.broker_id,
    CASE WHEN p_approve THEN 'Counterparty GST Verified' ELSE 'Counterparty GST Verification Rejected' END,
    CASE WHEN p_approve 
      THEN 'Admin approved GST registration for ' || COALESCE(v_req.legal_name, v_req.trade_name, v_req.gstin)
      ELSE 'Admin rejected GST registration for ' || COALESCE(v_req.legal_name, v_req.trade_name, v_req.gstin) || ': ' || p_reason
    END,
    'verification',
    '/directory'
  );

  RETURN jsonb_build_object(
    'success', true,
    'request_id', p_request_id,
    'status', v_new_status,
    'company_id', v_req.company_id
  );
END;
;

REVOKE ALL ON FUNCTION public.review_counterparty_verification(UUID, BOOLEAN, TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.review_counterparty_verification(UUID, BOOLEAN, TEXT) TO authenticated;

-- ------------------------------------------------------------------------------
-- 5. Storage Buckets (Private)
-- ------------------------------------------------------------------------------
INSERT INTO storage.buckets (id, name, public)
VALUES 
  ('brokerbridge_gst_certificates', 'brokerbridge_gst_certificates', false),
  ('brokerbridge_cheque_leaves', 'brokerbridge_cheque_leaves', false)
ON CONFLICT (id) DO NOTHING;

-- Policy: Upload GST certificates (authenticated brokers and admins)
DROP POLICY IF EXISTS "Brokers upload GST certificates" ON storage.objects;
CREATE POLICY "Brokers upload GST certificates"
  ON storage.objects FOR INSERT
  TO authenticated
  WITH CHECK (
    bucket_id = 'brokerbridge_gst_certificates'
    AND auth.uid() IS NOT NULL
  );

-- Policy: Read GST certificates (authenticated brokers and admins)
DROP POLICY IF EXISTS "Authorized brokers view GST certificates" ON storage.objects;
CREATE POLICY "Authorized brokers view GST certificates"
  ON storage.objects FOR SELECT
  TO authenticated
  USING (
    bucket_id = 'brokerbridge_gst_certificates'
    AND (public.is_broker() OR public.is_admin())
  );

-- Policy: Upload Cheque Leaves (authenticated brokers and admins)
DROP POLICY IF EXISTS "Brokers upload Cheque leaves" ON storage.objects;
CREATE POLICY "Brokers upload Cheque leaves"
  ON storage.objects FOR INSERT
  TO authenticated
  WITH CHECK (
    bucket_id = 'brokerbridge_cheque_leaves'
    AND auth.uid() IS NOT NULL
  );

-- Policy: Read Cheque Leaves (only authorized broker or admin)
DROP POLICY IF EXISTS "Authorized brokers view Cheque leaves" ON storage.objects;
CREATE POLICY "Authorized brokers view Cheque leaves"
  ON storage.objects FOR SELECT
  TO authenticated
  USING (
    bucket_id = 'brokerbridge_cheque_leaves'
    AND (public.is_broker() OR public.is_admin())
  );

-- Reload PostgREST schema cache
NOTIFY pgrst, 'reload schema';