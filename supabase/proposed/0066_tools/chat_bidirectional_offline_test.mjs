// RM-CHAT-BIDIRECTIONAL-E2E-01 — offline tests for migration 0043 + proposed 0066.
//
// Builds stubs of the tables the chat functions touch (users, companies,
// notifications, crm_contacts, requirements, availabilities) in PGlite, applies
// the real 0043 and the proposed 0066, and runs every scenario as a real
// `authenticated` session (SET ROLE + JWT sub claim), so RLS, grants and the
// SECURITY DEFINER functions execute for real. Finally applies rollback_0066
// and checks the 0043 behaviour is back.
//
// NOT covered (needs a Supabase project): PostgREST, Auth sign-in, Realtime
// delivery, and the production column set.
//
// Usage: node chat_bidirectional_offline_test.mjs <repoRoot> <pgliteModuleDir>
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
    const r = await db.query(sql, params);
    return { ok: true, rows: r.rows };
  } catch (e) {
    return { ok: false, code: e.code, msg: e.message.split('\n')[0] };
  } finally {
    await db.exec(`RESET ROLE; SELECT set_config('request.jwt.claim.sub', '', false);`);
  }
}

let seq = 0;
const cid = () => `00000000-0000-4000-8000-${String(++seq).padStart(12, '0')}`;
const send = (uid, body, { conv = null, broker = null, clientId = cid() } = {}) =>
  as(uid, 'SELECT * FROM public.chat_send_message($1, $2, $3, $4)', [body, clientId, broker, conv]);
const sendTo = (uid, body, to, clientId = cid()) =>
  as(uid, 'SELECT * FROM public.chat_send_message_to($1, $2, $3)', [body, clientId, to]);
const history = async (uid, conv) => {
  const r = await as(uid,
    'SELECT id, sender_id, body, created_at FROM public.chat_messages WHERE conversation_id = $1 ORDER BY created_at, id', [conv]);
  return r.ok ? r.rows : [];
};
const inbox = async (uid) => (await as(uid, 'SELECT * FROM public.chat_inbox(NULL)')).rows ?? [];
const sameHistory = (a, b) => a.length === b.length && a.every((m, i) => m.id === b[i].id);

// --- ids ---
const CO_BUY = 'c0000000-0000-4000-8000-000000000001';
const CO_SELL = 'c0000000-0000-4000-8000-000000000002';
const CO_BUY2 = 'c0000000-0000-4000-8000-000000000003';
const BROKER = 'b0000000-0000-4000-8000-000000000001';   // E2E-BROKER-01
const BROKER2 = 'b0000000-0000-4000-8000-000000000002';
const BROKER_OFF = 'b0000000-0000-4000-8000-000000000003';
const BUYER = 'a0000000-0000-4000-8000-000000000001';    // E2E-BUYER-01
const BUYER2 = 'a0000000-0000-4000-8000-000000000002';   // unrelated buyer
const SELLER = 'd0000000-0000-4000-8000-000000000001';   // E2E-SELLER-01 (company)
const SELLER_IND = 'd0000000-0000-4000-8000-000000000002'; // individual seller
const SELLER_X = 'd0000000-0000-4000-8000-000000000003'; // unrelated seller
const ADMIN = 'e0000000-0000-4000-8000-000000000001';
const REQ = 'f0000000-0000-4000-8000-000000000001';
const LOT = 'f0000000-0000-4000-8000-000000000002';
const LOT_IND = 'f0000000-0000-4000-8000-000000000003';
const LOT_OTHER = 'f0000000-0000-4000-8000-000000000004';

