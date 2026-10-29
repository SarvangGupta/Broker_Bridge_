// RMBUYER-GST-BACKEND-01 — offline security tests for proposed 0053 + 0054.
//
// Loads a schema-only extract of the live tables (users, companies, crm_contacts,
// notifications + their functions, policies, triggers, grants — no rows) into
// PGlite with minimal Supabase auth/storage stubs, applies the migrations and
// runs every case as a real `authenticated` session (SET ROLE + JWT sub claim),
// so grants, RLS, invoker/definer rights and triggers execute for real.
//
// NOT covered here (needs a Supabase project): PostgREST, Auth sign-in, Storage
// API size/MIME enforcement, signed URLs, true concurrent sessions.
//
// Usage: node gst_backend_offline_test.mjs <repoRoot> <baseline_schema.sql> <pgliteModuleDir>
import fs from 'node:fs';
import path from 'node:path';
import { createRequire } from 'node:module';
import { pathToFileURL } from 'node:url';

const [repoRoot, baselineFile, pgliteDir] = process.argv.slice(2);
process.on('uncaughtException', (e) => { console.log(`FATAL ${e.code ?? ''} ${e.message}`); process.exit(2); });
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
const one = async (sql, params) => Object.values((await q(sql, params))[0] ?? {})[0];

// Run [fn] as an authenticated API session for [uid]. Returns {ok, rows, code, msg}.
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

// --- GSTIN helper (same algorithm as the app and gstin_is_valid) ---
const CH = '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ';
const gstin = (first14) => {
  let s = 0;
  for (let i = 0; i < 14; i++) { const p = CH.indexOf(first14[i]) * (i % 2 === 0 ? 1 : 2); s += Math.floor(p / 36) + (p % 36); }
  return first14 + CH[(36 - (s % 36)) % 36];
};
const G_A = gstin('08AAAAA1111A1Z');   // Rajasthan
const G_A2 = gstin('08AAAAA1111A2Z');  // Rajasthan, second registration
const G_S = gstin('24CCCCC3333C1Z');   // Gujarat, held by a Seller company
const badChecksum = G_A.slice(0, 14) + (G_A[14] === 'A' ? 'B' : 'A');

// --- 1. Supabase platform stubs ---
await db.exec(`
  CREATE ROLE anon NOLOGIN; CREATE ROLE authenticated NOLOGIN; CREATE ROLE service_role NOLOGIN BYPASSRLS;
  CREATE SCHEMA auth;
  CREATE TABLE auth.users (id uuid PRIMARY KEY, email text,
    raw_user_meta_data jsonb DEFAULT '{}'::jsonb, raw_app_meta_data jsonb DEFAULT '{}'::jsonb);
  CREATE FUNCTION auth.uid() RETURNS uuid LANGUAGE sql STABLE AS
    $$ SELECT nullif(current_setting('request.jwt.claim.sub', true), '')::uuid $$;
  GRANT USAGE ON SCHEMA auth TO authenticated, anon;
  GRANT EXECUTE ON FUNCTION auth.uid() TO authenticated, anon;
  CREATE SCHEMA storage;
  CREATE TABLE storage.buckets (id text PRIMARY KEY, name text, public boolean DEFAULT false,
    file_size_limit bigint, allowed_mime_types text[]);
  CREATE TABLE storage.objects (id uuid PRIMARY KEY DEFAULT gen_random_uuid(), bucket_id text, name text,
    owner uuid DEFAULT nullif(current_setting('request.jwt.claim.sub', true), '')::uuid,
    owner_id text DEFAULT nullif(current_setting('request.jwt.claim.sub', true), ''),
    metadata jsonb, UNIQUE (bucket_id, name));
  CREATE FUNCTION storage.foldername(name text) RETURNS text[] LANGUAGE sql IMMUTABLE AS
    $$ SELECT (string_to_array(name, '/'))[1:array_length(string_to_array(name, '/'), 1) - 1] $$;
  ALTER TABLE storage.objects ENABLE ROW LEVEL SECURITY;
  GRANT USAGE ON SCHEMA storage TO authenticated, anon;
  GRANT SELECT, INSERT, UPDATE, DELETE ON storage.objects TO authenticated;
  GRANT SELECT ON storage.buckets TO authenticated;
  GRANT EXECUTE ON FUNCTION storage.foldername(text) TO authenticated;
`);

