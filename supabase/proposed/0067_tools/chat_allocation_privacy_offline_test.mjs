// RM-CHAT-ALLOCATION-PRIVACY-E2E-02 — offline tests for proposed 0067/0068/0069
// on top of 0043 + 0066 (the verified production state).
//
// PGlite, real `authenticated` sessions (SET ROLE + JWT sub). The RLS policies
// on availabilities / requirements / requirement_allocations / users are the
// production definitions read (read-only) on 2026-11-02, verbatim.
// Isolated synthetic fixtures only; nothing here touches any real database.
//
// Usage: node chat_allocation_privacy_offline_test.mjs <repoRoot> <pgliteModuleDir>
import fs from 'node:fs';
import path from 'node:path';
import { createRequire } from 'node:module';
import { pathToFileURL } from 'node:url';

const [repoRoot, pgliteDir] = process.argv.slice(2);
process.on('unhandledRejection', (e) => { console.log(`FATAL ${e?.code ?? ''} ${e?.message ?? e}`); process.exit(2); });
const req = createRequire(path.join(pgliteDir, 'package.json'));
const { PGlite } = await import(pathToFileURL(req.resolve('@electric-sql/pglite')).href);
const db = new PGlite();
const read = (...p) => fs.readFileSync(path.join(repoRoot, 'supabase', ...p), 'utf8');

const results = [];
const check = (name, ok, detail = '') => {
  results.push({ name, ok });
  console.log(`${ok ? 'PASS' : 'FAIL'}  ${name}${detail ? '  — ' + detail : ''}`);
};
const q = async (sql, params) => (await db.query(sql, params)).rows;
async function as(uid, sql, params) {
  await db.exec(`SET ROLE authenticated; SELECT set_config('request.jwt.claim.sub', '${uid}', false);`);
  try {
    return { ok: true, rows: (await db.query(sql, params)).rows };
  } catch (e) {
    return { ok: false, code: e.code, msg: e.message.split('\n')[0] };
  } finally {
    await db.exec(`RESET ROLE; SELECT set_config('request.jwt.claim.sub', '', false);`);
  }
}
let seq = 0;
const cid = () => `00000000-0000-4000-8000-${String(++seq).padStart(12, '0')}`;
const sendCtx = (uid, body, to, { req = null, lot = null, key = cid() } = {}) =>
  as(uid, 'SELECT * FROM public.chat_send_in_context($1,$2,$3,$4,$5)', [body, key, to, req, lot]);
const reply = (uid, body, conv, key = cid()) =>
  as(uid, 'SELECT * FROM public.chat_send_message($1,$2,NULL,$3)', [body, key, conv]);
const hist = async (uid, conv) =>
  (await as(uid, 'SELECT id, sender_id, body FROM public.chat_messages WHERE conversation_id=$1 ORDER BY created_at, id', [conv])).rows ?? [];
const same = (a, b) => a.length === b.length && a.every((m, i) => m.id === b[i].id);
const allocate = (uid, reqId, lotId, qty, price = 5900) =>
  as(uid, 'SELECT * FROM public.broker_allocate_lot($1,$2,$3,$4)', [reqId, lotId, qty, price]);

// --- identities (synthetic) ---
const CO_BUY = 'c0000000-0000-4000-8000-000000000001', CO_SELL = 'c0000000-0000-4000-8000-000000000002';
const CO_BUY2 = 'c0000000-0000-4000-8000-000000000003', CO_SELL2 = 'c0000000-0000-4000-8000-000000000004';
const BROKER = 'b0000000-0000-4000-8000-000000000001';       // assigned broker
const BROKER2 = 'b0000000-0000-4000-8000-000000000002';      // unassigned broker
const BUYER = 'a0000000-0000-4000-8000-000000000001', BUYER2 = 'a0000000-0000-4000-8000-000000000002';
const SELLER = 'd0000000-0000-4000-8000-000000000001', SELLER2 = 'd0000000-0000-4000-8000-000000000002';
const ADMIN = 'e0000000-0000-4000-8000-000000000001';
const NOROW = 'f9999999-0000-4000-8000-000000000000';         // authenticated, no users row
const MAIZE = '11111111-0000-4000-8000-000000000001', WHEAT = '11111111-0000-4000-8000-000000000002';
const MT = '22222222-0000-4000-8000-000000000001', QTL = '22222222-0000-4000-8000-000000000002';
const REQ = '33333333-0000-4000-8000-000000000001';           // BUYER's, assigned to BROKER
const REQ2 = '33333333-0000-4000-8000-000000000002';          // BUYER2's, assigned to BROKER2
const LOT = '44444444-0000-4000-8000-000000000001';           // SELLER's maize, assigned to BROKER
const LOT_FREE = '44444444-0000-4000-8000-000000000002';      // SELLER's maize, unassigned global (Qtl)
const LOT_OTHER = '44444444-0000-4000-8000-000000000003';     // SELLER2's maize, managed by BROKER2
const LOT_WHEAT = '44444444-0000-4000-8000-000000000004';     // unassigned wheat
const LOT_PRIVATE = '44444444-0000-4000-8000-000000000005';   // unassigned, private visibility

