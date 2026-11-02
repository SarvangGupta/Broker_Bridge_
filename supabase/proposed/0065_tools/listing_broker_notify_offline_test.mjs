// RB-SELLER-COMMODITY-BROKER-NOTIFY-01 — offline tests for proposed 0065.
//
// Builds a stub of the live tables involved (users, companies, master data,
// availabilities with the reconciled 0048 RLS policies, notifications with its
// unique idempotency index) in PGlite, applies 0065, and runs every case as a
// real `authenticated` session (SET ROLE + JWT sub claim), so RLS, definer
// rights and the trigger execute for real.
//
// NOT covered (needs a Supabase project): PostgREST, Auth sign-in, the real
// production column set, Realtime, and any push delivery (none exists).
//
// Usage: node listing_broker_notify_offline_test.mjs <repoRoot> <pgliteModuleDir>
import fs from 'node:fs';
import path from 'node:path';
import { createRequire } from 'node:module';
import { pathToFileURL } from 'node:url';

const [repoRoot, pgliteDir] = process.argv.slice(2);
process.on('unhandledRejection', (e) => { console.log(`FATAL ${e?.code ?? ''} ${e?.message ?? e}`); process.exit(2); });
const req = createRequire(path.join(pgliteDir, 'package.json'));
const { PGlite } = await import(pathToFileURL(req.resolve('@electric-sql/pglite')).href);
const db = new PGlite();
const proposed = (f) => fs.readFileSync(path.join(repoRoot, 'supabase', 'proposed', f), 'utf8');

const results = [];
const check = (name, ok, detail = '') => {
  results.push({ name, ok });
  console.log(`${ok ? 'PASS' : 'FAIL'}  ${name}${detail ? '  — ' + detail : ''}`);
};
const q = async (sql, params) => (await db.query(sql, params)).rows;

async function as(uid, sql, params) {
  await db.exec(`SET ROLE authenticated; SELECT set_config('request.jwt.claim.sub', '${uid}', false);`);
  try {
    const r = await db.query(sql, params);
    return { ok: true, rows: r.rows, affected: r.affectedRows ?? r.rows.length };
  } catch (e) {
    return { ok: false, code: e.code, msg: e.message.split('\n')[0] };
  } finally {
    await db.exec(`RESET ROLE; SELECT set_config('request.jwt.claim.sub', '', false);`);
  }
}

// --- ids ---
const CO_A = '00000000-0000-0000-0000-00000000000a';   // seller company A
const CO_B = '00000000-0000-0000-0000-00000000000b';   // seller company B
const CO_BR = '00000000-0000-0000-0000-0000000000b1';  // broker 1 firm
const CO_BR2 = '00000000-0000-0000-0000-0000000000b2'; // broker 2 firm
const SELLER_A = '10000000-0000-0000-0000-00000000000a';
const SELLER_B = '10000000-0000-0000-0000-00000000000b';
const SELLER_IND = '10000000-0000-0000-0000-0000000000c1';
const BROKER_1 = '20000000-0000-0000-0000-000000000001';
const BROKER_2 = '20000000-0000-0000-0000-000000000002';
const BROKER_X = '20000000-0000-0000-0000-000000000009'; // never assigned
const BROKER_OFF = '20000000-0000-0000-0000-000000000003'; // inactive
const ADMIN = '30000000-0000-0000-0000-000000000001';
const COMM = '40000000-0000-0000-0000-000000000001';
const GRADE = '40000000-0000-0000-0000-000000000002';
const GRADE2 = '40000000-0000-0000-0000-000000000003';
const UNIT = '40000000-0000-0000-0000-000000000004';
const ST = '40000000-0000-0000-0000-000000000005';
const DI = '40000000-0000-0000-0000-000000000006';
const DI2 = '40000000-0000-0000-0000-000000000007';

