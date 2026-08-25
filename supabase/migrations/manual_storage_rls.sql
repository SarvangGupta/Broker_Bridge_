-- 1. Create the private bucket 'brokerbridge_documents' if it doesn't exist
INSERT INTO storage.buckets (id, name, public) 
VALUES ('brokerbridge_documents', 'brokerbridge_documents', false)
ON CONFLICT (id) DO NOTHING;

-- 2. Allow authenticated users to INSERT files into this bucket
CREATE POLICY "Allow authenticated users to insert documents" 
ON storage.objects FOR INSERT 
TO authenticated 
WITH CHECK (
  bucket_id = 'brokerbridge_documents' 
  AND auth.uid() IS NOT NULL
);

-- 3. Allow users to SELECT files if their user ID matches buyer_id, seller_id, or broker_id of the deal
-- Path format: {deal_id}/{filename}. We can extract deal_id using (regexp_split_to_array(name, '/'))[1]
CREATE POLICY "Allow users to view documents related to their deals"
ON storage.objects FOR SELECT
TO authenticated
USING (
  bucket_id = 'brokerbridge_documents'
  AND EXISTS (
    SELECT 1 FROM public.deals
    WHERE public.deals.id = (regexp_split_to_array(storage.objects.name, '/'))[1]::uuid
    AND (
      public.deals.buyer_id = auth.uid()
      OR public.deals.seller_id = auth.uid()
      OR public.deals.broker_id = auth.uid()
    )
  )
);
