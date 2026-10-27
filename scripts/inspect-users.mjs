import postgres from 'postgres';
import fs from 'node:fs';

const env = Object.fromEntries(
  fs.readFileSync('.env.local', 'utf8').split(/\r?\n/)
    .filter((l) => /^[A-Z_]+=/.test(l))
    .map((l) => [l.slice(0, l.indexOf('=')), l.slice(l.indexOf('=') + 1).replace(/^"|"$/g, '')])
);
const sql = postgres(env.DATABASE_URL, { prepare: false, max: 1 });

async function run() {
  // Check all auth.users
  const authUsers = await sql`
    SELECT a.id, a.email, a.phone, a.created_at,
           a.raw_app_meta_data, a.raw_user_meta_data,
           p.id as public_id, p.role as public_role, p.company_id as public_company_id, p.status as public_status
    FROM auth.users a
    LEFT JOIN public.users p ON a.id = p.id
    ORDER BY a.created_at;
  `;
  console.log('All auth.users and matching public.users:');
  for (const u of authUsers) {
    console.log({
      id: u.id,
      email: u.email,
      phone: u.phone,
      created_at: u.created_at,
      app_meta: u.raw_app_meta_data,
      user_meta: u.raw_user_meta_data,
      in_public: u.public_id != null,
      public_role: u.public_role,
      public_company_id: u.public_company_id,
      public_status: u.public_status
    });
  }

  // Check all public.users that have NO auth.users row
  const publicWithoutAuth = await sql`
    SELECT p.id, p.name, p.role, p.status, p.company_id
    FROM public.users p
    LEFT JOIN auth.users a ON p.id = a.id
    WHERE a.id IS NULL;
  `;
  console.log('\nPublic users without auth row count:', publicWithoutAuth.length);
  for (const p of publicWithoutAuth) {
    console.log({ id: p.id, name: p.name, role: p.role, status: p.status, company_id: p.company_id });
  }

  // Check functions that reference public.users
  const funcs = await sql`
    SELECT routine_name, routine_definition
    FROM information_schema.routines
    WHERE routine_schema = 'public'
      AND routine_definition ILIKE '%users%';
  `;
  console.log('\nFunctions referencing users:');
  for (const f of funcs) {
    console.log(`  ${f.routine_name}`);
  }

  await sql.end();
}

run().catch(console.error);