await db.exec(`
  CREATE ROLE anon; CREATE ROLE authenticated;
  CREATE SCHEMA auth;
  CREATE FUNCTION auth.uid() RETURNS uuid LANGUAGE sql STABLE AS
    $$ SELECT NULLIF(current_setting('request.jwt.claim.sub', true), '')::uuid $$;
  GRANT USAGE ON SCHEMA auth TO authenticated, anon;
  GRANT EXECUTE ON FUNCTION auth.uid() TO authenticated, anon;
  CREATE PUBLICATION supabase_realtime;

  CREATE TABLE public.companies (id uuid PRIMARY KEY, name text NOT NULL);
  CREATE TABLE public.users (id uuid PRIMARY KEY, name text, mobile text, email text, role text,
    status boolean DEFAULT true, company_id uuid REFERENCES public.companies(id), created_by uuid);
  CREATE FUNCTION public.is_admin() RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER AS
    $$ SELECT EXISTS (SELECT 1 FROM public.users WHERE id = auth.uid() AND role = 'admin') $$;
  CREATE FUNCTION public.is_broker() RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER AS
    $$ SELECT EXISTS (SELECT 1 FROM public.users WHERE id = auth.uid() AND role = 'broker') $$;
  CREATE TABLE public.master_commodities (id uuid PRIMARY KEY, name text);
  CREATE TABLE public.master_units (id uuid PRIMARY KEY, name text, symbol text);
  CREATE TABLE public.crm_contacts (id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    broker_id uuid NOT NULL REFERENCES public.users(id), user_id uuid REFERENCES public.users(id),
    company_id uuid REFERENCES public.companies(id), removed_at timestamptz);
  CREATE TABLE public.requirements (id uuid PRIMARY KEY, company_id uuid NOT NULL, broker_id uuid,
    commodity_id uuid NOT NULL, unit_id uuid NOT NULL, quantity double precision NOT NULL,
    fulfilled_quantity double precision DEFAULT 0, status text NOT NULL DEFAULT 'Open',
    target_date timestamp NOT NULL, visibility text NOT NULL DEFAULT 'global');
  CREATE TABLE public.availabilities (id uuid PRIMARY KEY, company_id uuid, seller_user_id uuid,
    broker_id uuid, commodity_id uuid NOT NULL, unit_id uuid NOT NULL, lot_number text,
    status text NOT NULL DEFAULT 'Open', visibility text NOT NULL DEFAULT 'global',
    valid_until timestamp NOT NULL, available_quantity numeric NOT NULL, reserved_quantity numeric NOT NULL DEFAULT 0,
    version integer NOT NULL DEFAULT 1, asking_price numeric, confidential_minimum_price numeric);
  CREATE TABLE public.requirement_allocations (id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    allocation_reference text NOT NULL UNIQUE, requirement_id uuid NOT NULL, availability_id uuid NOT NULL,
    broker_id uuid NOT NULL, deal_id uuid, allocated_quantity double precision NOT NULL, unit_id uuid NOT NULL,
    price_basis text DEFAULT 'FOR_DESTINATION', allocated_price numeric, status text NOT NULL DEFAULT 'PROPOSED',
    notes text, release_reason text, version integer NOT NULL DEFAULT 1,
    allocated_at timestamptz NOT NULL DEFAULT now(), confirmed_at timestamptz, released_at timestamptz);
  CREATE TABLE public.notifications (id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id uuid NOT NULL, company_id uuid, channel text NOT NULL DEFAULT 'IN_APP', event_type text NOT NULL,
    title text NOT NULL, message text NOT NULL DEFAULT '', payload jsonb, delivery_status text NOT NULL DEFAULT 'Pending',
    action_url text NOT NULL DEFAULT '/', context_reason text NOT NULL DEFAULT '', action_label text NOT NULL DEFAULT 'View',
    idempotency_key text, is_read boolean NOT NULL DEFAULT false, read_at timestamptz, created_at timestamptz NOT NULL DEFAULT now());
  CREATE UNIQUE INDEX notifications_idempotency_key_idx ON public.notifications (idempotency_key);

  -- Production grants (as read): broad table grants, RLS does the gating.
  GRANT SELECT, INSERT, UPDATE ON public.availabilities, public.requirements, public.requirement_allocations,
    public.users, public.companies, public.crm_contacts TO authenticated;
  GRANT SELECT ON public.master_commodities, public.master_units, public.notifications TO authenticated;
  ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;
  CREATE POLICY notifications_select_policy ON public.notifications FOR SELECT TO authenticated
    USING ((user_id = auth.uid()) OR is_admin());

  -- Production policies, verbatim from pg_policies (2026-11-02).
  ALTER TABLE public.availabilities ENABLE ROW LEVEL SECURITY;
  CREATE POLICY availabilities_select_policy ON public.availabilities FOR SELECT TO authenticated USING (
    (broker_id = auth.uid()) OR (visibility = 'global'::text) OR is_admin()
    OR (EXISTS (SELECT 1 FROM users u WHERE u.id = auth.uid() AND lower(u.role) = 'seller'::text AND u.status = true
        AND u.company_id IS NOT NULL AND u.company_id = availabilities.company_id))
    OR ((company_id IS NULL) AND (seller_user_id = auth.uid())));
  CREATE POLICY availabilities_update_policy ON public.availabilities FOR UPDATE TO authenticated USING (
    (broker_id = auth.uid()) OR is_admin()
    OR (EXISTS (SELECT 1 FROM users u WHERE u.id = auth.uid() AND lower(u.role) = 'seller'::text AND u.status = true
        AND u.company_id IS NOT NULL AND u.company_id = availabilities.company_id))
    OR ((company_id IS NULL) AND (seller_user_id = auth.uid())
        AND (EXISTS (SELECT 1 FROM users u WHERE u.id = auth.uid() AND lower(u.role) = 'seller'::text AND u.status = true))))
  WITH CHECK ((broker_id = auth.uid()) OR is_admin()
    OR ((EXISTS (SELECT 1 FROM users u WHERE u.id = auth.uid() AND lower(u.role) = 'seller'::text AND u.status = true
        AND u.company_id IS NOT NULL AND u.company_id = availabilities.company_id)) AND (seller_user_id IS NULL))
    OR ((company_id IS NULL) AND (seller_user_id = auth.uid())));
  ALTER TABLE public.requirements ENABLE ROW LEVEL SECURITY;
  CREATE POLICY requirements_select_policy ON public.requirements FOR SELECT TO authenticated USING (
    (broker_id = auth.uid()) OR is_admin()
    OR (company_id IN (SELECT u.company_id FROM users u WHERE u.id = auth.uid()))
    OR ((visibility = 'global'::text) AND (status = ANY (ARRAY['Open'::text, 'Partially Fulfilled'::text, 'Allocated'::text]))));
  CREATE POLICY requirements_update_policy ON public.requirements FOR UPDATE TO authenticated
    USING ((broker_id = auth.uid()) OR is_admin() OR (company_id IN (SELECT u.company_id FROM users u WHERE u.id = auth.uid())))
    WITH CHECK ((broker_id = auth.uid()) OR is_admin() OR (company_id IN (SELECT u.company_id FROM users u WHERE u.id = auth.uid())));
  ALTER TABLE public.requirement_allocations ENABLE ROW LEVEL SECURITY;
  CREATE POLICY requirement_allocations_select_policy ON public.requirement_allocations FOR SELECT TO authenticated
    USING ((broker_id = auth.uid()) OR is_admin());
  CREATE POLICY requirement_allocations_insert_policy ON public.requirement_allocations FOR INSERT TO authenticated
    WITH CHECK (((broker_id = auth.uid()) AND (is_broker() OR is_admin())) OR is_admin());
  CREATE POLICY requirement_allocations_update_policy ON public.requirement_allocations FOR UPDATE TO authenticated
    USING ((broker_id = auth.uid()) OR is_admin()) WITH CHECK ((broker_id = auth.uid()) OR is_admin());
  ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
  CREATE POLICY users_select_policy ON public.users FOR SELECT TO authenticated USING (
    (id = auth.uid()) OR is_admin() OR ((lower(role) = 'broker'::text) AND (status = true))
    OR ((lower(role) = ANY (ARRAY['buyer'::text, 'seller'::text])) AND ((created_by = auth.uid())
      OR (EXISTS (SELECT 1 FROM crm_contacts WHERE crm_contacts.user_id = users.id AND crm_contacts.broker_id = auth.uid())))));

  INSERT INTO public.companies VALUES ('${CO_BUY}','Buyer Feeds'),('${CO_SELL}','Seller Traders'),
    ('${CO_BUY2}','Buyer Two'),('${CO_SELL2}','Seller Two');
  INSERT INTO public.users (id,name,mobile,role,status,company_id) VALUES
    ('${BROKER}','Assigned Broker','9000000001','broker',true,NULL),
    ('${BROKER2}','Other Broker','9000000002','broker',true,NULL),
    ('${BUYER}','Buyer One','9000000003','buyer',true,'${CO_BUY}'),
    ('${BUYER2}','Buyer Two','9000000004','buyer',true,'${CO_BUY2}'),
    ('${SELLER}','Seller One','9000000005','seller',true,'${CO_SELL}'),
    ('${SELLER2}','Seller Two','9000000006','seller',true,'${CO_SELL2}'),
    ('${ADMIN}','Admin',NULL,'admin',true,NULL);
  INSERT INTO public.master_commodities VALUES ('${MAIZE}','Maize'),('${WHEAT}','Wheat');
  INSERT INTO public.master_units VALUES ('${MT}','Metric Tonne','MT'),('${QTL}','Quintal','Qtl');
  INSERT INTO public.requirements (id,company_id,broker_id,commodity_id,unit_id,quantity,status,target_date) VALUES
    ('${REQ}','${CO_BUY}','${BROKER}','${MAIZE}','${MT}',50,'Open',now() + interval '10 days'),
    ('${REQ2}','${CO_BUY2}','${BROKER2}','${MAIZE}','${MT}',20,'Open',now() + interval '10 days');
  INSERT INTO public.availabilities (id,company_id,seller_user_id,broker_id,commodity_id,unit_id,lot_number,visibility,
      valid_until,available_quantity,asking_price,confidential_minimum_price) VALUES
    ('${LOT}','${CO_SELL}',NULL,'${BROKER}','${MAIZE}','${MT}','LOT-1','global',now()+interval '9 days',40,5900,5600),
    ('${LOT_FREE}','${CO_SELL}',NULL,NULL,'${MAIZE}','${QTL}','LOT-2','global',now()+interval '9 days',300,590,560),
    ('${LOT_OTHER}','${CO_SELL2}',NULL,'${BROKER2}','${MAIZE}','${MT}','LOT-3','global',now()+interval '9 days',30,5800,5500),
    ('${LOT_WHEAT}','${CO_SELL}',NULL,NULL,'${WHEAT}','${MT}','LOT-4','global',now()+interval '9 days',30,2500,2400),
    ('${LOT_PRIVATE}','${CO_SELL}',NULL,NULL,'${MAIZE}','${MT}','LOT-5','private',now()+interval '9 days',30,5900,5600);
`);