// --- 2. Live schema-only baseline ---
await db.exec(fs.readFileSync(baselineFile, 'utf8'));
check('baseline: live schema-only extract loads', true);

// --- 3. Synthetic seed (postgres session = trusted server path) ---
const U = {
  buyerA: 'a0000000-0000-4000-8000-00000000000a', buyerA2: 'a0000000-0000-4000-8000-0000000000a2',
  buyerB: 'b0000000-0000-4000-8000-00000000000b', seller: 'c0000000-0000-4000-8000-00000000000c',
  broker: 'd0000000-0000-4000-8000-00000000000d', admin: 'e0000000-0000-4000-8000-00000000000e',
  legacyBuyer: 'f0000000-0000-4000-8000-00000000000f',
};
const C = {
  A: '1a000000-0000-4000-8000-00000000000a', B: '1b000000-0000-4000-8000-00000000000b',
  S: '1c000000-0000-4000-8000-00000000000c', K: '1d000000-0000-4000-8000-00000000000d',
  crm: '1e000000-0000-4000-8000-00000000000e', other: '1f000000-0000-4000-8000-00000000000f',
  legacy: '10000000-0000-4000-8000-000000000010',
};
for (const [k, id] of Object.entries(U)) await db.query(`INSERT INTO auth.users (id, email) VALUES ($1, $2)`, [id, `${k}@test.invalid`]);
await db.exec(`
  INSERT INTO public.companies (id, name, gst, is_verified, created_by) VALUES
    ('${C.A}', 'Buyer A Feeds', NULL, false, NULL), ('${C.B}', 'Buyer B Agro', NULL, false, NULL),
    ('${C.S}', 'Seller S Mills', '${G_S}', true, NULL), ('${C.K}', 'Broker K Desk', NULL, false, NULL),
    ('${C.crm}', 'CRM Counterparty', NULL, false, NULL), ('${C.other}', 'Unrelated Co', NULL, false, NULL),
    ('${C.legacy}', 'Legacy Verified Buyer', NULL, true, NULL);
  INSERT INTO public.users (id, name, role, company_id, created_by) VALUES
    ('${U.buyerA}', 'Buyer A', 'buyer', '${C.A}', NULL), ('${U.buyerA2}', 'Buyer A2', 'buyer', '${C.A}', NULL),
    ('${U.buyerB}', 'Buyer B', 'buyer', '${C.B}', NULL), ('${U.seller}', 'Seller S', 'seller', '${C.S}', NULL),
    ('${U.broker}', 'Broker K', 'broker', '${C.K}', NULL), ('${U.admin}', 'Admin', 'admin', NULL, NULL),
    ('${U.legacyBuyer}', 'Legacy Buyer', 'buyer', '${C.legacy}', NULL);
  UPDATE public.companies SET created_by = '${U.broker}' WHERE id = '${C.crm}';
  INSERT INTO public.crm_contacts (broker_id, company_id) VALUES ('${U.broker}', '${C.crm}');
`);
check('seed: trusted roles synced into app_metadata by the live trigger',
  (await one(`SELECT raw_app_meta_data->>'role' FROM auth.users WHERE id = '${U.admin}'`)) === 'admin');

// --- 4. Pre-migration exposure (reproduces the live gap) ---
const pre = await as(U.buyerA, `UPDATE public.companies SET is_verified = true, trust_score = 1 WHERE id = '${C.A}'`);
check('BEFORE 0053: buyer CAN self-verify own company (live exposure reproduced)', pre.ok && pre.affected === 1);
await db.exec(`UPDATE public.companies SET is_verified = false, trust_score = 100 WHERE id = '${C.A}'`);

