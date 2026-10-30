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

async function check() {
  const varunId = 'b354958e-779a-41f2-b7a3-5899eca32e32';
  const contacts = await sql`
    select c.id, c.company_id, c.user_id, co.name as company_name, u.name as user_name, u.role
    from crm_contacts c
    join companies co on co.id = c.company_id
    join users u on u.id = c.user_id
    where c.broker_id = ${varunId}::uuid
    order by c.created_at desc
  `;
  console.log(`Varun CRM Contacts (${contacts.length}):`);
  for (const c of contacts) {
    const reqs = await sql`select id, commodity_id, status from requirements where broker_id = ${varunId}::uuid and company_id = ${c.company_id}::uuid`;
    const avails = await sql`select id, commodity_id, status from availabilities where broker_id = ${varunId}::uuid and company_id = ${c.company_id}::uuid`;
    console.log(`- Contact [${c.id}] ${c.user_name} (${c.company_name}) [${c.role}]: ${reqs.length} reqs, ${avails.length} avails`);
  }
  await sql.end();
}
check().catch(console.error);