// --- 1. Platform stubs + schema (mirrors migrations 0004/0009/0020/0017/0030/0048) ---
await db.exec(`
  CREATE ROLE anon; CREATE ROLE authenticated;
  CREATE SCHEMA auth;
  CREATE FUNCTION auth.uid() RETURNS uuid LANGUAGE sql STABLE AS
    $$ SELECT NULLIF(current_setting('request.jwt.claim.sub', true), '')::uuid $$;
  GRANT USAGE ON SCHEMA auth TO authenticated, anon;
  GRANT EXECUTE ON FUNCTION auth.uid() TO authenticated, anon;

  CREATE TABLE public.companies (id uuid PRIMARY KEY, name text NOT NULL);
  CREATE TABLE public.users (id uuid PRIMARY KEY, name text, role text, status boolean DEFAULT true,
    company_id uuid REFERENCES public.companies(id));
  CREATE TABLE public.master_commodities (id uuid PRIMARY KEY, name text);
  CREATE TABLE public.master_units (id uuid PRIMARY KEY, symbol text);

  CREATE FUNCTION public.is_admin() RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER AS
    $$ SELECT EXISTS (SELECT 1 FROM public.users WHERE id = auth.uid() AND role = 'admin') $$;
  CREATE FUNCTION public.is_broker() RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER AS
    $$ SELECT EXISTS (SELECT 1 FROM public.users WHERE id = auth.uid() AND role = 'broker') $$;

  CREATE TABLE public.availabilities (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id uuid, seller_user_id uuid REFERENCES public.users(id),
    commodity_id uuid NOT NULL, grade_id uuid NOT NULL, quantity integer NOT NULL,
    unit_id uuid NOT NULL, price numeric NOT NULL, state_id uuid NOT NULL, district_id uuid NOT NULL,
    valid_until timestamp NOT NULL DEFAULT now() + interval '7 days',
    status text NOT NULL DEFAULT 'Open', created_at timestamp NOT NULL DEFAULT now(),
    visibility text NOT NULL DEFAULT 'global', broker_id uuid REFERENCES public.users(id),
    loading_status text NOT NULL DEFAULT 'Not Ready', loading_remarks text, loading_updated_at timestamp,
    lot_number text, total_quantity numeric, available_quantity numeric,
    reserved_quantity numeric NOT NULL DEFAULT 0, sold_quantity numeric NOT NULL DEFAULT 0,
    minimum_order_quantity numeric, asking_price numeric, confidential_minimum_price numeric,
    available_from timestamp NOT NULL DEFAULT now(), version integer NOT NULL DEFAULT 1,
    loading_location_id uuid, loading_location_snapshot text,
    payment_terms text  -- not in production yet; exercises generic classification
  );
  CREATE UNIQUE INDEX availabilities_company_lot_number_key ON public.availabilities (company_id, lot_number)
    WHERE company_id IS NOT NULL AND lot_number IS NOT NULL;

  CREATE TABLE public.notifications (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    company_id uuid REFERENCES public.companies(id) ON DELETE CASCADE,
    channel text NOT NULL DEFAULT 'IN_APP', event_type text NOT NULL, title text NOT NULL,
    message text NOT NULL DEFAULT '', payload jsonb, delivery_status text NOT NULL DEFAULT 'Pending',
    action_url text NOT NULL DEFAULT '/seller', context_reason text NOT NULL DEFAULT '',
    action_label text NOT NULL DEFAULT 'View Details', idempotency_key text,
    is_read boolean NOT NULL DEFAULT false, created_at timestamptz NOT NULL DEFAULT now());
  CREATE UNIQUE INDEX notifications_idempotency_key_idx ON public.notifications (idempotency_key);
  ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;
  CREATE POLICY notif_own ON public.notifications FOR SELECT TO authenticated USING (user_id = auth.uid());
  GRANT SELECT ON public.notifications TO authenticated;
  GRANT SELECT ON public.users, public.companies, public.master_commodities, public.master_units TO authenticated;
  GRANT SELECT, INSERT, UPDATE, DELETE ON public.availabilities TO authenticated;
`);

// 0048's reconciled availabilities policies, verbatim (only the policy section).
const m48 = proposed('0048_reconciled_seller_listings_and_broker_check.sql');
await db.exec('ALTER TABLE public.availabilities ENABLE ROW LEVEL SECURITY;');
await db.exec(m48.slice(m48.indexOf('-- 5A. INSERT POLICY'), m48.lastIndexOf('COMMIT;')));