// --- 5. Apply 0053 ---
await db.exec(proposed('0053_protect_company_trust_fields.sql'));
check('0053 applies', true);

const denied = (r) => !r.ok && r.code === '42501';
for (const [col, val] of [['is_verified', 'true'], ['trust_score', '1'], ['bank_is_verified', 'true'],
  ['bank_verification_status', `'verified'`], ['created_by', `'${U.buyerA}'`], ['status', 'false'],
  ['id', `'${C.other}'`]]) {
  check(`G-1 buyer cannot change own companies.${col}`,
    denied(await as(U.buyerA, `UPDATE public.companies SET ${col} = ${val} WHERE id = '${C.A}'`)));
}
check('G-1 seller cannot self-verify own company',
  denied(await as(U.seller, `UPDATE public.companies SET trust_score = 5 WHERE id = '${C.S}'`)));

// Mutation check: with the trigger disabled the same write succeeds, so G-1 would catch a silent fail-open.
await db.exec(`ALTER TABLE public.companies DISABLE TRIGGER trg_protect_company_trust_fields`);
const mut = await as(U.buyerA, `UPDATE public.companies SET is_verified = true WHERE id = '${C.A}'`);
check('G-1 mutation check: guard disabled ⇒ self-verify succeeds (test is meaningful)', mut.ok && mut.affected === 1);
await db.exec(`UPDATE public.companies SET is_verified = false WHERE id = '${C.A}'`);
await db.exec(`ALTER TABLE public.companies ENABLE TRIGGER trg_protect_company_trust_fields`);

const edit = await as(U.buyerA, `UPDATE public.companies SET name = 'Buyer A Feeds Pvt', state_id = 'RJ', district_id = 'Jaipur' WHERE id = '${C.A}'`);
check('G-2 buyer profile edit (name/state/district) still works', edit.ok && edit.affected === 1);
const sEdit = await as(U.seller, `UPDATE public.companies SET name = 'Seller S Mills Ltd', gst = '${G_S}' WHERE id = '${C.S}'`);
check('G-2 seller profile save (name, gst, state, district) still works', sEdit.ok && sEdit.affected === 1);
const bkName = await as(U.broker, `UPDATE public.companies SET name = 'Broker K Desk Pvt' WHERE id = '${C.K}'`);
check('G-2 broker own profile name update still works', bkName.ok && bkName.affected === 1);

const ins = await as(U.broker, `INSERT INTO public.companies (name, status, is_verified, trust_score, bank_is_verified, created_by)
  VALUES ('Broker-made Co', true, true, 50, true, '${U.broker}') RETURNING is_verified, trust_score, bank_is_verified`);
check('G-3 broker directory insert: client-sent is_verified/trust forced to safe defaults',
  ins.ok && ins.rows[0].is_verified === false && ins.rows[0].trust_score === 100 && ins.rows[0].bank_is_verified === false);

const bStatus = await as(U.broker, `UPDATE public.companies SET status = false, name = 'CRM Counterparty' WHERE id = '${C.crm}'`);
check('G-4 broker directory edit of a CRM counterparty status still works', bStatus.ok && bStatus.affected === 1);
// Own company has created_by IS NULL: regression for a NULL-logic fail-open found in this sprint.
check('G-4 broker cannot change own company status (created_by NULL)',
  denied(await as(U.broker, `UPDATE public.companies SET status = false WHERE id = '${C.K}'`)));
const bOther = await as(U.broker, `UPDATE public.companies SET status = false WHERE id = '${C.other}'`);
check('G-4 broker cannot change an unrelated company status', !bOther.ok || bOther.affected === 0);
check('G-4 broker cannot verify a CRM counterparty',
  denied(await as(U.broker, `UPDATE public.companies SET is_verified = true WHERE id = '${C.crm}'`)));

