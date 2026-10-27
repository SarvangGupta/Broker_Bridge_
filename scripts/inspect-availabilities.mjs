import postgres from 'postgres';
import fs from 'node:fs';

const env = Object.fromEntries(
  fs.readFileSync('.env.local', 'utf8').split(/\r?\n/)
    .filter((l) => /^[A-Z_]+=/.test(l))
    .map((l) => [l.slice(0, l.indexOf('=')), l.slice(l.indexOf('=') + 1).replace(/^"|"$/g, '')])
);
const sql = postgres(env.DATABASE_URL, { prepare: false, max: 1 });

async function run() {
  const cols = await sql`
    SELECT column_name, is_nullable, data_type
    FROM information_schema.columns
    WHERE table_name = 'availabilities' AND table_schema = 'public'
    ORDER BY ordinal_position;
  `;
  console.log('Columns:');
  for (const c of cols) {
    console.log(`  ${c.column_name}: nullable=${c.is_nullable}, type=${c.data_type}`);
  }

  const cons = await sql`
    SELECT conname, contype, pg_get_constraintdef(c.oid) as def
    FROM pg_constraint c
    JOIN pg_class t ON c.conrelid = t.oid
    WHERE t.relname = 'availabilities';
  `;
  console.log('\nConstraints:');
  for (const c of cons) {
    console.log(`  ${c.conname} (${c.contype}): ${c.def}`);
  }

  const idxs = await sql`
    SELECT indexname, indexdef
    FROM pg_indexes
    WHERE tablename = 'availabilities' AND schemaname = 'public';
  `;
  console.log('\nIndexes:');
  for (const i of idxs) {
    console.log(`  ${i.indexname}: ${i.indexdef}`);
  }

  await sql.end();
}

run().catch(console.error);
