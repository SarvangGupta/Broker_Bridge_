-- Rollback for PROPOSED 0054. Export the two tables first if they hold rows:
--   COPY public.buyer_gst_verifications TO ...; COPY public.buyer_gst_verification_events TO ...;
-- companies.is_verified / gst values written by approvals are NOT reverted automatically;
-- use the exported events to reconcile them manually if required.
DROP POLICY IF EXISTS "Buyers upload own GST certificate" ON storage.objects;
DROP POLICY IF EXISTS "Owner or admin reads GST certificate" ON storage.objects;
-- The bucket itself is NOT removed here: Supabase blocks direct DELETE on storage
-- tables (storage.protect_delete, 42501). After this script, delete the bucket
-- 'brokerbridge_buyer_gst_certificates' with the Storage API or Dashboard
-- (Storage → bucket → Delete). With the policies above gone it is unreachable
-- from the apps either way.

DROP TRIGGER IF EXISTS trg_require_gst_review_for_buyer_verification ON public.companies;
DROP TRIGGER IF EXISTS trg_lock_company_gst_under_review ON public.companies;
DROP FUNCTION IF EXISTS public.review_buyer_gst_verification(uuid, text, text);
DROP FUNCTION IF EXISTS public.submit_buyer_gst_verification(jsonb, text);
DROP FUNCTION IF EXISTS public.require_gst_review_for_buyer_verification();
DROP FUNCTION IF EXISTS public.lock_company_gst_under_review();
DROP TABLE IF EXISTS public.buyer_gst_verification_events;
DROP TABLE IF EXISTS public.buyer_gst_verifications;
DROP FUNCTION IF EXISTS public.company_has_active_gst_verification(uuid);
DROP FUNCTION IF EXISTS public.bgve_append_only();
DROP FUNCTION IF EXISTS public.bgv_enforce_transition();
DROP FUNCTION IF EXISTS public.gst_parse_date(text);
DROP FUNCTION IF EXISTS public.gst_address_state_consistent(text, text);
DROP FUNCTION IF EXISTS public.gst_state_name(text);
DROP FUNCTION IF EXISTS public.gstin_is_valid(text);