// --- 1. Platform stubs (columns the chat functions read) ---
await db.exec(`
  CREATE ROLE anon; CREATE ROLE authenticated;
  CREATE SCHEMA auth;
  CREATE FUNCTION auth.uid() RETURNS uuid LANGUAGE sql STABLE AS
    $$ SELECT NULLIF(current_setting('request.jwt.claim.sub', true), '')::uuid $$;
  GRANT USAGE ON SCHEMA auth TO authenticated, anon;
  GRANT EXECUTE ON FUNCTION auth.uid() TO authenticated, anon;
  CREATE PUBLICATION supabase_realtime;

  CREATE TABLE public.companies (id uuid PRIMARY KEY, name text NOT NULL);
  CREATE TABLE public.users (id uuid PRIMARY KEY, name text, role text, status boolean DEFAULT true,
    company_id uuid REFERENCES public.companies(id), mobile text, email text);
  CREATE FUNCTION public.is_broker() RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER AS
    $$ SELECT EXISTS (SELECT 1 FROM public.users WHERE id = auth.uid() AND role = 'broker') $$;
  CREATE TABLE public.notifications (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id uuid NOT NULL REFERENCES public.users(id), company_id uuid,
    channel text NOT NULL DEFAULT 'IN_APP', event_type text NOT NULL, title text NOT NULL,
    message text NOT NULL DEFAULT '', payload jsonb, delivery_status text NOT NULL DEFAULT 'Pending',
    action_url text NOT NULL DEFAULT '/', context_reason text NOT NULL DEFAULT '',
    action_label text NOT NULL DEFAULT 'View', idempotency_key text, is_read boolean NOT NULL DEFAULT false,
    read_at timestamptz, created_at timestamptz NOT NULL DEFAULT now());
  CREATE UNIQUE INDEX notifications_idempotency_key_idx ON public.notifications (idempotency_key);
  ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;
  CREATE POLICY notif_own ON public.notifications FOR SELECT TO authenticated USING (user_id = auth.uid());
  GRANT SELECT ON public.notifications TO authenticated;
  CREATE TABLE public.crm_contacts (id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    broker_id uuid NOT NULL REFERENCES public.users(id), user_id uuid REFERENCES public.users(id),
    company_id uuid REFERENCES public.companies(id));
  CREATE TABLE public.requirements (id uuid PRIMARY KEY, company_id uuid NOT NULL REFERENCES public.companies(id),
    broker_id uuid REFERENCES public.users(id));
  CREATE TABLE public.availabilities (id uuid PRIMARY KEY, company_id uuid REFERENCES public.companies(id),
    seller_user_id uuid REFERENCES public.users(id), broker_id uuid REFERENCES public.users(id));
  GRANT SELECT ON public.users, public.companies TO authenticated;

  INSERT INTO public.companies VALUES
    ('${CO_BUY}','E2E Buyer Feeds'),('${CO_SELL}','E2E Seller Traders'),('${CO_BUY2}','Other Buyer Co');
  INSERT INTO public.users (id, name, role, status, company_id, mobile) VALUES
    ('${BROKER}','E2E Broker','broker',true,NULL,'9000000001'),
    ('${BROKER2}','Other Broker','broker',true,NULL,'9000000002'),
    ('${BROKER_OFF}','Inactive Broker','broker',false,NULL,NULL),
    ('${BUYER}','E2E Buyer','buyer',true,'${CO_BUY}','9000000003'),
    ('${BUYER2}','Other Buyer','buyer',true,'${CO_BUY2}',NULL),
    ('${SELLER}','E2E Seller','seller',true,'${CO_SELL}','9000000004'),
    ('${SELLER_IND}','Ramesh Kumar','seller',true,NULL,NULL),
    ('${SELLER_X}','Unrelated Seller','seller',true,NULL,NULL),
    ('${ADMIN}','Admin','admin',true,NULL,NULL);
  INSERT INTO public.requirements VALUES ('${REQ}','${CO_BUY}','${BROKER}');
  INSERT INTO public.availabilities VALUES
    ('${LOT}','${CO_SELL}',NULL,'${BROKER}'),
    ('${LOT_IND}',NULL,'${SELLER_IND}','${BROKER}'),
    ('${LOT_OTHER}',NULL,'${SELLER_X}','${BROKER2}');
`);

// --- 2. Apply the real 0043, then the proposed 0066 ---
await db.exec(read('migrations', '0043_buyer_broker_chat.sql'));
check('0043 applies cleanly', true);

