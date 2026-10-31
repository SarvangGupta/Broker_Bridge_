// Offline test of 0055 + 0061 + 0062 + 0063 and their rollbacks in PGlite with minimal stubs.
// Touches no real database.
// Usage: node location_persistence_offline_test.mjs <repoRoot> <pgliteModuleDir>
import fs from 'node:fs';
import path from 'node:path';
import { createRequire } from 'node:module';
import { pathToFileURL } from 'node:url';

const [repoRoot, pgliteDir] = process.argv.slice(2);
const req = createRequire(path.join(pgliteDir, 'package.json'));
const { PGlite } = await import(pathToFileURL(req.resolve('@electric-sql/pglite')).href);
const db = new PGlite();
const file = (n) => fs.readFileSync(path.join(repoRoot, 'supabase/proposed', n), 'utf8');

const A = '00000000-0000-4000-8000-00000000000a'; // broker A
const B = '00000000-0000-4000-8000-00000000000b'; // broker B
const C1 = '00000000-0000-4000-8000-0000000000c1'; // A's active contact
const C2 = '00000000-0000-4000-8000-0000000000c2'; // A has no contact
const C3 = '00000000-0000-4000-8000-0000000000c3'; // A removed this contact

await db.exec(`
  CREATE ROLE authenticated NOLOGIN; CREATE ROLE anon NOLOGIN;
  CREATE SCHEMA auth;
  CREATE FUNCTION auth.uid() RETURNS uuid LANGUAGE sql STABLE
    AS $$ SELECT nullif(current_setting('test.uid', true), '')::uuid $$;
  GRANT USAGE ON SCHEMA auth TO authenticated;
  CREATE TABLE companies (id uuid PRIMARY KEY, name text);
  CREATE TABLE users (id uuid PRIMARY KEY, company_id uuid, role text, status boolean DEFAULT true);
  CREATE TABLE crm_contacts (id uuid PRIMARY KEY DEFAULT gen_random_uuid(), broker_id uuid, company_id uuid, removed_at timestamptz);
  CREATE TABLE deals (id uuid PRIMARY KEY DEFAULT gen_random_uuid(), broker_id uuid, buyer_id uuid);
  CREATE TABLE notifications (id uuid PRIMARY KEY DEFAULT gen_random_uuid(), user_id uuid, company_id uuid, channel text,
    event_type text, title text, message text, context_reason text, action_label text, action_url text, payload jsonb,
    delivery_status text, idempotency_key text UNIQUE, is_read boolean, created_at timestamptz);
  CREATE TABLE requirements (id uuid PRIMARY KEY DEFAULT gen_random_uuid(), company_id uuid);
  CREATE TABLE availabilities (id uuid PRIMARY KEY DEFAULT gen_random_uuid(), company_id uuid);
  CREATE FUNCTION public.is_admin() RETURNS boolean LANGUAGE sql STABLE AS $$ SELECT false $$;
  GRANT SELECT ON crm_contacts, users, deals TO authenticated;
  GRANT SELECT, INSERT ON requirements, availabilities TO authenticated;
  INSERT INTO companies VALUES ('${C1}','C1'),('${C2}','C2'),('${C3}','C3');
  INSERT INTO users (id, role) VALUES ('${A}','broker'),('${B}','broker');
  INSERT INTO crm_contacts (broker_id, company_id, removed_at) VALUES
    ('${A}','${C1}',NULL),('${A}','${C3}',now());
`);
await db.exec(file('0055_company_warehouses.sql'));
await db.exec(file('0061_trade_location_references.sql'));
await db.exec(file('0062_broker_add_counterparty_location.sql'));
await db.exec(file('0063_broker_edit_counterparty_location.sql'));

let pass = 0;
let fail = 0;
const check = (name, ok, extra = '') => {
  ok ? pass++ : fail++;
  console.log(`${ok ? 'PASS' : 'FAIL'} ${name} ${ok ? '' : extra}`);
};
const asUser = async (uid, sql, params = []) => {
  await db.exec(`SET test.uid = '${uid}'; SET ROLE authenticated;`);
  try {
    return await db.query(sql, params);
  } finally {
    await db.exec('RESET ROLE;');
  }
};
const denied = async (uid, sql, params) => {
  try {
    await asUser(uid, sql, params);
    return false;
  } catch {
    return true;
  }
};
const insertWh = `INSERT INTO company_warehouses (company_id, created_by, name, address_line, state_id, district_id, pin_code)
  VALUES ($1, $2, $3, 'Road 1', 'st', 'd', '324005') RETURNING id`;