const adm = await as(U.admin, `UPDATE public.companies SET trust_score = 90 WHERE id = '${C.S}'`);
check('G-5 admin (trusted app_metadata role) can still change trust fields', adm.ok && adm.affected === 1);
const fakeAdmin = 'a9000000-0000-4000-8000-0000000000a9';
await db.query(`INSERT INTO auth.users (id, raw_user_meta_data) VALUES ($1, '{"role":"admin"}')`, [fakeAdmin]);
check('G-5 a user_metadata "admin" claim is not trusted by is_admin()',
  (await as(fakeAdmin, `SELECT public.is_admin() AS a`)).rows?.[0]?.a === false);
await db.exec(`UPDATE public.companies SET status = true WHERE id = '${C.A}'`);
check('G-6 server path (postgres, e.g. web Company Approvals status) unaffected', true);
const del = await as(U.buyerA, `DELETE FROM public.companies WHERE id = '${C.A}'`);
check('G-7 DELETE on companies no longer granted to authenticated', denied(del));

// --- 6. Apply 0054 ---
await db.exec(proposed('0054_buyer_gst_verification.sql'));
check('0054 applies', true);
check('0054 SQL checksum agrees with app vectors',
  (await one(`SELECT public.gstin_is_valid($1)`, [G_A])) === true &&
  (await one(`SELECT public.gstin_is_valid($1)`, [badChecksum])) === false &&
  (await one(`SELECT public.gstin_is_valid('08ADRPK6597J1ZL')`)) === true);
check('legacy company flag left unchanged by migrations',
  (await one(`SELECT is_verified FROM public.companies WHERE id = '${C.legacy}'`)) === true &&
  (await one(`SELECT count(*)::int FROM public.buyer_gst_verifications WHERE company_id = '${C.legacy}'`)) === 0);
check('legacy web "Company Approvals" cannot verify a Buyer company without GST review',
  await db.exec(`UPDATE public.companies SET is_verified = true WHERE id = '${C.B}'`).then(() => false, (e) => e.code === '42501'));
check('legacy web "Company Approvals" can still verify a Seller company',
  await db.exec(`UPDATE public.companies SET is_verified = false WHERE id = '${C.S}'; UPDATE public.companies SET is_verified = true WHERE id = '${C.S}'`).then(() => true, () => false));

const bucket = (await q(`SELECT public, file_size_limit, allowed_mime_types FROM storage.buckets WHERE id = 'brokerbridge_buyer_gst_certificates'`))[0];
check('ST-0 bucket private, 5 MB, JPG/PNG only', bucket.public === false && Number(bucket.file_size_limit) === 5242880 &&
  JSON.stringify(bucket.allowed_mime_types) === JSON.stringify(['image/jpeg', 'image/png']));

// --- 7. Storage policies ---
const uuid = () => crypto.randomUUID();
const put = (uid, name) => as(uid, `INSERT INTO storage.objects (bucket_id, name) VALUES ('brokerbridge_buyer_gst_certificates', $1)`, [name]);
const pathA = `${U.buyerA}/${uuid()}.jpg`;
check('ST-1 buyer uploads into own folder', (await put(U.buyerA, pathA)).ok);
check('ST-2 buyer cannot upload into another user\'s folder', denied(await put(U.buyerA, `${U.buyerB}/${uuid()}.jpg`)));
check('ST-3 seller cannot upload GST certificates', denied(await put(U.seller, `${U.seller}/${uuid()}.jpg`)));
check('ST-3 broker cannot upload GST certificates', denied(await put(U.broker, `${U.broker}/${uuid()}.jpg`)));
check('ST-4 non-JPG/PNG or nested names rejected', denied(await put(U.buyerA, `${U.buyerA}/${uuid()}.pdf`)) &&
  denied(await put(U.buyerA, `${U.buyerA}/x/${uuid()}.jpg`)));
const sel = async (uid) => (await as(uid, `SELECT count(*)::int n FROM storage.objects WHERE name = $1`, [pathA])).rows[0].n;
check('ST-5 owner reads own certificate', (await sel(U.buyerA)) === 1);
check('ST-5 other buyer, seller and broker cannot read it',
  (await sel(U.buyerB)) === 0 && (await sel(U.seller)) === 0 && (await sel(U.broker)) === 0);
