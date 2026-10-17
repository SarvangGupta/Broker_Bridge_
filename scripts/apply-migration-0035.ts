import postgres from 'postgres';
import fs from 'fs';
import path from 'path';
require('dotenv').config({ path: '.env.local' });

async function applyMigration() {
  if (!process.env.DATABASE_URL) {
    throw new Error('DATABASE_URL is not set in environment.');
  }

  const sql = postgres(process.env.DATABASE_URL);
  try {
    const migrationSql = fs.readFileSync(
      path.join(__dirname, '../supabase/migrations/0035_add_requirement_allocations.sql'),
      'utf-8'
    );
    console.log('Applying Migration 0035...');
    await sql.unsafe(migrationSql);
    console.log('Migration 0035 applied successfully!');

    // Verify table creation
    const res = await sql`
      SELECT column_name, data_type 
      FROM information_schema.columns 
      WHERE table_name = 'requirement_allocations'
      ORDER BY ordinal_position
    `;
    console.log('Table columns created:', res.map(r => `${r.column_name} (${r.data_type})`));
  } catch (err) {
    console.error('Migration failed:', err);
    process.exit(1);
  } finally {
    await sql.end();
  }
}

applyMigration();
