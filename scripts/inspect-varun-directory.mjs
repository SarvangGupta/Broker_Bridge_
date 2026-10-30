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

async function run() {
  console.log('--- 1. crm_contacts Table Schema ---');
  const cols = await sql`
    SELECT column_name, data_type, is_nullable, column_default
    FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'crm_contacts'
    ORDER BY ordinal_position;
  `;
  console.log('crm_contacts columns:', cols);

  console.log('\n--- 2. crm_contacts constraints and indexes ---');
  const constraints = await sql`
    SELECT conname, contype, pg_get_constraintdef(c.oid)
    FROM pg_constraint c
    JOIN pg_namespace n ON n.oid = c.connamespace
    WHERE n.nspname = 'public' AND conrelid = 'public.crm_contacts'::regclass;
  `;
  console.log('constraints:', constraints);

  console.log('\n--- 3. crm_contacts Triggers ---');
  const triggers = await sql`
    SELECT tgname, pg_get_triggerdef(t.oid)
    FROM pg_trigger t
    WHERE tgrelid = 'public.crm_contacts'::regclass;
  `;
  console.log('triggers:', triggers);

  console.log('\n--- 4. crm_contacts RLS Policies ---');
  const policies = await sql`
    SELECT policyname, permissive, roles, cmd, qual, with_check
    FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'crm_contacts';
  `;
  console.log('policies:', policies);

  await sql.end();
}

run().catch((e) => {
  console.error(e);
  process.exit(1);
});
