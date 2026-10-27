import postgres from 'postgres';
import fs from 'node:fs';

const env = Object.fromEntries(
  fs.readFileSync('.env.local', 'utf8').split(/\r?\n/)
    .filter((l) => /^[A-Z_]+=/.test(l))
    .map((l) => [l.slice(0, l.indexOf('=')), l.slice(l.indexOf('=') + 1).replace(/^"|"$/g, '')])
);

const sql = postgres(env.DATABASE_URL, { prepare: false, max: 1 });

async function run() {
  const commodities = await sql`
    SELECT c.id, c.name, c.code, count(g.id) as grade_count
    FROM public.master_commodities c
    LEFT JOIN public.master_grades g ON g.commodity_id = c.id
    GROUP BY c.id, c.name, c.code
    ORDER BY c.name;
  `;
  console.log('Master Commodities count:', commodities.length);
  for (const c of commodities.slice(0, 10)) {
    console.log(`- ${c.name} (${c.code}): ${c.id}, grades: ${c.grade_count}`);
  }

  const units = await sql`
    SELECT id, name, symbol
    FROM public.master_units;
  `;
  console.log('\nMaster Units:');
  for (const u of units) {
    console.log(`- ${u.name} (${u.symbol}): ${u.id}`);
  }

  await sql.end();
}

run();
