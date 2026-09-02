-- ==============================================================================
-- Migration: manual_lab_storage_rls.sql
-- Description: Private Supabase Storage bucket and RLS policies for Laboratory Evidence
-- Path format: {availability_id}/{filename}
-- ==============================================================================

-- 1. Create the private bucket 'brokerbridge_lab_evidence' if it doesn't exist
INSERT INTO storage.buckets (id, name, public)
VALUES ('brokerbridge_lab_evidence', 'brokerbridge_lab_evidence', false)
ON CONFLICT (id) DO NOTHING;

-- 2. Allow authenticated users to upload files into 'brokerbridge_lab_evidence'
CREATE POLICY "Allow authenticated users to upload lab evidence"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'brokerbridge_lab_evidence'
  AND auth.uid() IS NOT NULL
);

-- 3. Allow authorized users to SELECT (download/view) files only if:
--    - The user's company matches the company on the availability/lab_tests record
--    - OR the user's role is 'broker' or 'admin'
CREATE POLICY "Allow authorized users to view lab evidence"
ON storage.objects FOR SELECT
TO authenticated
USING (
  bucket_id = 'brokerbridge_lab_evidence'
  AND (
    -- Admin or Broker role authorization
    EXISTS (
      SELECT 1 FROM public.users
      WHERE public.users.id = auth.uid()
      AND public.users.role IN ('admin', 'broker')
    )
    OR
    -- Seller company ownership authorization (matches availability_id in path)
    EXISTS (
      SELECT 1 FROM public.availabilities
      JOIN public.users ON public.users.company_id = public.availabilities.company_id
      WHERE public.availabilities.id = (regexp_split_to_array(storage.objects.name, '/'))[1]::uuid
      AND public.users.id = auth.uid()
    )
  )
);
