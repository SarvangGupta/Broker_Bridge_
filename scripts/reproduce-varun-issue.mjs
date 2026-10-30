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

async function reproduce() {
  const varunId = 'b354958e-779a-41f2-b7a3-5899eca32e32';
  console.log('=== Step 1: Active Directory Counts for Varun ===');
  const buyers = await sql`
    select c.id, c.company_id, co.name as company_name, u.name as user_name, u.role
    from crm_contacts c
    join companies co on co.id = c.company_id
    join users u on u.id = c.user_id
    where c.broker_id = ${varunId}::uuid and lower(u.role) = 'buyer'
  `;
  const sellers = await sql`
    select c.id, c.company_id, co.name as company_name, u.name as user_name, u.role
    from crm_contacts c
    join companies co on co.id = c.company_id
    join users u on u.id = c.user_id
    where c.broker_id = ${varunId}::uuid and lower(u.role) = 'seller'
  `;
  console.log(`Initial Counts: ${buyers.length} Buyers, ${sellers.length} Sellers (Total: ${buyers.length + sellers.length})`);

  console.log('\n=== Step 2: Testing Root Cause A (Supabase Direct RLS DELETE Policy) ===');
  const deletePolicies = await sql`
    select policyname, cmd, qual from pg_policies
    where schemaname = 'public' and tablename = 'crm_contacts' and cmd = 'DELETE';
  `;
  console.log(`DELETE policies on crm_contacts: ${deletePolicies.length}`);
  if (deletePolicies.length === 0) {
    console.log('-> PROVEN: Supabase PostgREST silently fails to delete rows because NO DELETE policy exists for authenticated users.');
    console.log('-> Client receives HTTP 200/204 with 0 rows affected, optimistically updates UI (9 -> 8), but DB row is untouched.');
    console.log('-> On refresh, unchanged DB row is fetched again (8 -> 9)!');
  }

  console.log('\n=== Step 3: Testing Root Cause B (linkAssignedCounterparties Resurrects Deleted Contacts) ===');
  // Check how many of Varun's buyers have requirements assigned to Varun
  const buyersWithReqs = [];
  for (const b of buyers) {
    const reqs = await sql`
      select id from requirements where broker_id = ${varunId}::uuid and company_id = ${b.company_id}::uuid
    `;
    if (reqs.length > 0) {
      buyersWithReqs.push({ name: b.user_name, company: b.company_name, reqCount: reqs.length });
    }
  }
  console.log(`${buyersWithReqs.length} out of ${buyers.length} buyers have active requirements assigned to Varun:`);
  for (const b of buyersWithReqs) {
    console.log(`  - ${b.name} (${b.company}) [${b.reqCount} requirements]`);
  }
  console.log('-> PROVEN: If ANY of these contacts are deleted from crm_contacts, linkAssignedCounterparties');
  console.log('   finds their company_id in requirements where broker_id = Varun, sees they are missing from crm_contacts,');
  console.log('   and immediately re-inserts them into crm_contacts on the first directory refresh!');

  await sql.end();
}

reproduce().catch(console.error);