check('ST-5 admin can read it (for 60 s signed preview)', (await sel(U.admin)) === 1);
const ow = await as(U.buyerA, `UPDATE storage.objects SET name = name || 'x' WHERE name = $1`, [pathA]);
const dl = await as(U.buyerA, `DELETE FROM storage.objects WHERE name = $1`, [pathA]);
check('ST-6 no overwrite or delete, even by the owner', ow.affected === 0 && dl.affected === 0 &&
  (await one(`SELECT count(*)::int FROM storage.objects WHERE name = $1`, [pathA])) === 1);

// --- 8. Submission ---
const draft = (g, over = {}) => ({
  submitted: { gstin: g, legalName: 'BUYER A PROPRIETOR', tradeName: 'Buyer A Feeds', constitution: 'Proprietorship',
    address: 'A-6, Bani Park, Jaipur, Rajasthan, 302006', pinCode: '302006', registrationDate: '01/07/2017',
    registrationType: 'Regular', validityFrom: null, validityTo: 'Not Applicable', issueDate: '16/06/2022', ...over },
  ocr: { gstin: g, legalName: 'BUYER A PROPRIETOR', tradeName: 'Buyer A Paslhu Feeds', constitution: 'Proprietorship',
    address: 'A-6, Bani Park, Jaipur, Rajasthan, 302006', pinCode: '302006', registrationDate: '01/07/2017',
    registrationType: 'Regular', validityFrom: null, validityTo: 'Not Applicable', issueDate: '16/06/2022' },
  edited_fields: [], status: 'approved', company_id: C.B, reviewed_by: U.buyerA,
});
const submit = (uid, d, p) => as(uid, `SELECT * FROM public.submit_buyer_gst_verification($1::jsonb, $2)`, [JSON.stringify(d), p]);

const s1 = await submit(U.buyerA, draft(G_A), pathA);
const row1 = s1.rows?.[0];
check('S-1 buyer submission succeeds and returns the saved row', s1.ok && row1?.status === 'pending', s1.msg ?? '');
check('S-2 forged status/company/reviewer in payload ignored',
  row1?.company_id === C.A && row1?.reviewed_by === null && row1?.submitted_by === U.buyerA);
check('S-3 edited_fields recomputed server-side', JSON.stringify(row1?.edited_fields) === JSON.stringify(['tradeName']));
check('S-3 reviewed values persisted (dates parsed, absent values null)',
  row1?.trade_name === 'Buyer A Feeds' && row1?.validity_from === null && row1?.validity_to === 'Not Applicable' &&
  new Date(row1?.registration_date).getUTCFullYear() === 2017);
check('S-4 "submitted" history event written',
  (await one(`SELECT count(*)::int FROM public.buyer_gst_verification_events WHERE verification_id = $1 AND event = 'submitted'`, [row1.id])) === 1);
check('S-4 company flag NOT set by submission',
  (await one(`SELECT is_verified FROM public.companies WHERE id = '${C.A}'`)) === false);

const pathB = `${U.buyerB}/${uuid()}.png`;
await put(U.buyerB, pathB);
check('S-5 cannot submit someone else\'s certificate path', denied(await submit(U.buyerA, draft(G_A2), pathB)));
check('S-5 cannot submit a path with no uploaded object', denied(await submit(U.buyerA, draft(G_A2), `${U.buyerA}/${uuid()}.jpg`)));
const bad = async (d) => { const p = `${U.buyerA}/${uuid()}.jpg`; await put(U.buyerA, p); return submit(U.buyerA, d, p); };
const inv = (r) => !r.ok && r.code === '22023';
check('S-6 bad checksum rejected', inv(await bad(draft(badChecksum))));
check('S-6 state mismatch rejected', inv(await bad(draft(G_A2, { address: 'Plot 1, Ahmedabad, Gujarat, 380001', pinCode: '380001' }))));
check('S-6 missing legal name rejected', inv(await bad(draft(G_A2, { legalName: '  ' }))));
check('S-6 bad date rejected (never guessed)', inv(await bad(draft(G_A2, { issueDate: '2022.06.16' }))));
check('S-7 seller cannot submit', denied(await submit(U.seller, draft(G_A2), `${U.seller}/${uuid()}.jpg`)));
check('S-7 broker cannot submit', denied(await submit(U.broker, draft(G_A2), `${U.broker}/${uuid()}.jpg`)));

