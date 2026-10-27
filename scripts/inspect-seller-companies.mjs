import postgres from 'postgres';
import fs from 'node:fs';

const env = Object.fromEntries(
  fs.readFileSync('.env.local', 'utf8').split(/\r?\n/)
    .filter((l) => /^[A-Z_]+=/.test(l))
    .map((l) => [l.slice(0, l.indexOf('=')), l.slice(l.indexOf('=') + 1).replace(/^"|"$/g, '')])
);

const sql = postgres(env.DATABASE_URL, { prepare: false, max: 1 });

async function run() {
  const companies = await sql`
    SELECT c.id, c.name, c.gst, c.state_id, c.district_id,
           s.name as state_name, d.name as district_name
    FROM public.companies c
    LEFT JOIN public.master_states s ON c.state_id = s.id::text
    LEFT JOIN public.master_districts d ON c.district_id = d.id::text
    WHERE c.id::text IN ('b543d6c6-85a7-4f13-a048-1967c05bb71e', '4f3d7584-ebc8-4a92-82a5-b5d0b02079e7');
  `;
  console.log('Seller Companies:');
  console.log(JSON.stringify(companies, null, 2));

  // Check existing lots for Priya's company or Neha's company
  const lots = await sql`
    SELECT id, lot_number, company_id, seller_user_id, status
    FROM public.availabilities
    WHERE company_id IN ('b543d6c6-85a7-4f13-a048-1967c05bb71e', '4f3d7584-ebc8-4a92-82a5-b5d0b02079e7');
  `;
  console.log('Existing Lots for Priya / Neha companies:', lots.length);

  await sql.end();
}

run();
