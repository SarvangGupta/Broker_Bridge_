import 'dotenv/config';
import { db } from '../src/server/db';
import { sql } from 'drizzle-orm';

async function main() {
  for (const t of ['deals', 'deal_versions']) {
    const cols = await db.execute(sql`
      SELECT column_name, data_type, is_nullable, column_default
      FROM information_schema.columns
      WHERE table_name = ${t}
      ORDER BY ordinal_position;
    `);
    console.log(`\n=== TABLE: ${t} ===`);
    console.table(cols);
  }
}

main().then(() => process.exit(0)).catch((err) => {
  console.error(err);
  process.exit(1);
});