const pathB2 = `${U.buyerB}/${uuid()}.jpg`; await put(U.buyerB, pathB2);
const dup = await submit(U.buyerB, draft(G_A), pathB2);
check('S-8 another company cannot hold the same active GSTIN (23505)', !dup.ok && dup.code === '23505');

const pathA2 = `${U.buyerA}/${uuid()}.jpg`; await put(U.buyerA, pathA2);
const s2 = await submit(U.buyerA2, draft(G_A), pathA2);
check('S-9 a co-worker cannot submit another user\'s upload', denied(s2));
const pathA2own = `${U.buyerA2}/${uuid()}.jpg`; await put(U.buyerA2, pathA2own);
const s3 = await submit(U.buyerA2, draft(G_A, { tradeName: 'Buyer A Feeds Co' }), pathA2own);
check('S-9 replacing a pending submission keeps history (old → superseded, "replaced" event)', s3.ok &&
  (await one(`SELECT status FROM public.buyer_gst_verifications WHERE id = $1`, [row1.id])) === 'superseded' &&
  (await one(`SELECT count(*)::int FROM public.buyer_gst_verification_events WHERE verification_id = $1 AND event = 'replaced'`, [row1.id])) === 1 &&
  (await one(`SELECT count(*)::int FROM public.buyer_gst_verifications WHERE company_id = '${C.A}' AND status = 'pending'`)) === 1);
const pendingA = s3.rows[0];

const pathB3 = `${U.buyerB}/${uuid()}.jpg`; await put(U.buyerB, pathB3);
const sc = await submit(U.buyerB, draft(G_S, { address: 'Plot 9, GIDC, Ahmedabad, Gujarat, 380001', pinCode: '380001' }), pathB3);
check('S-10 GSTIN held by a Seller company is flagged, not rejected', sc.ok && sc.rows[0].seller_gstin_conflict === true, sc.msg ?? '');

check('S-11 buyer cannot INSERT/UPDATE verification rows directly',
  denied(await as(U.buyerA, `UPDATE public.buyer_gst_verifications SET status = 'approved' WHERE id = $1`, [pendingA.id])) &&
  denied(await as(U.buyerA, `INSERT INTO public.buyer_gst_verification_events (verification_id, company_id, event, to_status, actor_id) VALUES ($1, '${C.A}', 'approved', 'approved', '${U.buyerA}')`, [pendingA.id])));
const vis = async (uid) => (await as(uid, `SELECT count(*)::int n FROM public.buyer_gst_verifications WHERE company_id = '${C.A}'`)).rows[0].n;
check('S-12 company members read own records; other buyer/seller/broker read none; admin reads all',
  (await vis(U.buyerA)) === 2 && (await vis(U.buyerA2)) === 2 && (await vis(U.buyerB)) === 0 &&
  (await vis(U.seller)) === 0 && (await vis(U.broker)) === 0 && (await vis(U.admin)) === 2);