await db.exec(`
  INSERT INTO public.companies VALUES
    ('${CO_A}','Shree Ganesh Traders'),('${CO_B}','Other Seller Co'),
    ('${CO_BR}','Kota Brokerage'),('${CO_BR2}','Indore Brokerage');
  INSERT INTO public.users VALUES
    ('${SELLER_A}','Seller A','seller',true,'${CO_A}'),
    ('${SELLER_B}','Seller B','seller',true,'${CO_B}'),
    ('${SELLER_IND}','Ramesh Kumar','seller',true,NULL),
    ('${BROKER_1}','Broker One','broker',true,'${CO_BR}'),
    ('${BROKER_2}','Broker Two','broker',true,'${CO_BR2}'),
    ('${BROKER_X}','Broker X','broker',true,'${CO_BR}'),
    ('${BROKER_OFF}','Broker Off','broker',true,'${CO_BR}'),
    ('${ADMIN}','Admin','admin',true,NULL);
  INSERT INTO public.master_commodities VALUES ('${COMM}','Yellow Maize');
  INSERT INTO public.master_units VALUES ('${UNIT}','MT');
`);

// --- 2. Apply the migration under test ---
await db.exec(proposed('0065_seller_listing_broker_notifications.sql'));
check('0065 applies cleanly', true);

const notes = (uid) => q(`SELECT * FROM public.notifications WHERE user_id = $1 ORDER BY created_at, event_type`, [uid]);
const total = async () => Number((await q('SELECT count(*)::int n FROM public.notifications'))[0].n);
const reset = () => db.exec('DELETE FROM public.notifications');
const insertLot = (uid, { company = CO_A, seller = null, broker = BROKER_1, lot = 'LOT-123' } = {}) => as(uid, `
  INSERT INTO public.availabilities (company_id, seller_user_id, commodity_id, grade_id, quantity, unit_id, price,
    state_id, district_id, lot_number, total_quantity, available_quantity, asking_price, confidential_minimum_price, broker_id)
  VALUES ($1,$2,'${COMM}','${GRADE}',100,'${UNIT}',5850,'${ST}','${DI}',$3,100,100,5850,5700,$4) RETURNING id`,
  [company, seller, lot, broker]);
const upd = (uid, id, set, params = []) => as(uid, `UPDATE public.availabilities SET ${set} WHERE id = '${id}' RETURNING id`, params);

// T1 new listing -> assigned broker
let r = await insertLot(SELLER_A);
const LOT = r.rows?.[0]?.id;
let n = await notes(BROKER_1);
check('T1 new listing notifies its assigned broker', r.ok && n.length === 1 && n[0].event_type === 'AVAILABILITY_CREATED'
  && n[0].title === 'New commodity listing', JSON.stringify(n.map((x) => x.message)));
check('T1 content: commodity, lot, seller, qty, price', /Shree Ganesh Traders listed Yellow Maize — LOT-123: 100 MT at ₹5850\/MT/.test(n[0]?.message ?? ''), n[0]?.message);
check('T1 tenant: notification company is the broker firm', n[0]?.company_id === CO_BR);
check('T1 payload never carries the confidential floor price', !JSON.stringify(n[0]?.payload).includes('5700')
  && !JSON.stringify(n[0]?.payload).includes('confidential'));
check('T14 unassigned broker receives nothing on create', (await notes(BROKER_X)).length === 0 && (await notes(BROKER_2)).length === 0);

// T3 no broker
await reset();
r = await insertLot(SELLER_A, { broker: null, lot: 'LOT-NOBRK' });
const LOT_NB = r.rows?.[0]?.id;
check('T3 listing with no assigned broker creates no notification', r.ok && (await total()) === 0);
r = await upd(SELLER_A, LOT_NB, `asking_price = 6000, price = 6000`);
check('T3 updating an unassigned listing creates no notification', r.ok && (await total()) === 0);

// T5 price
await reset();
r = await upd(SELLER_A, LOT, `asking_price = 6100, price = 6100`);
n = await notes(BROKER_1);
check('T5 price change notifies the assigned broker', n.length === 1 && n[0].event_type === 'AVAILABILITY_PRICE_UPDATED'
  && n[0].title === 'Commodity price updated' && /updated the price for Yellow Maize — LOT-123 to ₹6100\/MT/.test(n[0].message), n[0]?.message);
check('T5 changed fields listed in payload', JSON.stringify(n[0]?.payload?.changedFields?.sort()) === '["asking_price","price"]');

// T6 quantity
await reset();
await upd(SELLER_A, LOT, `available_quantity = 80, total_quantity = 80, quantity = 80`);
n = await notes(BROKER_1);
check('T6 quantity change notifies the assigned broker', n.length === 1 && n[0].event_type === 'AVAILABILITY_QUANTITY_UPDATED'
  && /quantity for Yellow Maize — LOT-123 to 80 MT/.test(n[0].message), n[0]?.message);