// 0043 baseline: brokers and sellers cannot start conversations.
const pre = await sendTo(BROKER, 'hi', BUYER);
check('before 0066: broker-initiated chat does not exist', !pre.ok);
const preSeller = await send(SELLER, 'hi', { broker: BROKER });
check('before 0066: seller cannot start a broker chat', !preSeller.ok && preSeller.code === '42501', preSeller.msg);

await db.exec(read('proposed', '0066_bidirectional_broker_chat.sql'));
check('0066 applies cleanly', true);

// --- Scenario A: broker -> buyer (related through an assigned requirement) ---
const a1 = await sendTo(BROKER, 'A1 broker: your maize requirement', BUYER);
check('A1 broker starts a chat with the requirement buyer', a1.ok, a1.msg);
const convA = a1.rows?.[0]?.conversation_id;
check('A message stores the authenticated sender and the conversation',
  a1.rows?.[0]?.sender_id === BROKER && !!convA && !!a1.rows?.[0]?.created_at);
const buyerInbox = await inbox(BUYER);
check('A2 buyer sees the broker-initiated conversation in the inbox',
  buyerInbox.some((r) => r.conversation_id === convA && r.counterpart_id === BROKER && r.unread_count === 1));
const a3 = await send(BUYER, 'A3 buyer reply', { conv: convA });
check('A3 buyer replies into the same conversation', a3.ok && a3.rows[0].conversation_id === convA, a3.msg);
const a5 = await send(BROKER, 'A5 broker follow-up', { conv: convA });
const a6 = await send(BUYER, 'A6 buyer again', { conv: convA });
check('A5/A6 both sides keep sending', a5.ok && a6.ok);
const hA_broker = await history(BROKER, convA);
const hA_buyer = await history(BUYER, convA);
check('A7 both sides read the same 4 messages in the same order', sameHistory(hA_broker, hA_buyer) && hA_broker.length === 4,
  hA_broker.map((m) => m.body.slice(0, 2)).join(','));
check('A ordering is chronological by server time',
  hA_broker.every((m, i) => i === 0 || new Date(hA_broker[i - 1].created_at) <= new Date(m.created_at)));
const again = await sendTo(BROKER, 'A again via send_to', BUYER);
check('A repeated start reuses the same conversation (no duplicate)', again.ok && again.rows[0].conversation_id === convA);
const nConvA = await q(`SELECT count(*)::int n FROM public.chat_conversations WHERE buyer_id='${BUYER}' AND broker_id='${BROKER}'`);
check('A exactly one conversation for the pair', nConvA[0].n === 1);
const brokerInboxA = (await inbox(BROKER)).find((r) => r.conversation_id === convA);
check('A broker inbox labels the counterpart as buyer', brokerInboxA?.counterpart_role === 'buyer');

// --- Scenario B: broker -> seller (related through a managed lot) ---
const b1 = await sendTo(BROKER, 'B1 broker: about your lot', SELLER);
check('B1 broker starts a chat with the seller of a managed lot', b1.ok, b1.msg);
const convB = b1.rows?.[0]?.conversation_id;
check('B2 seller sees it in the inbox', (await inbox(SELLER)).some((r) => r.conversation_id === convB && r.counterpart_role === 'broker'));
const b3 = await send(SELLER, 'B3 seller reply', { conv: convB });
const b5 = await send(BROKER, 'B5 broker follow-up', { conv: convB });
const b6 = await send(SELLER, 'B6 seller again', { conv: convB });
check('B3-B6 seller and broker reply both ways', b3.ok && b5.ok && b6.ok, b3.msg ?? b5.msg ?? b6.msg);
const hB_s = await history(SELLER, convB);
check('B7 both sides read the same 4 messages in order', sameHistory(hB_s, await history(BROKER, convB)) && hB_s.length === 4);
const bInd = await sendTo(BROKER, 'hello', SELLER_IND);
check('B individual seller (seller_user_id lot) is reachable', bInd.ok, bInd.msg);
check('B broker inbox labels the counterpart as seller',
  (await inbox(BROKER)).find((r) => r.conversation_id === convB)?.counterpart_role === 'seller');

