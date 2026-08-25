-- Enable RLS on the companies table
ALTER TABLE companies ENABLE ROW LEVEL SECURITY;

-- Policy: Allow an authenticated user to SELECT a company row ONLY IF their Supabase Auth UID matches a user in the users table who is linked to that specific company_id.
CREATE POLICY "Users can select their own company"
ON companies
FOR SELECT
TO authenticated
USING (
  id IN (
    SELECT company_id 
    FROM users 
    WHERE id = auth.uid()
  )
);

-- Policy: Allow an authenticated user to UPDATE a company row ONLY IF their Supabase Auth UID matches a user in the users table who is linked to that specific company_id.
CREATE POLICY "Users can update their own company"
ON companies
FOR UPDATE
TO authenticated
USING (
  id IN (
    SELECT company_id 
    FROM users 
    WHERE id = auth.uid()
  )
)
WITH CHECK (
  id IN (
    SELECT company_id 
    FROM users 
    WHERE id = auth.uid()
  )
);

-- Policy: Tier 0 admin users have full access to the companies table.
CREATE POLICY "Tier 0 admin users full access to companies"
ON companies
FOR ALL
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM users
    WHERE users.id = auth.uid() AND users.role = 'admin'
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1 FROM users
    WHERE users.id = auth.uid() AND users.role = 'admin'
  )
);
