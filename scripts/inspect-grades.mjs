import postgres from 'postgres';
import fs from 'node:fs';

const env = Object.fromEntries(
  fs.readFileSync('.env.local', 'utf8').split(/\r?\n/)
    .filter((l) => /^[A-Z_]+=/.test(l))
    .map((l) => [l.slice(0, l.indexOf('=')), l.slice(l.indexOf('=') + 1).replace(/^"|"$/g, '')])
);

const sql = postgres(env.DATABASE_URL, { prepare: false, max: 1 });

async function run() {
  const rows = await sql`
    SELECT c.id as commodity_id, c.name as commodity_name, g.id as grade_id, g.grade_name
    FROM master_commodities c
    JOIN master_grades g ON g.commodity_id = c.id
    WHERE c.name ILIKE '%Bajra%' OR c.name ILIKE '%Wheat%'
    LIMIT 5;
  `;
  console.log(JSON.stringify(rows, null, 2));
  await sql.end();
}

run();