await db.exec(read('migrations', '0043_buyer_broker_chat.sql'));
await db.exec(read('proposed', '0066_bidirectional_broker_chat.sql'));
check('production state (0043 + 0066) builds', true);

// ===================== Phase 6 baseline: current production policies =====================
const leak = async (uid) => ({
  lots: (await as(uid, 'SELECT count(*)::int n FROM public.availabilities')).rows[0].n,
  floors: (await as(uid, 'SELECT count(*)::int n FROM public.availabilities WHERE confidential_minimum_price IS NOT NULL')).rows[0].n,
  reqs: (await as(uid, 'SELECT count(*)::int n FROM public.requirements')).rows[0].n,
});
const pBuyer = await leak(BUYER), pSeller = await leak(SELLER), pNoRow = await leak(NOROW);
check('[current prod] buyer can read seller lots + confidential floor price (LEAK reproduced)',
  pBuyer.lots > 0 && pBuyer.floors > 0, JSON.stringify(pBuyer));
check('[current prod] seller can read other buyers\' requirements (LEAK reproduced)',
  pSeller.reqs === 2, JSON.stringify(pSeller));
check('[current prod] a session with no users row reads lots and requirements (LEAK reproduced)',
  pNoRow.lots > 0 && pNoRow.reqs > 0, JSON.stringify(pNoRow));