// --- Scenario C: buyer -> broker (0043 path still works) ---
const c1 = await send(BUYER2, 'C1 buyer asks a broker', { broker: BROKER2 });
check('C1 buyer starts a conversation with a broker', c1.ok, c1.msg);
const convC = c1.rows?.[0]?.conversation_id;
check('C2 broker sees the incoming conversation', (await inbox(BROKER2)).some((r) => r.conversation_id === convC && r.unread_count === 1));
const c3 = await send(BROKER2, 'C3 broker reply', { conv: convC });
const c4 = await send(BUYER2, 'C4 buyer responds', { conv: convC });
check('C3/C4 conversation continues both ways', c3.ok && c4.ok && (await history(BUYER2, convC)).length === 3);
const viaTo = await sendTo(BUYER2, 'C via send_to', BROKER2);
check('C buyer send_to delegates to the same conversation', viaTo.ok && viaTo.rows[0].conversation_id === convC);

// --- Scenario D: seller -> broker ---
const d1 = await send(SELLER_X, 'D1 seller asks a broker', { broker: BROKER });
check('D1 seller starts a conversation with a broker', d1.ok, d1.msg);
const convD = d1.rows?.[0]?.conversation_id;
check('D2 broker sees the incoming seller conversation', (await inbox(BROKER)).some((r) => r.conversation_id === convD && r.counterpart_role === 'seller'));
const d3 = await send(BROKER, 'D3 broker reply', { conv: convD });
const d4 = await send(SELLER_X, 'D4 seller responds', { conv: convD });
check('D3/D4 conversation continues both ways', d3.ok && d4.ok && sameHistory(await history(SELLER_X, convD), await history(BROKER, convD)));

// --- Authorization and privacy ---
const unrelatedBuyer = await sendTo(BROKER, 'cold message', BUYER2);
check('broker cannot cold-message an unrelated buyer', !unrelatedBuyer.ok && unrelatedBuyer.code === '42501', unrelatedBuyer.msg);
const otherDeskSeller = await sendTo(BROKER2, 'not my lot', SELLER);
check('broker cannot message the seller of another desk\'s lot', !otherDeskSeller.ok && otherDeskSeller.code === '42501');
const ghost = await sendTo(BROKER, 'x', '99999999-0000-4000-8000-000000000000');
check('unknown user gives the same error as unrelated (no probing)', !ghost.ok && ghost.msg === unrelatedBuyer.msg);
const toBroker = await sendTo(BROKER, 'x', BROKER2);
check('broker cannot open a broker-to-broker chat', !toBroker.ok);
const toAdmin = await sendTo(BROKER, 'x', ADMIN);
check('admins are not chat participants', !toAdmin.ok);
const buyerToSeller = await sendTo(BUYER, 'direct?', SELLER);
check('buyer cannot message a seller directly (send_to)', !buyerToSeller.ok && buyerToSeller.code === '42501', buyerToSeller.msg);
const buyerToSeller2 = await send(BUYER, 'direct?', { broker: SELLER });
check('buyer cannot message a seller directly (0043 path)', !buyerToSeller2.ok);
const sellerToBuyer = await sendTo(SELLER, 'direct?', BUYER);
check('seller cannot message a buyer directly', !sellerToBuyer.ok);
const inactive = await send(BUYER, 'x', { broker: BROKER_OFF });
check('inactive broker cannot be messaged', !inactive.ok);
check('third party reads no messages (RLS)', (await history(SELLER, convA)).length === 0 && (await history(BUYER2, convB)).length === 0);
const intrude = await send(BROKER2, 'intrude', { conv: convA });
check('third party cannot post into a conversation', !intrude.ok && intrude.code === '42501');
check('third party does not see the conversation in its inbox', !(await inbox(BROKER2)).some((r) => r.conversation_id === convA));
const forged = await as(BUYER, `INSERT INTO public.chat_messages (conversation_id, sender_id, body, client_message_id)
  VALUES ('${convA}', '${BROKER}', 'forged', '${cid()}')`);