// --- 9. Review ---
const review = (uid, id, d, r = null) => as(uid, `SELECT * FROM public.review_buyer_gst_verification($1, $2, $3)`, [id, d, r]);
check('R-1 buyer cannot review (self-approve)', denied(await review(U.buyerA, pendingA.id, 'approve')));
check('R-1 broker cannot review', denied(await review(U.broker, pendingA.id, 'approve')));
check('R-1 user_metadata "admin" cannot review', denied(await review(fakeAdmin, pendingA.id, 'approve')));
// Roleless account: is_admin() returns NULL, not false — regression for a NULL fail-open.
const roleless = 'a8000000-0000-4000-8000-0000000000a8';
await db.query(`INSERT INTO auth.users (id) VALUES ($1)`, [roleless]);
await db.query(`INSERT INTO public.users (id, name, role, company_id, created_by) VALUES ($1, 'No Role', NULL, $2, NULL)`, [roleless, C.A]);
{
  const r = (await as(roleless, `SELECT public.is_admin() AS a, public.get_auth_role() AS r`)).rows?.[0];
  console.log(`INFO roleless account: is_admin()=${r?.a} get_auth_role()=${JSON.stringify(r?.r)}`);
  const anon = (await as('a7000000-0000-4000-8000-0000000000a7', `SELECT public.is_admin() AS a`)).rows?.[0];
  console.log(`INFO unknown auth.uid (no auth.users row): is_admin()=${anon?.a}`);
}
check('R-1 roleless account cannot review', denied(await review(roleless, pendingA.id, 'approve')));
// A still-valid JWT for a deleted account: is_admin() is NULL here, so the RPC must fail closed.
check('R-1 deleted-account JWT (is_admin() NULL) cannot review',
  denied(await review('a7000000-0000-4000-8000-0000000000a7', pendingA.id, 'approve')) &&
  (await one(`SELECT status FROM public.buyer_gst_verifications WHERE id = $1`, [pendingA.id])) === 'pending');
check('R-2 reject without reason refused', inv(await review(U.admin, pendingA.id, 'reject', '  ')));
const rj = await review(U.admin, pendingA.id, 'reject', 'Certificate image is cut off');
check('R-3 admin rejects with reason; reviewer + timestamp recorded', rj.ok && rj.rows[0].status === 'rejected' &&
  rj.rows[0].reviewed_by === U.admin && rj.rows[0].rejection_reason === 'Certificate image is cut off');
const notes = async (ev) => one(`SELECT count(*)::int FROM public.notifications WHERE event_type = $1 AND company_id = '${C.A}'`, [ev]);
check('R-3 exactly one notification per buyer user of the company', (await notes('GST_VERIFICATION_REJECTED')) === 2);
check('R-4 a decided submission cannot be reviewed again', inv(await review(U.admin, pendingA.id, 'approve')));
check('R-4 rejected → approved transition blocked even for postgres',
  await db.exec(`UPDATE public.buyer_gst_verifications SET status = 'approved', reviewed_by = '${U.admin}', reviewed_at = now() WHERE id = '${pendingA.id}'`).then(() => false, (e) => e.code === '22023'));

const pathA3 = `${U.buyerA}/${uuid()}.jpg`; await put(U.buyerA, pathA3);
const s4 = await submit(U.buyerA, draft(G_A), pathA3);
check('R-5 resubmission after rejection creates a new pending row', s4.ok && s4.rows[0].status === 'pending');
const ap = await review(U.admin, s4.rows[0].id, 'approve');
const coA = (await q(`SELECT is_verified, gst, name FROM public.companies WHERE id = '${C.A}'`))[0];
check('R-6 approval sets is_verified + gst; company name NOT overwritten', ap.ok && coA.is_verified === true &&
  coA.gst === G_A && coA.name === 'Buyer A Feeds Pvt');
check('R-6 one approval notification per buyer user', (await notes('GST_VERIFICATION_APPROVED')) === 2);
check('R-6 approval event recorded with admin actor',
  (await one(`SELECT actor_id::text FROM public.buyer_gst_verification_events WHERE verification_id = $1 AND event = 'approved'`, [s4.rows[0].id])) === U.admin);

check('R-7 buyer cannot change companies.gst directly while approved',
  denied(await as(U.buyerA, `UPDATE public.companies SET gst = '${G_A2}' WHERE id = '${C.A}'`)));
check('R-7 roleless company member cannot change companies.gst while approved',
  denied(await as(roleless, `UPDATE public.companies SET gst = '${G_A2}' WHERE id = '${C.A}'`)));
