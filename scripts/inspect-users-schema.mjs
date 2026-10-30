import postgres from 'postgres';
import fs from 'node:fs';

const env = Object.fromEntries(
  fs.readFileSync('.env.local', 'utf8').split(/\r?\n/)
    .filter((l) => /^[A-Z_]+=/.test(l))
    .map((l) => [l.slice(0, l.indexOf('=')), l.slice(l.indexOf('=') + 1).replace(/^"|"$/g, '')])
);

const sql = postgres(env.DATABASE_URL, { prepare: false, max: 1 });

async function run() {
  const policies = await sql`SELECT policyname, cmd, roles, qual, with_check FROM pg_policies WHERE tablename = 'users';`;
  console.log('POLICIES ON users:', JSON.stringify(policies, null, 2));

  const triggers = await sql`
    SELECT trigger_name, event_manipulation, action_statement, action_timing
    FROM information_schema.triggers
    WHERE event_object_table = 'users';
  `;
  console.log('TRIGGERS ON users:', JSON.stringify(triggers, null, 2));

  const authTriggers = await sql`
    SELECT trigger_name, event_manipulation, action_statement, action_timing, event_object_schema, event_object_table
    FROM information_schema.triggers
    WHERE event_object_schema = 'auth';
  `;
  console.log('TRIGGERS ON auth:', JSON.stringify(authTriggers, null, 2));

  const userColumns = await sql`
    SELECT column_name, data_type, is_nullable, column_default
    FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'users';
  `;
  console.log('COLUMNS ON users:', JSON.stringify(userColumns, null, 2));

  const compColumns = await sql`
    SELECT column_name, data_type, is_nullable, column_default
    FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'companies';
  `;
  console.log('COLUMNS ON companies:', JSON.stringify(compColumns, null, 2));

  const compPolicies = await sql`
    SELECT policyname, cmd, roles, qual, with_check FROM pg_policies WHERE tablename = 'companies';
  `;
  console.log('POLICIES ON companies:', JSON.stringify(compPolicies, null, 2));

  const pbColumns = await sql`
    SELECT column_name, data_type FROM information_schema.columns WHERE table_name = 'profiles_broker';
  `;
  console.log('COLUMNS ON profiles_broker:', JSON.stringify(pbColumns, null, 2));

  const storageBuckets = await sql`
    SELECT id, name, public FROM storage.buckets;
  `;
  console.log('STORAGE BUCKETS:', JSON.stringify(storageBuckets, null, 2));

  const brokerUsers = await sql`SELECT id, name, mobile, email, role, company_id FROM users WHERE lower(role) = 'broker' LIMIT 3;`;
  console.log('SAMPLE BROKERS:', JSON.stringify(brokerUsers, null, 2));
  if (brokerUsers.length > 0 && brokerUsers[0].company_id) {
    const comp = await sql`SELECT * FROM companies WHERE id = ${brokerUsers[0].company_id};`;
    console.log('BROKER COMPANY:', JSON.stringify(comp, null, 2));
  }

  const func = await sql`SELECT prosrc FROM pg_proc WHERE proname = 'prevent_self_company_change';`;
  console.log('FUNCTION prevent_self_company_change:', func[0]?.prosrc);

  await sql.end();
}

run();