// T7 warehouse / dispatch location
await reset();
await upd(SELLER_A, LOT, `district_id = '${DI2}', loading_location_snapshot = 'Kota Warehouse 2'`);
n = await notes(BROKER_1);
check('T7 dispatch location change notifies the assigned broker', n.length === 1
  && n[0].event_type === 'AVAILABILITY_LOCATION_UPDATED' && n[0].title === 'Dispatch location updated');

// T8 payment terms
await reset();
await upd(SELLER_A, LOT, `payment_terms = '50% advance'`);
n = await notes(BROKER_1);
check('T8 payment-term change notifies the assigned broker', n.length === 1
  && n[0].event_type === 'AVAILABILITY_PAYMENT_TERMS_UPDATED' && n[0].title === 'Payment terms updated');

// Quality
await reset();
await upd(SELLER_A, LOT, `grade_id = '${GRADE2}'`);
n = await notes(BROKER_1);
check('Quality/grade change notifies the assigned broker', n.length === 1 && n[0].event_type === 'AVAILABILITY_QUALITY_UPDATED');

// T4 general edit (several categories)
await reset();
await upd(SELLER_A, LOT, `asking_price = 6200, price = 6200, loading_remarks = 'Bagged'`);
n = await notes(BROKER_1);
check('T4 multi-field edit notifies once with all categories', n.length === 1 && n[0].event_type === 'AVAILABILITY_UPDATED'
  && n[0].title === 'Commodity listing updated' && /updated price, other details for Yellow Maize — LOT-123/.test(n[0].message), n[0]?.message);

// T13 repeated identical request
await reset();
await upd(SELLER_A, LOT, `asking_price = 6200, price = 6200`);
check('T13/T12 identical retry or no-op save creates no notification', (await total()) === 0);
r = await insertLot(SELLER_A); // same lot number again
check('T13 duplicate create is rejected and notifies nobody', !r.ok && r.code === '23505' && (await total()) === 0, r.code);
await db.exec(`DO $$ BEGIN
  UPDATE public.availabilities SET loading_remarks = 'x1' WHERE id = '${LOT}';
  UPDATE public.availabilities SET loading_remarks = 'x2' WHERE id = '${LOT}';
END $$`);
check('T13 idempotency: superuser (non-seller) writes do not notify', (await total()) === 0);

// T11 failed mutations
await reset();
r = await upd(SELLER_B, LOT, `asking_price = 1`);
check('T11/T15 other company seller cannot change the lot and nothing is sent', r.ok && r.affected === 0 && (await total()) === 0);
r = await insertLot(SELLER_A, { broker: BROKER_OFF, lot: 'LOT-BADBRK' });
await db.exec(`UPDATE public.users SET status = false WHERE id = '${BROKER_OFF}'`);
r = await insertLot(SELLER_A, { broker: BROKER_OFF, lot: 'LOT-BADBRK2' });
check('T11 RLS-rejected create (inactive broker) sends nothing', !r.ok && (await notes(BROKER_OFF)).length === 1 /* only the earlier, valid one */);
await reset();
await db.exec(`BEGIN; SET LOCAL ROLE authenticated; SELECT set_config('request.jwt.claim.sub', '${SELLER_A}', true);
  UPDATE public.availabilities SET asking_price = 9999 WHERE id = '${LOT}'; ROLLBACK;`);
check('T11 rolled-back save leaves no notification', (await total()) === 0);
r = await as(SELLER_A, `UPDATE public.availabilities SET asking_price = 'abc' WHERE id = '${LOT}'`);
check('T11 invalid value is rejected and sends nothing', !r.ok && (await total()) === 0);

// T15 isolation: other-company seller insert claiming company A
r = await insertLot(SELLER_B, { company: CO_A, lot: 'LOT-SPOOF' });
check('T15 cross-company create is rejected by RLS, nothing sent', !r.ok && (await total()) === 0, r.code);
// Broker/admin writes are not seller actions
await upd(BROKER_1, LOT, `loading_remarks = 'broker note'`);
await upd(ADMIN, LOT, `reserved_quantity = 10, loading_remarks = 'admin note'`);
check('Broker and admin edits do not notify (only seller actions do)', (await total()) === 0);
// T15: seller A cannot read broker notifications
r = await as(SELLER_A, `SELECT count(*)::int n FROM public.notifications`);
await upd(SELLER_A, LOT, `loading_remarks = 'seller note'`);
r = await as(SELLER_A, `SELECT count(*)::int n FROM public.notifications`);
check('T15 seller cannot read the broker notification', r.ok && r.rows[0].n === 0);
r = await as(BROKER_X, `SELECT count(*)::int n FROM public.notifications`);
check('T14/T15 another broker cannot read it either', r.ok && r.rows[0].n === 0);