check('no direct insert: a sender cannot impersonate another participant', !forged.ok);
check('seller of convB cannot see buyer of convA in its inbox',
  !(await inbox(SELLER)).some((r) => r.counterpart_id === BUYER));
const inboxCols = Object.keys((await inbox(BUYER))[0] ?? {});
check('inbox exposes no phone/email', !inboxCols.some((c) => /mobile|phone|email/.test(c)), inboxCols.join(','));

// --- Idempotency and notifications ---
const key = cid();
const r1 = await send(BUYER, 'retry me', { conv: convA, clientId: key });
const r2 = await send(BUYER, 'retry me', { conv: convA, clientId: key });
check('retry with the same client id returns the original message', r1.ok && r2.ok && r1.rows[0].id === r2.rows[0].id);
const notif = await q(`SELECT count(*)::int n FROM public.notifications WHERE idempotency_key = 'chat-msg-${r1.rows[0].id}'`);
check('retry creates exactly one notification', notif[0].n === 1);
const nB = await as(SELLER, `SELECT action_url, payload FROM public.notifications WHERE user_id = '${SELLER}' AND event_type = 'CHAT_MESSAGE'`);
check('recipient notification routes to the conversation, without the body',
  nB.ok && nB.rows.length >= 2 && nB.rows.every((n) => n.action_url === `/chats/${convB}` && !JSON.stringify(n.payload).includes('B5')));
const bad = await sendTo(BROKER, '   ', BUYER2);
check('invalid body is rejected', !bad.ok);
const badConv = await q(`SELECT count(*)::int n FROM public.chat_conversations WHERE buyer_id='${BUYER2}' AND broker_id='${BROKER}'`);
check('a rejected first send leaves no empty conversation', badConv[0].n === 0);

// --- Contacts for context ---
const cReq = await as(BROKER, 'SELECT * FROM public.chat_contacts_for_context($1, NULL)', [REQ]);
check('broker gets the requirement buyer as chat contact', cReq.ok && cReq.rows.length === 1 && cReq.rows[0].user_id === BUYER && cReq.rows[0].role === 'buyer');
const cLot = await as(BROKER, 'SELECT * FROM public.chat_contacts_for_context(NULL, $1)', [LOT]);
check('broker gets the lot seller as chat contact', cLot.ok && cLot.rows.length === 1 && cLot.rows[0].user_id === SELLER);
const cOther = await as(BROKER2, 'SELECT * FROM public.chat_contacts_for_context($1, $2)', [REQ, LOT]);
check('another broker gets no contacts for a desk it does not own', cOther.ok && cOther.rows.length === 0);
const cBuyer = await as(BUYER, 'SELECT * FROM public.chat_contacts_for_context(NULL, $1)', [LOT]);
check('a buyer cannot resolve the seller of a lot', cBuyer.ok && cBuyer.rows.length === 0);
check('contacts expose no phone/email', !Object.keys(cReq.rows?.[0] ?? {}).some((c) => /mobile|phone|email/.test(c)));
const helper = await as(BROKER, 'SELECT public.chat_broker_may_contact($1, $2)', [BROKER, BUYER]);
check('internal relationship helper is not callable by clients', !helper.ok);

// --- Rollback ---
await db.exec(read('proposed', 'rollback_0066.sql'));
const rbBroker = await sendTo(BROKER, 'after rollback', BUYER);
check('rollback removes broker-initiated chat', !rbBroker.ok);
const rbBuyer = await send(BUYER, 'still works', { conv: convA });
check('rollback keeps buyer conversations working (0043)', rbBuyer.ok, rbBuyer.msg);
const rbSeller = await send(SELLER, 'after rollback', { conv: convB });
check('rollback: seller conversations stop taking messages', !rbSeller.ok);

const failed = results.filter((r) => !r.ok).length;
console.log(`\n${results.length - failed}/${results.length} passed`);
process.exit(failed ? 1 : 0);
