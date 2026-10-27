import postgres from 'postgres';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const root = path.join(path.dirname(fileURLToPath(import.meta.url)), '..');
const envPath = path.join(root, '.env.local');
if (!fs.existsSync(envPath)) {
  console.log('No .env.local found');
  process.exit(1);
}

const env = Object.fromEntries(
  fs.readFileSync(envPath, 'utf8').split(/\r?\n/)
    .filter((l) => /^[A-Z_]+=/.test(l))
    .map((l) => [l.slice(0, l.indexOf('=')), l.slice(l.indexOf('=') + 1).replace(/^"|"$/g, '')]),
);

if (!env.DATABASE_URL) {
  console.log('DATABASE_URL is not set.');
  process.exit(1);
}

const sql = postgres(env.DATABASE_URL, { prepare: false, max: 1 });

async function inspect() {
  await sql.begin('read only', async (t) => {
    // 1. Check availabilities columns
    const availCols = await t`
      SELECT column_name, data_type, is_nullable, column_default
      FROM information_schema.columns
      WHERE table_name = 'availabilities' AND table_schema = 'public'
      ORDER BY ordinal_position;
    `;
    console.log('--- availabilities columns ---');
    console.table(availCols.map(c => ({
      name: c.column_name,
      type: c.data_type,
      nullable: c.is_nullable,
      default: c.column_default
    })));

    // 2. Check availabilities indexes
    const indexes = await t`
      SELECT indexname, indexdef
      FROM pg_indexes
      WHERE tablename = 'availabilities' AND schemaname = 'public';
    `;
    console.log('--- availabilities indexes ---');
    console.table(indexes);

    // 3. Check availabilities constraints
    const constraints = await t`
      SELECT conname, contype, pg_get_constraintdef(c.oid) as def
      FROM pg_constraint c
      JOIN pg_class t ON c.conrelid = t.oid
      JOIN pg_namespace n ON t.relnamespace = n.oid
      WHERE t.relname = 'availabilities' AND n.nspname = 'public';
    `;
    console.log('--- availabilities constraints ---');
    console.table(constraints);

    // 4. Check policies on availabilities
    const policies = await t`
      SELECT policyname, permissive, roles, cmd, qual, with_check
      FROM pg_policies
      WHERE tablename = 'availabilities' AND schemaname = 'public';
    `;
    console.log('--- availabilities policies ---');
    for (const p of policies) {
      console.log(`POLICY: ${p.policyname} (${p.cmd})`);
      console.log(`  USING: ${p.qual}`);
      console.log(`  WITH CHECK: ${p.with_check}`);
    }

    // 5. Check triggers on auth.users and public.users
    const triggers = await t`
      SELECT event_object_schema, event_object_table, trigger_name, action_statement, action_orientation, action_timing
      FROM information_schema.triggers
      WHERE (event_object_table IN ('users') AND event_object_schema IN ('public', 'auth'))
      ORDER BY event_object_schema, event_object_table, trigger_name;
    `;
    console.log('--- triggers on users ---');
    console.table(triggers);

    // 6. Inspect auth.users count vs public.users count
    const [authCount] = await t`SELECT COUNT(*) FROM auth.users;`;
    const [publicCount] = await t`SELECT COUNT(*) FROM public.users;`;
    console.log(`User counts: auth.users=${authCount.count}, public.users=${publicCount.count}`);

    // 7. Check auth.users that are not in public.users (without printing PII)
    const missingInPublic = await t`
      SELECT a.id, a.email IS NOT NULL as has_email, a.created_at,
             a.raw_app_meta_data->>'role' as app_role,
             a.raw_user_meta_data->>'role' as user_meta_role
      FROM auth.users a
      LEFT JOIN public.users p ON a.id = p.id
      WHERE p.id IS NULL;
    `;
    console.log(`Unprovisioned auth users: ${missingInPublic.length}`);
    console.table(missingInPublic.map(u => ({
      id_prefix: u.id.slice(0, 8) + '...',
      has_email: u.has_email,
      created_at: u.created_at,
      app_role: u.app_role,
      user_meta_role: u.user_meta_role
    })));

    // 8. Check existing public.users roles and company status
    const publicUserStats = await t`
      SELECT role, status, (company_id IS NOT NULL) as has_company, count(*)
      FROM public.users
      GROUP BY role, status, (company_id IS NOT NULL);
    `;
    console.log('--- public.users breakdown ---');
    console.table(publicUserStats);

    // 9. Check availabilities row count and company/seller distribution
    const [availCount] = await t`SELECT count(*) FROM public.availabilities;`;
    console.log(`availabilities row count: ${availCount.count}`);
    const availSummary = await t`
      SELECT
        count(*) as total,
        count(company_id) as with_company,
        count(*) - count(company_id) as without_company,
        count(broker_id) as with_broker
      FROM public.availabilities;
    `;
    console.table(availSummary);
  });
  await sql.end();
}

inspect().catch(err => {
  console.error(err);
  process.exit(1);
});
