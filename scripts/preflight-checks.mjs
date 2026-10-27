import postgres from 'postgres';
import fs from 'node:fs';

const env = Object.fromEntries(
  fs.readFileSync('.env.local', 'utf8').split(/\r?\n/)
    .filter((l) => /^[A-Z_]+=/.test(l))
    .map((l) => [l.slice(0, l.indexOf('=')), l.slice(l.indexOf('=') + 1).replace(/^"|"$/g, '')])
);
const sql = postgres(env.DATABASE_URL, { prepare: false, max: 1 });

async function run() {
  // Check 1: duplicate (company_id, lot_number)
  const dupCompany = await sql`
    SELECT company_id, lot_number, count(*)
    FROM public.availabilities
    WHERE company_id IS NOT NULL AND lot_number IS NOT NULL
    GROUP BY company_id, lot_number
    HAVING count(*) > 1;
  `;
  console.log('Duplicate company lot numbers:', dupCompany.length);

  // Check 2: duplicate (seller_user_id, lot_number)
  const dupIndividual = await sql`
    SELECT seller_user_id, lot_number, count(*)
    FROM public.availabilities
    WHERE seller_user_id IS NOT NULL AND lot_number IS NOT NULL
    GROUP BY seller_user_id, lot_number
    HAVING count(*) > 1;
  `;
  console.log('Duplicate individual lot numbers:', dupIndividual.length);

  // Check 3: owner check violations
  const invalidOwners = await sql`
    SELECT id, company_id, seller_user_id
    FROM public.availabilities
    WHERE (company_id IS NULL AND seller_user_id IS NULL)
       OR (company_id IS NOT NULL AND seller_user_id IS NOT NULL);
  `;
  console.log('Invalid owners count:', invalidOwners.length);

  // Check 4: broker_id validity
  const invalidBrokers = await sql`
    SELECT a.id, a.broker_id, u.role, u.status
    FROM public.availabilities a
    LEFT JOIN public.users u ON a.broker_id = u.id
    WHERE a.broker_id IS NOT NULL
      AND (u.id IS NULL OR lower(u.role) != 'broker' OR u.status IS NOT TRUE);
  `;
  console.log('Invalid broker assignments count:', invalidBrokers.length);

  // Check 5: inspect existing availabilities rows
  const rows = await sql`
    SELECT id, company_id, seller_user_id, lot_number, broker_id, price, status, visibility
    FROM public.availabilities;
  `;
  console.log('Existing availabilities:');
  for (const r of rows) {
    console.log(r);
  }

  await sql.end();
}

run().catch(console.error);