// Reassignment
await reset();
await upd(SELLER_A, LOT, `broker_id = '${BROKER_2}'`);
n = await notes(BROKER_2);
check('Reassignment notifies the newly assigned broker', n.length === 1 && n[0].event_type === 'AVAILABILITY_ASSIGNED'
  && n[0].company_id === CO_BR2, n[0]?.message);
check('Reassignment does not notify the previous broker', (await notes(BROKER_1)).length === 0);
await reset();
await upd(SELLER_A, LOT, `asking_price = 6300, price = 6300`);
check('After reassignment only the new broker hears updates', (await notes(BROKER_1)).length === 0 && (await notes(BROKER_2)).length === 1);

// T9 status
await reset();
await upd(SELLER_A, LOT, `status = 'Fulfilled'`);
n = await notes(BROKER_2);
check('T9 status change notifies the assigned broker', n.length === 1 && n[0].event_type === 'AVAILABILITY_STATUS_CHANGED'
  && /changed the status of Yellow Maize — LOT-123 to Fulfilled/.test(n[0].message), n[0]?.message);

// T10 removal (status-based, the seller app's Cancel)
await reset();
await upd(SELLER_A, LOT, `status = 'Cancelled'`);
n = await notes(BROKER_2);
check('T10 cancel/withdraw is sent as a removal', n.length === 1 && n[0].event_type === 'AVAILABILITY_REMOVED'
  && n[0].title === 'Commodity listing removed'
  && n[0].message === 'Shree Ganesh Traders has removed Yellow Maize — LOT-123. This listing is no longer available.'
  && n[0].payload.listingRemoved === true, n[0]?.message);

// T10 hard delete path (sellers have no DELETE policy today; a test-only one exercises the trigger)
r = await as(SELLER_A, `DELETE FROM public.availabilities WHERE id = '${LOT}'`);
check('Sellers cannot hard-delete listings today (no DELETE policy)', r.ok && r.affected === 0);
await db.exec(`CREATE POLICY test_only_seller_delete ON public.availabilities FOR DELETE TO authenticated
  USING (company_id IN (SELECT company_id FROM public.users WHERE id = auth.uid()))`);
await reset();
r = await as(SELLER_A, `DELETE FROM public.availabilities WHERE id = '${LOT}'`);
const brokerView = await as(BROKER_2, `SELECT event_type, message, payload, action_url FROM public.notifications`);
check('T10 deletion notification is created from pre-delete data and stays readable', r.ok && brokerView.ok
  && brokerView.rows.length === 1 && brokerView.rows[0].event_type === 'AVAILABILITY_REMOVED'
  && brokerView.rows[0].payload.lotNumber === 'LOT-123' && brokerView.rows[0].payload.commodity === 'Yellow Maize');
check('T16 deep link targets the listing', brokerView.rows?.[0]?.action_url === `/work?tab=1&offerId=${LOT}`
  && brokerView.rows?.[0]?.payload.availabilityId === LOT);
await db.exec('DROP POLICY test_only_seller_delete ON public.availabilities');

// Individual seller
await reset();
r = await insertLot(SELLER_IND, { company: null, seller: SELLER_IND, lot: 'LOT-IND' });
n = await notes(BROKER_1);
check('Individual seller listing notifies its broker with the seller name', r.ok && n.length === 1
  && n[0].message.startsWith('Ramesh Kumar listed Yellow Maize — LOT-IND'), r.msg ?? n[0]?.message);

// Internal helpers not callable through the API
r = await as(SELLER_A, `SELECT public._insert_listing_broker_notification('${BROKER_X}','${SELLER_A}','{"id":"x"}'::jsonb,
  'AVAILABILITY_CREATED','spoof','spoof','{}',null,null,null,null,null,null,false)`);
check('Seller cannot call the insert helper to pick arbitrary recipients', !r.ok && r.code === '42501', r.code);

const failed = results.filter((x) => !x.ok).length;
console.log(`\n${results.length - failed}/${results.length} passed`);
process.exit(failed ? 1 : 0);