const freeUpd = await as(BROKER, `UPDATE public.availabilities SET reserved_quantity = 1 WHERE id = '${LOT_FREE}' RETURNING id`);
check('[current prod] broker cannot update an unassigned lot (allocation blocker reproduced)',
  freeUpd.ok && freeUpd.rows.length === 0);

// ===================== 0069 privacy =====================
await db.exec(read('proposed', '0069_marketplace_visibility_privacy.sql'));
const aBuyer = await leak(BUYER), aSeller = await leak(SELLER), aNoRow = await leak(NOROW);
const aBroker = await leak(BROKER), aBroker2 = await leak(BROKER2), aAdmin = await leak(ADMIN);
check('0069 buyer cannot browse or search seller lots', aBuyer.lots === 0 && aBuyer.floors === 0, JSON.stringify(aBuyer));
check('0069 buyer still reads its own requirement only', aBuyer.reqs === 1);
check('0069 seller reads only its own lots, no buyer requirements', aSeller.lots === 4 && aSeller.reqs === 0, JSON.stringify(aSeller));
check('0069 no-users-row session reads nothing', aNoRow.lots === 0 && aNoRow.reqs === 0);
check('0069 brokers keep the global marketplace (global lots + global requirements)',
  aBroker.lots === 4 && aBroker.reqs === 2 && aBroker2.lots === 4, JSON.stringify(aBroker));