check('R-7 roleless company member cannot self-verify either',
  denied(await as(roleless, `UPDATE public.companies SET trust_score = 3 WHERE id = '${C.A}'`)));
const pathA4 = `${U.buyerA}/${uuid()}.jpg`; await put(U.buyerA, pathA4);
check('R-8 resubmitting identical approved details refused', inv(await submit(U.buyerA, draft(G_A), pathA4)));
const s5 = await submit(U.buyerA, draft(G_A2), pathA4);
check('R-8 material GSTIN change: approval superseded, is_verified cleared, new pending', s5.ok &&
  (await one(`SELECT status FROM public.buyer_gst_verifications WHERE id = $1`, [s4.rows[0].id])) === 'superseded' &&
  (await one(`SELECT is_verified FROM public.companies WHERE id = '${C.A}'`)) === false &&
  (await one(`SELECT count(*)::int FROM public.buyer_gst_verification_events WHERE verification_id = $1 AND event = 'superseded'`, [s4.rows[0].id])) === 1);

check('R-9 history is append-only (even for postgres)',
  await db.exec(`UPDATE public.buyer_gst_verification_events SET reason = 'x'`).then(() => false, (e) => e.code === '42501') &&
  await db.exec(`DELETE FROM public.buyer_gst_verification_events`).then(() => false, (e) => e.code === '42501'));
check('R-9 submitted details immutable (even for postgres)',
  await db.exec(`UPDATE public.buyer_gst_verifications SET gstin = '${G_A2}' WHERE id = '${s4.rows[0].id}'`).then(() => false, (e) => e.code === '42501'));

// Atomicity: a failure after the status update must roll the whole review back.
await db.exec(`CREATE OR REPLACE FUNCTION public._fail_notif() RETURNS trigger LANGUAGE plpgsql AS $$ BEGIN RAISE EXCEPTION 'boom'; END $$;
  CREATE TRIGGER _fail BEFORE INSERT ON public.notifications FOR EACH ROW EXECUTE FUNCTION public._fail_notif();`);
const atom = await review(U.admin, s5.rows[0].id, 'approve');
await db.exec(`DROP TRIGGER _fail ON public.notifications; DROP FUNCTION public._fail_notif();`);
check('R-10 failed review leaves status, company flag and history unchanged', !atom.ok &&
  (await one(`SELECT status FROM public.buyer_gst_verifications WHERE id = $1`, [s5.rows[0].id])) === 'pending' &&
  (await one(`SELECT is_verified FROM public.companies WHERE id = '${C.A}'`)) === false &&
  (await one(`SELECT count(*)::int FROM public.buyer_gst_verification_events WHERE verification_id = $1 AND event = 'approved'`, [s5.rows[0].id])) === 0);

// --- 10. Rollback and re-apply ---
await db.exec(proposed('rollback_0054.sql'));
await db.exec(proposed('rollback_0053.sql'));
check('rollback: 0054 objects removed, legacy flag intact',
  (await one(`SELECT count(*)::int FROM information_schema.tables WHERE table_name LIKE 'buyer_gst%'`)) === 0 &&
  (await one(`SELECT is_verified FROM public.companies WHERE id = '${C.legacy}'`)) === true);
const after = await as(U.buyerA, `UPDATE public.companies SET trust_score = 7 WHERE id = '${C.A}'`);
check('rollback: 0053 guard removed (pre-0053 behaviour restored exactly)', after.ok && after.affected === 1);
await db.exec(`DELETE FROM storage.objects WHERE bucket_id = 'brokerbridge_buyer_gst_certificates'`);
await db.exec(proposed('0053_protect_company_trust_fields.sql'));
await db.exec(proposed('0054_buyer_gst_verification.sql'));
await db.exec(proposed('0053_protect_company_trust_fields.sql'));
await db.exec(proposed('0054_buyer_gst_verification.sql'));
check('re-apply: 0053 and 0054 are idempotent', true);

const failed = results.filter((r) => !r.ok).length;
console.log(`\n${results.length - failed} passed, ${failed} failed`);
process.exit(failed ? 1 : 0);
