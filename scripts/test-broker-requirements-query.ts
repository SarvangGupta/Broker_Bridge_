import 'dotenv/config';
import { db } from '../src/server/db';
import { sql } from 'drizzle-orm';

async function main() {
  const brokerId = 'b354958e-779a-41f2-b7a3-5899eca32e32'; // Varun
  console.log('Querying requirements joined with master tables for broker_id: ' + brokerId);

  const res = await db.execute(sql`
    SELECT
      r.id,
      r.quantity,
      r.fulfilled_quantity,
      r.target_price,
      r.delivery_terms_id,
      r.target_date,
      r.status,
      r.created_at,
      r.company_id,
      r.commodity_id,
      r.grade_id,
      r.unit_id,
      c.id as buyer_company_id,
      c.name as buyer_company_name,
      c.is_verified as buyer_company_verified,
      c.trust_score as buyer_trust_score,
      comm.id as commodity_id_from_comm,
      comm.name as commodity_name,
      comm.code as commodity_code,
      g.id as grade_id_from_grade,
      g.grade_name,
      g.parameters as quality_parameters,
      u.id as unit_id_from_unit,
      u.name as unit_name,
      u.symbol as unit_symbol
    FROM requirements r
    INNER JOIN companies c ON r.company_id = c.id
    INNER JOIN master_commodities comm ON r.commodity_id = comm.id
    LEFT JOIN master_grades g ON r.grade_id = g.id
    LEFT JOIN master_units u ON r.unit_id = u.id
    WHERE r.broker_id = ${brokerId}
    ORDER BY r.created_at DESC;
  `);

  console.log('Total requirements found: ' + res.length);
  for (const item of res) {
    console.log(JSON.stringify(item, null, 2));
  }
}

main().then(() => process.exit(0)).catch((err) => {
  console.error(err);
  process.exit(1);
});