check('0069 admin unchanged (all rows)', aAdmin.lots === 5 && aAdmin.reqs === 2);
const sellerOther = await as(SELLER, `SELECT count(*)::int n FROM public.availabilities WHERE id = '${LOT_OTHER}'`);
check('0069 seller cannot read another seller\'s lot', sellerOther.rows[0].n === 0);
const buyerDirect = await as(BUYER, `SELECT confidential_minimum_price FROM public.availabilities WHERE id = '${LOT}'`);
check('0069 direct API read of a lot floor price by a buyer returns nothing', buyerDirect.ok && buyerDirect.rows.length === 0);
const buyerUsers = await as(BUYER, `SELECT count(*)::int n FROM public.users WHERE lower(role) = 'seller'`);
check('buyer cannot list sellers in users (existing policy)', buyerUsers.rows[0].n === 0);
const sellerUsers = await as(SELLER, `SELECT count(*)::int n FROM public.users WHERE lower(role) = 'buyer'`);
check('seller cannot list buyers in users (existing policy)', sellerUsers.rows[0].n === 0);

// ===================== 0068 allocation =====================
await db.exec(read('proposed', '0068_broker_allocate_lot.sql'));
const a1 = await allocate(BROKER, REQ, LOT_FREE, 10);   // 10 MT from a Qtl lot = 100 Qtl
check('0068 broker allocates an UNASSIGNED global lot to its requirement', a1.ok, a1.msg);
const lotAfter = (await q(`SELECT available_quantity::float a, reserved_quantity::float r, broker_id FROM public.availabilities WHERE id='${LOT_FREE}'`))[0];
check('0068 stock reserved with unit conversion (10 MT = 100 Qtl); lot not reassigned',
  lotAfter.a === 200 && lotAfter.r === 100 && lotAfter.broker_id === null, JSON.stringify(lotAfter));
const reqAfter = (await q(`SELECT fulfilled_quantity::float f FROM public.requirements WHERE id='${REQ}'`))[0];
check('0068 requirement fulfilled quantity raised in the same transaction', reqAfter.f === 10);
const persisted = await as(BROKER, `SELECT id, requirement_id, availability_id, status FROM public.requirement_allocations WHERE requirement_id='${REQ}'`);
check('0068 allocation persists, references the right requirement and lot, readable by its broker',
  persisted.rows.length === 1 && persisted.rows[0].availability_id === LOT_FREE && persisted.rows[0].status === 'CONFIRMED');
