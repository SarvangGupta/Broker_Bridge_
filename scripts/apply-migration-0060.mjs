import postgres from 'postgres';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const rootDir = path.resolve(__dirname, '..');
const envPath = path.join(rootDir, '.env.local');

const env = Object.fromEntries(
  fs.readFileSync(envPath, 'utf8').split(/\r?\n/)
    .filter((l) => /^[A-Z_]+=/.test(l))
    .map((l) => [l.slice(0, l.indexOf('=')), l.slice(l.indexOf('=') + 1).replace(/^"|"$/g, '')])
);
const sql = postgres(env.DATABASE_URL, { prepare: false, max: 1 });

async function apply() {
  console.log('--- Applying 0059 & 0060 schema enhancements ---');

  // 1. Add removed_at column to crm_contacts
  await sql`
    ALTER TABLE public.crm_contacts 
    ADD COLUMN IF NOT EXISTS removed_at TIMESTAMPTZ DEFAULT NULL;
  `;
  console.log('1. Added removed_at column to public.crm_contacts');

  // 2. Create partial index for active contacts
  await sql`
    CREATE INDEX IF NOT EXISTS idx_crm_contacts_broker_active 
    ON public.crm_contacts(broker_id, created_at DESC) 
    WHERE removed_at IS NULL;
  `;
  console.log('2. Created partial index idx_crm_contacts_broker_active');

  // 3. Apply 0059: allow DELETE for authenticated brokers on crm_contacts
  await sql`GRANT DELETE ON TABLE public.crm_contacts TO authenticated;`;
  await sql`DROP POLICY IF EXISTS "crm_contacts_delete_policy" ON public.crm_contacts;`;
  await sql`
    CREATE POLICY "crm_contacts_delete_policy"
    ON public.crm_contacts
    FOR DELETE
    TO authenticated
    USING (
      broker_id = auth.uid() OR public.is_admin()
    );
  `;
  console.log('3. Granted DELETE & created crm_contacts_delete_policy on public.crm_contacts');

  // Verify
  const cols = await sql`
    SELECT column_name, data_type, is_nullable
    FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'crm_contacts';
  `;
  console.log('Updated crm_contacts columns:', cols.map((c) => c.column_name));

  const policies = await sql`
    SELECT policyname, cmd, qual
    FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'crm_contacts';
  `;
  console.log('Updated crm_contacts policies:', policies.map((p) => `${p.policyname} (${p.cmd})`));

  await sql.end();
}

apply().catch(console.error);

