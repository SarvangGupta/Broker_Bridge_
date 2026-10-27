import postgres from 'postgres';
import fs from 'node:fs';

const env = Object.fromEntries(
  fs.readFileSync('.env.local', 'utf8').split(/\r?\n/)
    .filter((l) => /^[A-Z_]+=/.test(l))
    .map((l) => [l.slice(0, l.indexOf('=')), l.slice(l.indexOf('=') + 1).replace(/^"|"$/g, '')])
);

const sql = postgres(env.DATABASE_URL, { prepare: false, max: 1 });

async function inspect() {
  console.log('=== REAL DATABASE INSPECTION (READ ONLY) ===');

  // 1. Database & Project identification
  const dbInfo = await sql`SELECT current_database(), current_user, version();`;
  console.log('Database:', dbInfo[0].current_database, 'User:', dbInfo[0].current_user);

  // 2. Applied policies on availabilities
  const policies = await sql`
    SELECT policyname, permissive, roles, cmd, qual, with_check
    FROM pg_policies
    WHERE tablename = 'availabilities';
  `;
  console.log('\n--- Applied Policies on availabilities ---');
  for (const p of policies) {
    console.log(`- [${p.cmd}] ${p.policyname}`);
  }

  // 3. Constraints & Columns on availabilities
  const cols = await sql`
    SELECT column_name, data_type, is_nullable
    FROM information_schema.columns
    WHERE table_name = 'availabilities' AND table_schema = 'public';
  `;
  console.log('\n--- Columns on public.availabilities ---');
  for (const c of cols) {
    console.log(`- ${c.column_name}: ${c.data_type} (nullable: ${c.is_nullable})`);
  }

  const constraints = await sql`
    SELECT conname, contype, pg_get_constraintdef(c.oid) as def
    FROM pg_constraint c
    JOIN pg_class t ON c.conrelid = t.oid
    WHERE t.relname = 'availabilities';
  `;
  console.log('\n--- Constraints on public.availabilities ---');
  for (const c of constraints) {
    console.log(`- ${c.conname} (${c.contype}): ${c.def}`);
  }

  const indexes = await sql`
    SELECT indexname, indexdef
    FROM pg_indexes
    WHERE tablename = 'availabilities';
  `;
  console.log('\n--- Indexes on public.availabilities ---');
  for (const i of indexes) {
    console.log(`- ${i.indexname}: ${i.indexdef}`);
  }

  // 4. Existing users with role = 'seller'
  const sellers = await sql`
    SELECT u.id, u.name, u.email, u.mobile, u.role, u.status, u.company_id, c.name as company_name
    FROM public.users u
    LEFT JOIN public.companies c ON u.company_id = c.id
    WHERE LOWER(u.role) = 'seller';
  `;
  console.log('\n--- Public Users with role = seller ---');
  console.log(`Found ${sellers.length} sellers:`);
  for (const s of sellers) {
    console.log(`- id: ${s.id}, name: ${s.name}, email: ${s.email}, status: ${s.status}, company_id: ${s.company_id}, firm: ${s.company_name}`);
  }

  // 5. Check auth.users for seller logins
  const authUsers = await sql`
    SELECT id, email, confirmed_at, raw_app_meta_data, raw_user_meta_data
    FROM auth.users;
  `;
  console.log('\n--- Auth Users ---');
  console.log(`Found ${authUsers.length} total auth accounts:`);
  for (const a of authUsers) {
    console.log(`- id: ${a.id}, email: ${a.email}, app_metadata: ${JSON.stringify(a.raw_app_meta_data)}, user_metadata: ${JSON.stringify(a.raw_user_meta_data)}`);
  }

  // 6. Existing availabilities rows
  const availabilities = await sql`
    SELECT a.id, a.lot_number, a.company_id, a.seller_user_id, a.commodity_id, a.asking_price, a.price, a.status, a.broker_id, a.created_at,
           c.name as commodity_name, comp.name as company_name
    FROM public.availabilities a
    LEFT JOIN public.master_commodities c ON a.commodity_id = c.id
    LEFT JOIN public.companies comp ON a.company_id = comp.id;
  `;
  console.log('\n--- Current Rows in public.availabilities ---');
  console.log(`Found ${availabilities.length} lots:`);
  for (const a of availabilities) {
    console.log(`- id: ${a.id}, lot: ${a.lot_number}, company: ${a.company_name} (${a.company_id}), seller_user_id: ${a.seller_user_id}, status: ${a.status}, price: ${a.asking_price ?? a.price}, broker_id: ${a.broker_id}`);
  }

  // 7. Active Brokers in public.users
  const brokers = await sql`
    SELECT id, name, email, mobile, role, status
    FROM public.users
    WHERE LOWER(role) = 'broker' AND status = true;
  `;
  console.log('\n--- Active Brokers in public.users ---');
  console.log(`Found ${brokers.length} active brokers:`);
  for (const b of brokers) {
    console.log(`- id: ${b.id}, name: ${b.name}, status: ${b.status}`);
  }

  await sql.end();
}

inspect().catch(err => {
  console.error(err);
  process.exit(1);
});
