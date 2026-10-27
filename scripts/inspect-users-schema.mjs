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

  await sql.end();
}

run();