const id = (await asUser(A, insertWh, [C1, A, 'Yard'])).rows[0].id;
check('broker adds a location for an active contact', !!id);
check('new location is readable after refresh', (await asUser(A, 'SELECT id FROM company_warehouses WHERE company_id = $1', [C1])).rows.length === 1);
check('adding for a non-contact is denied', await denied(A, insertWh, [C2, A, 'X']));
check('adding for a removed contact is denied', await denied(A, insertWh, [C3, A, 'X']));
check('adding as another user is denied', await denied(A, insertWh, [C1, B, 'X']));
check('another broker cannot add for that company', await denied(B, insertWh, [C1, B, 'X']));

const snapshot = 'Yard, Road 1 - 324005, Kota, Rajasthan';
const reqId = (await asUser(A, `INSERT INTO requirements (company_id, delivery_location_id, delivery_location_snapshot) VALUES ($1,$2,$3) RETURNING id`, [C1, id, snapshot])).rows[0].id;
const availId = (await asUser(A, `INSERT INTO availabilities (company_id, loading_location_id, loading_location_snapshot) VALUES ($1,$2,$3) RETURNING id`, [C1, id, snapshot])).rows[0].id;
check('requirement stores the location id and snapshot', !!reqId);
check('offer stores the location id and snapshot', !!availId);

const edited = await asUser(A, `UPDATE company_warehouses SET address_line = 'Road 2' WHERE id = $1 RETURNING id`, [id]);
check('broker edit updates that record', edited.rows.length === 1 && edited.rows[0].id === id);
check('edit creates no duplicate', (await db.query('SELECT 1 FROM company_warehouses')).rows.length === 1);
check('edit persisted', (await db.query('SELECT address_line a FROM company_warehouses WHERE id = $1', [id])).rows[0].a === 'Road 2');
const reqAfter = (await db.query('SELECT delivery_location_snapshot s, delivery_location_id i FROM requirements WHERE id = $1', [reqId])).rows[0];
check('edit leaves the requirement snapshot unchanged', reqAfter.s === snapshot && reqAfter.i === id);
const avAfter = (await db.query('SELECT loading_location_snapshot s FROM availabilities WHERE id = $1', [availId])).rows[0];
check('edit leaves the offer snapshot unchanged', avAfter.s === snapshot);

check('a broker with no contact updates nothing', (await asUser(B, `UPDATE company_warehouses SET name = 'Hack' WHERE id = $1 RETURNING id`, [id])).rows.length === 0);
check('moving a location to a non-contact company is denied', await denied(A, 'UPDATE company_warehouses SET company_id = $1 WHERE id = $2', [C2, id]));
check('broker delete removes nothing', (await asUser(A, 'DELETE FROM company_warehouses WHERE id = $1 RETURNING id', [id])).rows.length === 0);
check('bad PIN is rejected', await denied(A, `INSERT INTO company_warehouses (company_id, created_by, name, address_line, pin_code) VALUES ($1,$2,'Y','R','123')`, [C1, A]));

await db.exec("UPDATE crm_contacts SET removed_at = now() WHERE company_id = '" + C1 + "'");
check('edit stops after the contact is removed', (await asUser(A, `UPDATE company_warehouses SET name = 'Late' WHERE id = $1 RETURNING id`, [id])).rows.length === 0);

await db.exec(file('rollback_0063.sql'));
await db.exec(file('rollback_0062.sql'));
await db.exec(file('rollback_0061.sql'));
const left = await db.query(`SELECT column_name FROM information_schema.columns WHERE table_name IN ('requirements','availabilities') AND column_name LIKE '%location%'`);
const pol = await db.query(`SELECT policyname FROM pg_policies WHERE policyname LIKE 'company_warehouses_broker%'`);
check('rollbacks remove the columns and policies', left.rows.length === 0 && pol.rows.length === 0);

console.log(`\n${pass} passed, ${fail} failed`);
process.exit(fail ? 1 : 0);