const retry = await allocate(BROKER, REQ, LOT_FREE, 10);
check('0068 identical retry returns the same allocation (no duplicate)', retry.ok && retry.rows[0].id === a1.rows[0].id);
const dup = await allocate(BROKER, REQ, LOT_FREE, 5);
check('0068 a second allocation of the same lot to the same requirement is refused', !dup.ok && dup.code === '23505', dup.msg);
const a2 = await allocate(BROKER, REQ, LOT, 20);
check('0068 another matching lot can be added (existing allocation not replaced)', a2.ok, a2.msg);
const nAlloc = (await q(`SELECT count(*)::int n FROM public.requirement_allocations WHERE requirement_id='${REQ}'`))[0].n;
check('0068 both allocations kept', nAlloc === 2);
const wheat = await allocate(BROKER, REQ, LOT_WHEAT, 1);
check('0068 different commodity is refused', !wheat.ok && /different product/.test(wheat.msg));
const otherDesk = await allocate(BROKER, REQ, LOT_OTHER, 1);
check('0068 a lot managed by another broker stays blocked', !otherDesk.ok && otherDesk.code === '42501');
const priv = await allocate(BROKER, REQ, LOT_PRIVATE, 1);
check('0068 an unassigned PRIVATE lot is not allocatable', !priv.ok && priv.code === '42501');
const notMine = await allocate(BROKER, REQ2, LOT_FREE, 1);
check('0068 broker cannot allocate to another broker\'s requirement', !notMine.ok && notMine.code === '42501');
const over = await allocate(BROKER, REQ, LOT, 100);
check('0068 over-allocation beyond remaining requirement is refused', !over.ok);
const byBuyer = await allocate(BUYER, REQ, LOT_FREE, 1);
const bySeller = await allocate(SELLER, REQ, LOT_FREE, 1);
check('0068 buyers and sellers cannot allocate', !byBuyer.ok && !bySeller.ok && byBuyer.code === '42501');
const sellerSeesAlloc = await as(SELLER, 'SELECT count(*)::int n FROM public.requirement_allocations');
const buyerSeesAlloc = await as(BUYER, 'SELECT count(*)::int n FROM public.requirement_allocations');
check('allocations are invisible to buyers and sellers (no counterparty discovery)',
  sellerSeesAlloc.rows[0].n === 0 && buyerSeesAlloc.rows[0].n === 0);
const direct = await as(BROKER, `INSERT INTO public.requirement_allocations (allocation_reference, requirement_id, availability_id, broker_id, allocated_quantity, unit_id)
  VALUES ('X-1','${REQ2}','${LOT_OTHER}','${BROKER2}',1,'${MT}')`);
check('direct insert of an allocation for another broker is denied (RLS)', !direct.ok);

// ===================== 0067 chat context =====================
await db.exec(read('proposed', '0067_chat_context_conversations.sql'));
check('0067 applies on top of 0066', true);

// Flow A (after allocation): broker -> seller on the offer, broker -> buyer on the requirement.
const fa1 = await sendCtx(BROKER, 'A6 broker to seller about LOT-1', SELLER, { lot: LOT });
check('A6 broker opens an offer chat with the seller of its assigned lot', fa1.ok, fa1.msg);
const convLot = fa1.rows?.[0]?.conversation_id;
const fa2 = await reply(SELLER, 'A7 seller replies', convLot);
const fa3 = await reply(BROKER, 'A7 broker again', convLot);
check('A7 seller and broker reply in the same offer conversation', fa2.ok && fa3.ok);
check('A7 both sides read identical chronological history', same(await hist(SELLER, convLot), await hist(BROKER, convLot))
  && (await hist(BROKER, convLot)).map((m) => m.body.slice(0, 2)).join() === 'A6,A7,A7');
const fa4 = await sendCtx(BROKER, 'A8 broker to buyer about the requirement', BUYER, { req: REQ });
const convReq = fa4.rows?.[0]?.conversation_id;
check('A8 broker opens a requirement chat with the buyer', fa4.ok && convReq && convReq !== convLot, fa4.msg);
const fa5 = await reply(BUYER, 'A9 buyer replies', convReq);
check('A9 buyer replies; identical history both sides', fa5.ok && same(await hist(BUYER, convReq), await hist(BROKER, convReq)));
const ctxRow = (await q(`SELECT requirement_id, availability_id FROM public.chat_conversations WHERE id IN ('${convLot}','${convReq}') ORDER BY requirement_id NULLS FIRST`));
check('conversations are linked to the right offer / requirement', ctxRow[0].availability_id === LOT && ctxRow[1].requirement_id === REQ);
const inboxB = (await as(BROKER, 'SELECT conversation_id, counterpart_role, context_label FROM public.chat_inbox(NULL)')).rows;
check('broker inbox shows separate buyer and seller conversations with context labels',
  inboxB.length === 2 && inboxB.some((r) => r.counterpart_role === 'seller' && r.context_label === 'Offer · Maize · LOT-1')
  && inboxB.some((r) => r.counterpart_role === 'buyer' && r.context_label === 'Requirement · Maize'), JSON.stringify(inboxB));

