import postgres from 'postgres';
require('dotenv').config({ path: '.env.local' });

async function test() {
  if (!process.env.DATABASE_URL) {
    throw new Error("DATABASE_URL environment variable is required.");
  }
  const sql = postgres(process.env.DATABASE_URL);
  try {
    const res = await sql`SELECT table_name FROM information_schema.tables WHERE table_schema = 'public'`;
    console.log(res);
  } catch (e: any) {
    console.error("Error:", e);
  }
  process.exit(0);
}
test();
