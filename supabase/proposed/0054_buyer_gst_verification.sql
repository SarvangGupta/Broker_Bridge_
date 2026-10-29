-- ============================================================================
-- Migration: 0054_buyer_gst_verification.sql   (PROPOSED — not applied)
-- Sprint: RMBUYER-GST-BACKEND-01. Depends on 0053.
--
-- Secure Buyer GST verification:
--   * buyer_gst_verifications            one row per submission (status lifecycle)
--   * buyer_gst_verification_events      append-only history
--   * submit_buyer_gst_verification()    Buyer → pending only (SECURITY DEFINER)
--   * review_buyer_gst_verification()    Admin approve/reject (SECURITY DEFINER)
--   * guards on public.companies         is_verified for a Buyer company needs an approved
--                                        GST review; gst locked while pending/approved
--   * private bucket brokerbridge_buyer_gst_certificates (JPG/PNG, 5 MB, owner folder)
--
-- Clients get SELECT only (own company, or admin). Every write goes through the RPCs.
-- Legacy companies.is_verified values are left untouched; no history is fabricated.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- 1. Pure validation helpers (same rules as the app's GstinRules)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.gstin_is_valid(p_gstin text)
RETURNS boolean
LANGUAGE plpgsql
IMMUTABLE
SET search_path = ''
AS $$
DECLARE
  chars constant text := '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ';
  s int := 0;
  p int;
BEGIN
  IF p_gstin IS NULL OR p_gstin !~ '^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z][1-9A-Z]Z[0-9A-Z]$' THEN
    RETURN false;
  END IF;
  FOR i IN 1..14 LOOP
    p := (strpos(chars, substr(p_gstin, i, 1)) - 1) * (CASE WHEN i % 2 = 1 THEN 1 ELSE 2 END);
    s := s + p / 36 + p % 36;
  END LOOP;
  RETURN substr(chars, ((36 - s % 36) % 36) + 1, 1) = substr(p_gstin, 15, 1);
END;
$$;

CREATE OR REPLACE FUNCTION public.gst_state_name(p_code text)
RETURNS text
LANGUAGE sql
IMMUTABLE
SET search_path = ''
AS $$
  SELECT CASE p_code
    WHEN '01' THEN 'Jammu and Kashmir' WHEN '02' THEN 'Himachal Pradesh' WHEN '03' THEN 'Punjab'
    WHEN '04' THEN 'Chandigarh' WHEN '05' THEN 'Uttarakhand' WHEN '06' THEN 'Haryana'
    WHEN '07' THEN 'Delhi' WHEN '08' THEN 'Rajasthan' WHEN '09' THEN 'Uttar Pradesh'
    WHEN '10' THEN 'Bihar' WHEN '11' THEN 'Sikkim' WHEN '12' THEN 'Arunachal Pradesh'
    WHEN '13' THEN 'Nagaland' WHEN '14' THEN 'Manipur' WHEN '15' THEN 'Mizoram'
    WHEN '16' THEN 'Tripura' WHEN '17' THEN 'Meghalaya' WHEN '18' THEN 'Assam'
    WHEN '19' THEN 'West Bengal' WHEN '20' THEN 'Jharkhand' WHEN '21' THEN 'Odisha'
    WHEN '22' THEN 'Chhattisgarh' WHEN '23' THEN 'Madhya Pradesh' WHEN '24' THEN 'Gujarat'
    WHEN '25' THEN 'Daman and Diu' WHEN '26' THEN 'Dadra and Nagar Haveli and Daman and Diu'
    WHEN '27' THEN 'Maharashtra' WHEN '29' THEN 'Karnataka' WHEN '30' THEN 'Goa'
    WHEN '31' THEN 'Lakshadweep' WHEN '32' THEN 'Kerala' WHEN '33' THEN 'Tamil Nadu'
    WHEN '34' THEN 'Puducherry' WHEN '35' THEN 'Andaman and Nicobar Islands' WHEN '36' THEN 'Telangana'
    WHEN '37' THEN 'Andhra Pradesh' WHEN '38' THEN 'Ladakh' WHEN '97' THEN 'Other Territory'
  END
$$;

-- True when the address names the GSTIN's state, or names no known state at all.
CREATE OR REPLACE FUNCTION public.gst_address_state_consistent(p_address text, p_state text)
RETURNS boolean
LANGUAGE sql
IMMUTABLE
SET search_path = ''
AS $$
  SELECT p_address ~* ('\m' || p_state || '\M')
      OR NOT EXISTS (
           SELECT 1 FROM unnest(ARRAY[
             'Jammu and Kashmir','Himachal Pradesh','Punjab','Chandigarh','Uttarakhand','Haryana','Delhi',
             'Rajasthan','Uttar Pradesh','Bihar','Sikkim','Arunachal Pradesh','Nagaland','Manipur','Mizoram',
             'Tripura','Meghalaya','Assam','West Bengal','Jharkhand','Odisha','Chhattisgarh','Madhya Pradesh',
             'Gujarat','Daman and Diu','Dadra and Nagar Haveli and Daman and Diu','Maharashtra','Karnataka','Goa',
             'Lakshadweep','Kerala','Tamil Nadu','Puducherry','Andaman and Nicobar Islands','Telangana',
             'Andhra Pradesh','Ladakh']) AS s(name)
           WHERE p_address ~* ('\m' || s.name || '\M'))
$$;

-- dd/mm/yyyy → date; null/empty → null; anything else is rejected (never guessed).
CREATE OR REPLACE FUNCTION public.gst_parse_date(p_value text)
RETURNS date
LANGUAGE plpgsql
IMMUTABLE
SET search_path = ''
AS $$
DECLARE
  d date;
BEGIN
  IF p_value IS NULL OR btrim(p_value) = '' THEN
    RETURN NULL;
  END IF;
  IF btrim(p_value) !~ '^\d{2}/\d{2}/\d{4}$' THEN
    RAISE EXCEPTION 'invalid date: %', p_value USING ERRCODE = '22023';
  END IF;
  d := to_date(btrim(p_value), 'DD/MM/YYYY');
  IF to_char(d, 'DD/MM/YYYY') <> btrim(p_value) THEN
    RAISE EXCEPTION 'invalid date: %', p_value USING ERRCODE = '22023';
  END IF;
  RETURN d;
END;
$$;

REVOKE ALL ON FUNCTION public.gstin_is_valid(text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.gst_state_name(text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.gst_address_state_consistent(text, text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.gst_parse_date(text) FROM PUBLIC, anon;

-- ---------------------------------------------------------------------------
-- 2. Tables
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.buyer_gst_verifications (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id uuid NOT NULL REFERENCES public.companies(id),
  submitted_by uuid NOT NULL REFERENCES public.users(id),
  status text NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending', 'approved', 'rejected', 'superseded')),
  gstin text NOT NULL CHECK (gstin ~ '^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z][1-9A-Z]Z[0-9A-Z]$'),
  legal_name text NOT NULL CHECK (length(btrim(legal_name)) > 0),
  trade_name text,
  constitution text,
  principal_address text NOT NULL CHECK (length(btrim(principal_address)) > 0),
  pin_code text NOT NULL CHECK (pin_code ~ '^[1-9][0-9]{5}$'),
  registration_type text,
  registration_date date,
  validity_from date,
  validity_to text,
  issue_date date,
  ocr_values jsonb NOT NULL DEFAULT '{}'::jsonb,
  edited_fields text[] NOT NULL DEFAULT '{}',
  certificate_path text NOT NULL UNIQUE,
  seller_gstin_conflict boolean NOT NULL DEFAULT false,
  submitted_at timestamptz NOT NULL DEFAULT now(),
  reviewed_by uuid REFERENCES public.users(id),
  reviewed_at timestamptz,
  rejection_reason text,
  CONSTRAINT bgv_rejection_reason_required
    CHECK (status <> 'rejected' OR length(btrim(coalesce(rejection_reason, ''))) > 0),
  CONSTRAINT bgv_reviewed_fields
    CHECK (status NOT IN ('approved', 'rejected') OR (reviewed_by IS NOT NULL AND reviewed_at IS NOT NULL)),
  CONSTRAINT bgv_pending_unreviewed
    CHECK (status <> 'pending' OR (reviewed_by IS NULL AND reviewed_at IS NULL AND rejection_reason IS NULL))
);

-- One open submission and one approval per company; one active holder per GSTIN.
CREATE UNIQUE INDEX IF NOT EXISTS bgv_one_pending_per_company
  ON public.buyer_gst_verifications (company_id) WHERE status = 'pending';
CREATE UNIQUE INDEX IF NOT EXISTS bgv_one_approved_per_company
  ON public.buyer_gst_verifications (company_id) WHERE status = 'approved';
CREATE UNIQUE INDEX IF NOT EXISTS bgv_one_active_gstin
  ON public.buyer_gst_verifications (gstin) WHERE status IN ('pending', 'approved');
CREATE INDEX IF NOT EXISTS bgv_queue_idx
  ON public.buyer_gst_verifications (status, submitted_at);
CREATE INDEX IF NOT EXISTS bgv_company_idx
  ON public.buyer_gst_verifications (company_id, submitted_at DESC);

CREATE TABLE IF NOT EXISTS public.buyer_gst_verification_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  verification_id uuid NOT NULL REFERENCES public.buyer_gst_verifications(id),
  company_id uuid NOT NULL REFERENCES public.companies(id),
  event text NOT NULL CHECK (event IN ('submitted', 'replaced', 'superseded', 'approved', 'rejected')),
  from_status text,
  to_status text NOT NULL,
  actor_id uuid NOT NULL REFERENCES public.users(id),
  reason text,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS bgve_company_idx
  ON public.buyer_gst_verification_events (company_id, created_at);
CREATE INDEX IF NOT EXISTS bgve_verification_idx
  ON public.buyer_gst_verification_events (verification_id, created_at);

-- ---------------------------------------------------------------------------
-- 3. Integrity triggers
-- ---------------------------------------------------------------------------
-- Submitted content is immutable; only the allowed status transitions may happen.
CREATE OR REPLACE FUNCTION public.bgv_enforce_transition()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = ''
AS $$
BEGIN
  IF (NEW.company_id, NEW.submitted_by, NEW.gstin, NEW.legal_name, NEW.trade_name, NEW.constitution,
      NEW.principal_address, NEW.pin_code, NEW.registration_type, NEW.registration_date,
      NEW.validity_from, NEW.validity_to, NEW.issue_date, NEW.ocr_values, NEW.edited_fields,
      NEW.certificate_path, NEW.seller_gstin_conflict, NEW.submitted_at)
     IS DISTINCT FROM
     (OLD.company_id, OLD.submitted_by, OLD.gstin, OLD.legal_name, OLD.trade_name, OLD.constitution,
      OLD.principal_address, OLD.pin_code, OLD.registration_type, OLD.registration_date,
      OLD.validity_from, OLD.validity_to, OLD.issue_date, OLD.ocr_values, OLD.edited_fields,
      OLD.certificate_path, OLD.seller_gstin_conflict, OLD.submitted_at) THEN
    RAISE EXCEPTION 'submitted GST details are immutable' USING ERRCODE = '42501';
  END IF;
  IF NEW.status IS DISTINCT FROM OLD.status AND NOT (
       (OLD.status = 'pending' AND NEW.status IN ('approved', 'rejected', 'superseded'))
    OR (OLD.status = 'approved' AND NEW.status = 'superseded')) THEN
    RAISE EXCEPTION 'invalid GST verification transition % -> %', OLD.status, NEW.status
      USING ERRCODE = '22023';
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_bgv_enforce_transition ON public.buyer_gst_verifications;
CREATE TRIGGER trg_bgv_enforce_transition
BEFORE UPDATE ON public.buyer_gst_verifications
FOR EACH ROW EXECUTE FUNCTION public.bgv_enforce_transition();

CREATE OR REPLACE FUNCTION public.bgve_append_only()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = ''
AS $$
BEGIN
  RAISE EXCEPTION 'GST verification history is append-only' USING ERRCODE = '42501';
END;
$$;

DROP TRIGGER IF EXISTS trg_bgve_append_only ON public.buyer_gst_verification_events;
CREATE TRIGGER trg_bgve_append_only
BEFORE UPDATE OR DELETE ON public.buyer_gst_verification_events
FOR EACH ROW EXECUTE FUNCTION public.bgve_append_only();

-- Definer helper: does this company have a pending or approved GST record?
CREATE OR REPLACE FUNCTION public.company_has_active_gst_verification(p_company uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT EXISTS (SELECT 1 FROM public.buyer_gst_verifications v
                 WHERE v.company_id = p_company AND v.status IN ('pending', 'approved'))
$$;
REVOKE ALL ON FUNCTION public.company_has_active_gst_verification(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.company_has_active_gst_verification(uuid) TO authenticated;

-- (a) companies.gst cannot be edited by app users while a GST review is pending/approved:
--     a GSTIN change must go through submit (re-review).
CREATE OR REPLACE FUNCTION public.lock_company_gst_under_review()
RETURNS trigger
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = ''
AS $$
BEGIN
  IF current_user IN ('authenticated', 'anon')
     AND NOT coalesce(public.is_admin(), false)
     AND NEW.gst IS DISTINCT FROM OLD.gst
     AND public.company_has_active_gst_verification(OLD.id) THEN
    RAISE EXCEPTION 'GSTIN is under GST verification; submit a new certificate to change it'
      USING ERRCODE = '42501';
  END IF;
  RETURN NEW;
END;
$$;
REVOKE ALL ON FUNCTION public.lock_company_gst_under_review() FROM PUBLIC, anon;

DROP TRIGGER IF EXISTS trg_lock_company_gst_under_review ON public.companies;
CREATE TRIGGER trg_lock_company_gst_under_review
BEFORE UPDATE OF gst ON public.companies
FOR EACH ROW EXECUTE FUNCTION public.lock_company_gst_under_review();

-- (b) Any path (including postgres/server actions such as the legacy web
--     "Company Approvals") turning is_verified false→true on a company with
--     Buyer users needs an approved GST review. Existing true values are untouched.
CREATE OR REPLACE FUNCTION public.require_gst_review_for_buyer_verification()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  IF NEW.is_verified AND NOT coalesce(OLD.is_verified, false)
     AND EXISTS (SELECT 1 FROM public.users u WHERE u.company_id = NEW.id AND lower(u.role) = 'buyer')
     AND NOT EXISTS (SELECT 1 FROM public.buyer_gst_verifications v
                     WHERE v.company_id = NEW.id AND v.status = 'approved') THEN
    RAISE EXCEPTION 'Buyer company verification requires an approved GST review'
      USING ERRCODE = '42501';
  END IF;
  RETURN NEW;
END;
$$;
REVOKE ALL ON FUNCTION public.require_gst_review_for_buyer_verification() FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS trg_require_gst_review_for_buyer_verification ON public.companies;
CREATE TRIGGER trg_require_gst_review_for_buyer_verification
BEFORE UPDATE OF is_verified ON public.companies
FOR EACH ROW EXECUTE FUNCTION public.require_gst_review_for_buyer_verification();

-- ---------------------------------------------------------------------------
-- 4. Access: SELECT only, own company or admin. No client writes.
-- ---------------------------------------------------------------------------
ALTER TABLE public.buyer_gst_verifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.buyer_gst_verification_events ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.buyer_gst_verifications FROM PUBLIC, anon, authenticated;
REVOKE ALL ON public.buyer_gst_verification_events FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.buyer_gst_verifications TO authenticated;
GRANT SELECT ON public.buyer_gst_verification_events TO authenticated;

DROP POLICY IF EXISTS bgv_select_own_or_admin ON public.buyer_gst_verifications;
CREATE POLICY bgv_select_own_or_admin ON public.buyer_gst_verifications
FOR SELECT TO authenticated
USING (
  company_id = (SELECT u.company_id FROM public.users u WHERE u.id = auth.uid())
  OR public.is_admin()
);

DROP POLICY IF EXISTS bgve_select_own_or_admin ON public.buyer_gst_verification_events;
CREATE POLICY bgve_select_own_or_admin ON public.buyer_gst_verification_events
FOR SELECT TO authenticated
USING (
  company_id = (SELECT u.company_id FROM public.users u WHERE u.id = auth.uid())
  OR public.is_admin()
);

-- ---------------------------------------------------------------------------
-- 5. Buyer submission (pending only)
-- p_submission = the app's GstSubmissionDraft.toPayload():
--   { "submitted": {gstin, legalName, tradeName, constitution, address, pinCode,
--                   registrationDate, registrationType, validityFrom, validityTo, issueDate},
--     "ocr": {same keys}, "edited_fields": [...] }   (edited_fields is recomputed here)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.submit_buyer_gst_verification(
  p_submission jsonb,
  p_certificate_path text
)
RETURNS public.buyer_gst_verifications
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_company uuid;
  s jsonb := coalesce(p_submission -> 'submitted', '{}'::jsonb);
  o jsonb := coalesce(p_submission -> 'ocr', '{}'::jsonb);
  v_gstin text;
  v_legal text;
  v_address text;
  v_pin text;
  v_state text;
  v_approved public.buyer_gst_verifications;
  v_pending public.buyer_gst_verifications;
  v_row public.buyer_gst_verifications;
  v_edited text[];
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'authentication required' USING ERRCODE = '42501';
  END IF;
  IF public.get_auth_role() IS DISTINCT FROM 'buyer' THEN
    RAISE EXCEPTION 'only buyers can submit GST verification' USING ERRCODE = '42501';
  END IF;

  -- Company comes only from the caller's own users row; nothing in the payload is trusted for it.
  SELECT u.company_id INTO v_company
  FROM public.users u
  WHERE u.id = v_uid AND u.status AND lower(u.role) = 'buyer';
  IF v_company IS NULL THEN
    RAISE EXCEPTION 'no company is linked to this account' USING ERRCODE = '42501';
  END IF;

  v_gstin := upper(regexp_replace(coalesce(s ->> 'gstin', ''), '\s', '', 'g'));
  v_legal := nullif(btrim(s ->> 'legalName'), '');
  v_address := nullif(btrim(s ->> 'address'), '');
  v_pin := nullif(btrim(s ->> 'pinCode'), '');
  IF v_gstin = '' OR v_legal IS NULL OR v_address IS NULL OR v_pin IS NULL THEN
    RAISE EXCEPTION 'required field missing' USING ERRCODE = '22023';
  END IF;
  IF NOT public.gstin_is_valid(v_gstin) THEN
    RAISE EXCEPTION 'invalid GSTIN' USING ERRCODE = '22023';
  END IF;
  IF v_pin !~ '^[1-9][0-9]{5}$' THEN
    RAISE EXCEPTION 'invalid PIN code' USING ERRCODE = '22023';
  END IF;
  v_state := public.gst_state_name(substr(v_gstin, 1, 2));
  IF v_state IS NULL THEN
    RAISE EXCEPTION 'unknown GSTIN state code' USING ERRCODE = '22023';
  END IF;
  IF NOT public.gst_address_state_consistent(v_address, v_state) THEN
    RAISE EXCEPTION 'address state does not match GSTIN state' USING ERRCODE = '22023';
  END IF;

  -- Certificate: caller's own folder, permitted name, object present and owned by the caller.
  IF p_certificate_path IS NULL
     OR p_certificate_path !~ ('^' || v_uid::text || '/[0-9a-f-]{36}\.(jpg|png)$') THEN
    RAISE EXCEPTION 'certificate path is not permitted' USING ERRCODE = '42501';
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM storage.objects ob
    WHERE ob.bucket_id = 'brokerbridge_buyer_gst_certificates'
      AND ob.name = p_certificate_path
      AND coalesce(ob.owner_id, ob.owner::text) = v_uid::text) THEN
    RAISE EXCEPTION 'certificate upload not found' USING ERRCODE = '42501';
  END IF;

  -- Serialize submissions per company.
  PERFORM 1 FROM public.companies c WHERE c.id = v_company FOR UPDATE;

  SELECT * INTO v_approved FROM public.buyer_gst_verifications
  WHERE company_id = v_company AND status = 'approved';
  IF FOUND AND v_approved.gstin = v_gstin AND lower(v_approved.legal_name) = lower(v_legal) THEN
    RAISE EXCEPTION 'already verified with these details' USING ERRCODE = '22023';
  END IF;

  -- Replace an open submission, keeping its history.
  SELECT * INTO v_pending FROM public.buyer_gst_verifications
  WHERE company_id = v_company AND status = 'pending';
  IF FOUND THEN
    UPDATE public.buyer_gst_verifications SET status = 'superseded' WHERE id = v_pending.id;
    INSERT INTO public.buyer_gst_verification_events
      (verification_id, company_id, event, from_status, to_status, actor_id)
    VALUES (v_pending.id, v_company, 'replaced', 'pending', 'superseded', v_uid);
  END IF;

  -- Material change (GSTIN or legal name) on an approved company: approval ends until re-review.
  IF v_approved.id IS NOT NULL THEN
    UPDATE public.buyer_gst_verifications SET status = 'superseded' WHERE id = v_approved.id;
    INSERT INTO public.buyer_gst_verification_events
      (verification_id, company_id, event, from_status, to_status, actor_id, reason)
    VALUES (v_approved.id, v_company, 'superseded', 'approved', 'superseded', v_uid,
            'GSTIN or legal name changed; re-review required');
    UPDATE public.companies SET is_verified = false WHERE id = v_company;
  END IF;

  SELECT coalesce(array_agg(e.key ORDER BY e.key), '{}') INTO v_edited
  FROM jsonb_each(s) e
  WHERE (e.value #>> '{}') IS DISTINCT FROM (o ->> e.key);

  BEGIN
    INSERT INTO public.buyer_gst_verifications (
      company_id, submitted_by, status, gstin, legal_name, trade_name, constitution,
      principal_address, pin_code, registration_type, registration_date, validity_from,
      validity_to, issue_date, ocr_values, edited_fields, certificate_path, seller_gstin_conflict)
    VALUES (
      v_company, v_uid, 'pending', v_gstin, v_legal, nullif(btrim(s ->> 'tradeName'), ''),
      nullif(btrim(s ->> 'constitution'), ''), v_address, v_pin,
      nullif(btrim(s ->> 'registrationType'), ''),
      public.gst_parse_date(s ->> 'registrationDate'),
      public.gst_parse_date(s ->> 'validityFrom'),
      nullif(btrim(s ->> 'validityTo'), ''),
      public.gst_parse_date(s ->> 'issueDate'),
      o, v_edited, p_certificate_path,
      -- Same GSTIN on a Seller company: flagged for the reviewer, not rejected.
      EXISTS (SELECT 1 FROM public.companies c JOIN public.users u ON u.company_id = c.id
              WHERE c.id <> v_company AND upper(btrim(c.gst)) = v_gstin AND lower(u.role) = 'seller'))
    RETURNING * INTO v_row;
  EXCEPTION WHEN unique_violation THEN
    RAISE EXCEPTION 'this GSTIN or certificate is already registered for verification'
      USING ERRCODE = '23505';
  END;

  INSERT INTO public.buyer_gst_verification_events
    (verification_id, company_id, event, from_status, to_status, actor_id)
  VALUES (v_row.id, v_company, 'submitted', NULL, 'pending', v_uid);

  RETURN v_row;
END;
$$;

REVOKE ALL ON FUNCTION public.submit_buyer_gst_verification(jsonb, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.submit_buyer_gst_verification(jsonb, text) TO authenticated;

-- ---------------------------------------------------------------------------
-- 6. Admin review (approve / reject with reason)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.review_buyer_gst_verification(
  p_id uuid,
  p_decision text,
  p_reason text DEFAULT NULL
)
RETURNS public.buyer_gst_verifications
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_admin uuid := auth.uid();
  v_row public.buyer_gst_verifications;
  v_status text;
BEGIN
  -- is_admin() is NULL (not false) for a user with no role; coalesce so that fails closed.
  IF v_admin IS NULL OR NOT coalesce(public.is_admin(), false) THEN
    RAISE EXCEPTION 'admin access required' USING ERRCODE = '42501';
  END IF;
  IF p_decision NOT IN ('approve', 'reject') THEN
    RAISE EXCEPTION 'decision must be approve or reject' USING ERRCODE = '22023';
  END IF;
  IF p_decision = 'reject' AND nullif(btrim(p_reason), '') IS NULL THEN
    RAISE EXCEPTION 'a rejection reason is required' USING ERRCODE = '22023';
  END IF;

  SELECT * INTO v_row FROM public.buyer_gst_verifications WHERE id = p_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'GST verification not found' USING ERRCODE = 'P0002';
  END IF;
  IF v_row.status <> 'pending' THEN
    RAISE EXCEPTION 'only pending submissions can be reviewed' USING ERRCODE = '22023';
  END IF;

  v_status := CASE p_decision WHEN 'approve' THEN 'approved' ELSE 'rejected' END;
  UPDATE public.buyer_gst_verifications
  SET status = v_status,
      reviewed_by = v_admin,
      reviewed_at = now(),
      rejection_reason = CASE WHEN p_decision = 'reject' THEN btrim(p_reason) END
  WHERE id = p_id
  RETURNING * INTO v_row;

  INSERT INTO public.buyer_gst_verification_events
    (verification_id, company_id, event, from_status, to_status, actor_id, reason)
  VALUES (p_id, v_row.company_id, v_status, 'pending', v_status, v_admin,
          CASE WHEN p_decision = 'reject' THEN btrim(p_reason) END);

  IF p_decision = 'approve' THEN
    -- The company display name is never overwritten from the certificate.
    UPDATE public.companies SET is_verified = true, gst = v_row.gstin WHERE id = v_row.company_id;
  END IF;

  -- One in-app notification per Buyer user per committed decision.
  INSERT INTO public.notifications (
    user_id, company_id, channel, event_type, title, message, context_reason,
    action_label, action_url, payload, delivery_status, idempotency_key, is_read, created_at)
  SELECT u.id, v_row.company_id, 'IN_APP',
         CASE WHEN p_decision = 'approve' THEN 'GST_VERIFICATION_APPROVED' ELSE 'GST_VERIFICATION_REJECTED' END,
         CASE WHEN p_decision = 'approve' THEN 'GST verification approved' ELSE 'GST verification rejected' END,
         CASE WHEN p_decision = 'approve' THEN 'Your GST certificate was reviewed and approved.'
              ELSE 'Your GST certificate was rejected: ' || btrim(p_reason) END,
         'GST verification review', 'View status', '/gst-verification',
         jsonb_build_object('verificationId', p_id, 'status', v_status),
         'Sent', 'gstv-' || p_id::text || '-' || v_status || '-' || u.id::text, false, now()
  FROM public.users u
  WHERE u.company_id = v_row.company_id AND lower(u.role) = 'buyer' AND u.status
  ON CONFLICT (idempotency_key) DO NOTHING;

  RETURN v_row;
END;
$$;

REVOKE ALL ON FUNCTION public.review_buyer_gst_verification(uuid, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.review_buyer_gst_verification(uuid, text, text) TO authenticated;

-- ---------------------------------------------------------------------------
-- 7. Private certificate bucket (JPG/PNG, 5 MB, owner folder, no update/delete)
-- ---------------------------------------------------------------------------
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES ('brokerbridge_buyer_gst_certificates', 'brokerbridge_buyer_gst_certificates', false,
        5242880, ARRAY['image/jpeg', 'image/png'])
ON CONFLICT (id) DO UPDATE
SET public = false, file_size_limit = 5242880, allowed_mime_types = ARRAY['image/jpeg', 'image/png'];

DROP POLICY IF EXISTS "Buyers upload own GST certificate" ON storage.objects;
CREATE POLICY "Buyers upload own GST certificate" ON storage.objects
FOR INSERT TO authenticated
WITH CHECK (
  bucket_id = 'brokerbridge_buyer_gst_certificates'
  AND (storage.foldername(name))[1] = auth.uid()::text
  AND name ~ '^[^/]+/[0-9a-f-]{36}\.(jpg|png)$'
  AND public.get_auth_role() = 'buyer'
);

DROP POLICY IF EXISTS "Owner or admin reads GST certificate" ON storage.objects;
CREATE POLICY "Owner or admin reads GST certificate" ON storage.objects
FOR SELECT TO authenticated
USING (
  bucket_id = 'brokerbridge_buyer_gst_certificates'
  AND ((storage.foldername(name))[1] = auth.uid()::text OR public.is_admin())
);
-- Deliberately no UPDATE/DELETE policy: certificates are immutable; Replace uploads a new object.
-- Retention (approved proposal): rejected/superseded certificates purge-eligible after 12 months,
-- by an admin job, subject to legal/business obligations. Not automated in this migration.