// Flow B: buyer starts from its requirement (to the requirement's broker).
const fb = await sendCtx(BUYER, 'B buyer again from the requirement', BROKER, { req: REQ });
check('B buyer starting from the same requirement reuses the conversation (no duplicate)',
  fb.ok && fb.rows[0].conversation_id === convReq);
const findB = await as(BUYER, 'SELECT public.chat_find_conversation($1,$2,NULL) id', [BROKER, REQ]);
const findBr = await as(BROKER, 'SELECT public.chat_find_conversation($1,$2,NULL) id', [BUYER, REQ]);
check('B both participants find the same conversation for the requirement', findB.rows[0].id === convReq && findBr.rows[0].id === convReq);
const fb2 = await sendCtx(BUYER2, 'B2 fresh buyer chat', BROKER2, { req: REQ2 });
const fb3 = fb2.ok ? await reply(BROKER2, 'B2 broker reply', fb2.rows[0].conversation_id) : fb2;
check('B fresh buyer-started requirement chat; broker replies', fb2.ok && fb3.ok, fb2.msg);

// Flow C: seller starts from its offer (to the offer's assigned broker).
const fc = await sendCtx(SELLER2, 'C seller starts on LOT-3', BROKER2, { lot: LOT_OTHER });
const fc2 = fc.ok ? await reply(BROKER2, 'C broker reply', fc.rows[0].conversation_id) : fc;
const fc3 = fc.ok ? await reply(SELLER2, 'C seller again', fc.rows[0].conversation_id) : fc;
check('C seller starts an offer chat with its assigned broker; both continue', fc.ok && fc2.ok && fc3.ok, fc.msg);

// Flow D: authorization.
const d1 = await sendCtx(BROKER2, 'not my lot', SELLER, { lot: LOT });
check('D unassigned broker cannot open the offer chat', !d1.ok && d1.code === '42501');
const d2 = await sendCtx(SELLER, 'wrong broker', BROKER2, { lot: LOT });
check('D seller cannot open an offer chat with a broker not assigned to the offer', !d2.ok);
const d3 = await sendCtx(SELLER2, 'not my lot', BROKER, { lot: LOT });
check('D unrelated seller cannot open someone else\'s offer chat', !d3.ok);
const d4 = await sendCtx(BUYER2, 'not my requirement', BROKER, { req: REQ });
check('D unrelated buyer cannot open someone else\'s requirement chat', !d4.ok);
const d5 = await sendCtx(BUYER, 'seller via requirement?', SELLER, { req: REQ });
const d6 = await sendCtx(SELLER, 'buyer via offer?', BUYER, { lot: LOT });
const d7 = await sendCtx(BUYER, 'buyer on an offer?', BROKER, { lot: LOT });
check('D buyer and seller can never become participants together', !d5.ok && !d6.ok && !d7.ok);
for (const [who, label] of [[BROKER2, 'other broker'], [SELLER2, 'unrelated seller'], [BUYER2, 'unrelated buyer'], [BUYER, 'the buyer (offer chat)']]) {
  const h = await hist(who, convLot);
  const w = await reply(who, 'intrude', convLot);
  check(`D ${label} cannot read or post in the offer conversation`, h.length === 0 && !w.ok);
}
for (const [who, label] of [[BROKER2, 'other broker'], [SELLER, 'the seller (requirement chat)']]) {
  const h = await hist(who, convReq);
  const w = await reply(who, 'intrude', convReq);
  check(`D ${label} cannot read or post in the requirement conversation`, h.length === 0 && !w.ok);
}
const probe = await sendCtx(BROKER, 'x', '99999999-0000-4000-8000-000000000000', { lot: LOT });
check('D unknown user gives the same error as unauthorised (no probing)', !probe.ok && probe.msg === d1.msg);
const both = await sendCtx(BROKER, 'x', SELLER, { req: REQ, lot: LOT });
check('D a chat cannot have two contexts', !both.ok);
const sellerInbox = (await as(SELLER, 'SELECT * FROM public.chat_inbox(NULL)')).rows;
check('seller inbox metadata never names a buyer', sellerInbox.every((r) => r.counterpart_role === 'broker')
  && !JSON.stringify(sellerInbox).includes('Buyer One'));
const buyerInbox = (await as(BUYER, 'SELECT * FROM public.chat_inbox(NULL)')).rows;
check('buyer inbox metadata never names a seller, lot or floor price', buyerInbox.every((r) => r.counterpart_role === 'broker')
  && !/Seller|LOT-|5600/.test(JSON.stringify(buyerInbox)));

