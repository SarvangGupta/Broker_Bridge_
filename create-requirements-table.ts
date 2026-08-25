import postgres from 'postgres';
require('dotenv').config({ path: '.env.local' });

async function createTable() {
  if (!process.env.DATABASE_URL) {
    throw new Error("DATABASE_URL environment variable is required.");
  }
  const sql = postgres(process.env.DATABASE_URL);
  try {
    await sql`
      CREATE TABLE IF NOT EXISTS requirements (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        company_id UUID NOT NULL REFERENCES companies(id),
        commodity_id UUID NOT NULL REFERENCES master_commodities(id),
        grade_id UUID NOT NULL REFERENCES master_grades(id),
        quantity DOUBLE PRECISION NOT NULL,
        unit_id UUID NOT NULL REFERENCES master_units(id),
        target_price DOUBLE PRECISION NOT NULL,
        delivery_terms_id TEXT NOT NULL,
        target_date TIMESTAMP NOT NULL,
        status TEXT NOT NULL DEFAULT 'Open',
        created_at TIMESTAMP NOT NULL DEFAULT NOW()
      );
    `;
    console.log("Table 'requirements' created successfully.");
  } catch (e: any) {
    console.error("Error creating table:", e);
  }
  process.exit(0);
}
createTable();
