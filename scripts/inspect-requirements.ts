import 'dotenv/config';
import { db } from '../src/server/db';
import { sql } from 'drizzle-orm';

async function main() {
  console.log('=== USERS (BROKERS & BUYERS) ===');
  const userList = await db.execute(sql`
    SELECT id, email, role, name, company_id FROM users
    WHERE role IN ('broker', 'buyer')
    LIMIT 10;
  `);
  console.table(userList);

  console.log('\n=== ROW SECURITY STATUS ===');
  const rlsStatus = await db.execute(sql`
    SELECT relname, relrowsecurity
    FROM pg_class
    WHERE relname IN ('deal_versions', 'negotiation_events', 'quotations', 'requirements', 'deals');
  `);
  console.table(rlsStatus);

  console.log('\n=== QUOTATIONS ===');
  const quoteList = await db.execute(sql`
    SELECT id, requirement_id, broker_id, offered_price, status, created_at
    FROM quotations
    ORDER BY created_at DESC
    LIMIT 10;
  `);
  console.table(quoteList);
}

main().then(() => process.exit(0)).catch((err) => {
  console.error(err);
  process.exit(1);
});
