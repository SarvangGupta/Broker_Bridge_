import postgres from 'postgres';
import fs from 'node:fs';

const env = Object.fromEntries(
  fs.readFileSync('.env.local', 'utf8').split(/\r?\n/)
    .filter((l) => /^[A-Z_]+=/.test(l))
    .map((l) => [l.slice(0, l.indexOf('=')), l.slice(l.indexOf('=') + 1).replace(/^"|"$/g, '')])
);
const sql = postgres(env.DATABASE_URL, { prepare: false, max: 1 });

async function run() {
  const funcs = await sql`
    SELECT routine_name, routine_definition
    FROM information_schema.routines
    WHERE routine_name IN ('get_auth_role', 'sync_privileged_role_to_auth', 'is_admin', 'is_broker', 'provision_individual_seller');
  `;
  for (const f of funcs) {
    console.log(`=== FUNCTION ${f.routine_name} ===\n${f.routine_definition}\n`);
  }
  await sql.end();
}

run().catch(console.error);
