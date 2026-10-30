-- Rollback for 0057_counterparty_gst_and_bank_verification.sql
DROP FUNCTION IF EXISTS public.review_counterparty_verification(UUID, BOOLEAN, TEXT);
DROP TABLE IF EXISTS public.deal_document_shares;
DROP TABLE IF EXISTS public.counterparty_verification_requests;
DROP INDEX IF EXISTS idx_companies_unique_active_gst;
DROP INDEX IF EXISTS idx_companies_gst_verification_status;
DROP INDEX IF EXISTS idx_companies_bank_verification_status;
NOTIFY pgrst, 'reload schema';