// Reassignment: the old broker stops writing, history stays readable.
await db.exec(`UPDATE public.availabilities SET broker_id = '${BROKER2}' WHERE id = '${LOT}'`);
const afterReassign = await reply(BROKER, 'still mine?', convLot);
check('after the offer is reassigned the old broker can no longer post', !afterReassign.ok);
check('after reassignment the old participants keep their history', (await hist(BROKER, convLot)).length === 3);
await db.exec(`UPDATE public.availabilities SET broker_id = '${BROKER}' WHERE id = '${LOT}'`);

// General (0043/0066) behaviour preserved.
const g1 = await as(BUYER, 'SELECT * FROM public.chat_send_message($1,$2,$3,NULL)', ['general hello', cid(), BROKER]);
check('buyer-started general conversation still works (0043 path)', g1.ok && ![convReq, convLot].includes(g1.rows[0].conversation_id), g1.msg);
const g2 = await as(BUYER, 'SELECT * FROM public.chat_send_message($1,$2,$3,NULL)', ['general again', cid(), BROKER]);
check('general conversation is reused (one per pair)', g2.ok && g2.rows[0].conversation_id === g1.rows[0].conversation_id);

// Removed CRM contact no longer authorises a broker general chat.
await db.exec(`INSERT INTO public.crm_contacts (broker_id, user_id, removed_at) VALUES ('${BROKER2}','${BUYER}', now())`);
const removed = await as(BROKER2, 'SELECT * FROM public.chat_send_message_to($1,$2,$3)', ['hi', cid(), BUYER]);
check('0067 removed CRM contact does not authorise a broker-initiated chat', !removed.ok);
await db.exec(`INSERT INTO public.crm_contacts (broker_id, user_id) VALUES ('${BROKER2}','${BUYER2}')`);
const active = await as(BROKER2, 'SELECT * FROM public.chat_send_message_to($1,$2,$3)', ['hi', cid(), BUYER2]);
check('active CRM contact still authorises it', active.ok, active.msg);

// Idempotency + notifications in context chats.
const k = cid();
const r1 = await reply(SELLER, 'retry', convLot, k), r2 = await reply(SELLER, 'retry', convLot, k);
check('retried send returns the original message', r1.ok && r2.ok && r1.rows[0].id === r2.rows[0].id);
const n = await as(BROKER, `SELECT count(*)::int n FROM public.notifications WHERE idempotency_key = 'chat-msg-${r1.rows[0].id}'`);
check('exactly one notification for the retried message, to the broker', n.rows[0].n === 1);
const notifLeak = await q(`SELECT count(*)::int n FROM public.notifications WHERE payload::text ILIKE '%5600%' OR message ILIKE '%A6 broker%'`);
check('chat notifications carry no message body and no floor price', notifLeak[0].n === 0);

// ===================== rollbacks =====================
const rb67 = await db.exec(read('proposed', 'rollback_0067.sql')).then(() => 'applied', async (e) => {
  await db.exec('ROLLBACK'); // the refused rollback leaves its transaction aborted
  return e.message.split('\n')[0];
});
check('rollback_0067 refuses while context conversations exist (no silent history loss)', /context conversations exist/.test(rb67), rb67);
await db.exec(`DELETE FROM public.chat_messages WHERE conversation_id IN (SELECT id FROM public.chat_conversations WHERE requirement_id IS NOT NULL OR availability_id IS NOT NULL);
  DELETE FROM public.chat_conversations WHERE requirement_id IS NOT NULL OR availability_id IS NOT NULL;`);
await db.exec(read('proposed', 'rollback_0067.sql'));
const g3 = await as(BUYER, 'SELECT * FROM public.chat_send_message($1,$2,$3,NULL)', ['after rollback', cid(), BROKER]);
check('rollback_0067 restores 0066 behaviour (fixture cleanup only)', g3.ok && g3.rows[0].conversation_id === g1.rows[0].conversation_id, g3.msg);
await db.exec(read('proposed', 'rollback_0068.sql'));
check('rollback_0068 removes the allocation function', !(await allocate(BROKER, REQ, LOT, 1)).ok);
await db.exec(read('proposed', 'rollback_0069.sql'));
check('rollback_0069 restores the production policies (leak returns)', (await leak(BUYER)).lots > 0);

const failed = results.filter((r) => !r.ok).length;
console.log(`\n${results.length - failed}/${results.length} passed`);
process.exit(failed ? 1 : 0);
