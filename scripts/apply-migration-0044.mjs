// RB-SELLER-AVAILABILITY-RLS-FIX-01 — apply approved migration 0044 (A+B+C+D).
// One transaction: apply SQL, run impersonated validation on synthetic rows inside a
// savepoint that is always rolled back, then COMMIT only if every check passed.
// Prints pass/fail only (no ids, no personal data, no secrets).
import postgres from 'postgres';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const root = path.join(path.dirname(fileURLToPath(import.meta.url)), '..');
const env = Object.fromEntries(
  fs.readFileSync(path.join(root, '.env.local'), 'utf8').split(/\r?\n/)
    .filter((l) => /^[A-Z_]+=/.test(l))
    .map((l) => [l.slice(0, l.indexOf('=')), l.slice(l.indexOf('=') + 1).replace(/^"|"$/g, '')]),
);
if (!env.DATABASE_URL) throw new Error('DATABASE_URL is not set.');

const migration = fs
  .readFileSync(path.join(root, 'supabase/migrations/0044_allow_sellers_own_availabilities.sql'), 'utf8')
  .split(/\r?\n/)
  .filter((l) => !/^\s*(BEGIN|COMMIT);\s*$/.test(l)) // we own the transaction
  .join('\n');

const DRY_RUN = process.argv.includes('--dry-run');
const sql = postgres(env.DATABASE_URL, { prepare: false, max: 1 });
const ROLLBACK = new Error('ROLLBACK_SAVEPOINT');
const results = [];
const record = (n, name, ok, detail = '') => {
  results.push(ok);
  console.log(`${ok ? 'PASS' : 'FAIL'} #${n} ${name}${detail ? ' — ' + detail : ''}`);
};

async function as(t, role, userId) {
  await t.unsafe(`SET LOCAL ROLE ${role}`);
  await t`select set_config('request.jwt.claims', ${JSON.stringify(userId ? { sub: userId, role } : { role })}, true)`;
}
async function asOwner(t) {
  await t.unsafe('RESET ROLE');
  await t`select set_config('request.jwt.claims', '', true)`;
}
// Runs fn in a savepoint and reports the SQLSTATE it raised (null = succeeded).
async function codeOf(t, fn) {
  try {
    let out;
    await t.savepoint(async (sp) => { out = await fn(sp); throw ROLLBACK; });
    return { code: null, out };
  } catch (e) {
    if (e === ROLLBACK) return { code: null };
    return { code: e.code ?? 'ERR' };
  }
}

let committed = false;
try {
  await sql.begin(async (t) => {
    // ---- fixtures (owner role; read-only lookups) ----
    const [seller] = await t`
      select u.id, u.company_id from public.users u join auth.users a on a.id = u.id
      where lower(u.role) = 'seller' and u.status = true and u.company_id is not null
        and lower(coalesce(a.raw_app_meta_data->>'role','')) = 'seller' limit 1`;
    const [other] = await t`select id from public.companies where id <> ${seller.company_id} limit 1`;
    const [buyer] = await t`
      select u.id from public.users u join auth.users a on a.id = u.id
      where lower(u.role) = 'buyer' limit 1`;
    const [broker] = await t`
      select u.id from public.users u join auth.users a on a.id = u.id
      where lower(coalesce(a.raw_app_meta_data->>'role','')) = 'broker' limit 1`;
    const [m] = await t`
      select g.commodity_id, g.id as grade_id,
             (select id from public.master_units limit 1) as unit_id,
             d.state_id, d.id as district_id
      from public.master_grades g, public.master_districts d limit 1`;
    if (!seller || !other || !buyer || !broker || !m) throw new Error('missing fixture');

    const lot = (company, extra = {}) => ({
      company_id: company, commodity_id: m.commodity_id, grade_id: m.grade_id,
      quantity: 1, unit_id: m.unit_id, price: '1', state_id: m.state_id,
      district_id: m.district_id, valid_until: new Date(Date.now() + 864e5),
      total_quantity: '1', available_quantity: '1', asking_price: '1',
      lot_number: 'RLS-0044-SYNTHETIC', ...extra,
    });

    // ---- apply ----
    await t.unsafe(migration);
    console.log('Migration 0044 statements executed (uncommitted).');

    // ---- validation on synthetic rows: whole block rolled back ----
    try {
      await t.savepoint(async (s) => {
        // Synthetic lot of ANOTHER company, created as owner, restricted.
        const [foreign] = await s`insert into public.availabilities ${s(lot(other.id, { visibility: 'restricted' }))} returning id`;

        await as(s, 'authenticated', seller.id);
        // 1
        const r1 = await codeOf(s, (x) => x`insert into public.availabilities ${x(lot(seller.company_id, { visibility: 'restricted' }))} returning id`);
        record(1, 'seller inserts own-company restricted lot with RETURNING', r1.code === null, r1.code ?? '');
        const [own] = await s`insert into public.availabilities ${s(lot(seller.company_id, { visibility: 'restricted' }))} returning id`;
        // 2
        const r2 = await codeOf(s, (x) => x`insert into public.availabilities ${x(lot(other.id))} returning id`);
        record(2, 'seller insert for another company rejected', r2.code === '42501', r2.code ?? 'succeeded');
        // 3
        const seeOwn = await s`select 1 from public.availabilities where id = ${own.id}`;
        const seeForeign = await s`select 1 from public.availabilities where id = ${foreign.id}`;
        record(3, 'seller sees own restricted lot, not another company\'s', seeOwn.length === 1 && seeForeign.length === 0);
        // 4
        const upOwn = await s`update public.availabilities set asking_price = 2, price = 2 where id = ${own.id} returning id`;
        const upForeign = await s`update public.availabilities set asking_price = 2 where id = ${foreign.id} returning id`;
        record(4, 'seller updates own lot (1 row), not another company\'s (0 rows)', upOwn.length === 1 && upForeign.length === 0);
        // 5
        const r5 = await codeOf(s, (x) => x`update public.availabilities set company_id = ${other.id} where id = ${own.id}`);
        record(5, 'seller cannot move own lot to another company', r5.code === '42501', r5.code ?? 'succeeded');
        // 6
        const r6 = await codeOf(s, (x) => x`update public.users set company_id = ${other.id} where id = ${seller.id}`);
        record(6, 'seller cannot change own users.company_id', r6.code === '42501', r6.code ?? 'succeeded');

        // 7
        await asOwner(s);
        await as(s, 'authenticated', buyer.id);
        const r7 = await codeOf(s, (x) => x`insert into public.availabilities ${x(lot(other.id))}`);
        record(7, 'buyer insert rejected', r7.code === '42501', r7.code ?? 'succeeded');

        // 8
        await asOwner(s);
        await as(s, 'authenticated', broker.id);
        const r8 = await codeOf(s, (x) => x`insert into public.availabilities ${x(lot(other.id, { broker_id: broker.id }))}`);
        record(8, 'broker insert with broker_id = self still allowed', r8.code === null, r8.code ?? '');

        // 9
        await asOwner(s);
        await as(s, 'anon', null);
        const r9a = await codeOf(s, (x) => x`insert into public.availabilities ${x(lot(other.id))}`);
        const r9b = await codeOf(s, (x) => x`select 1 from public.availabilities limit 1`);
        record(9, 'anon insert/select denied', r9a.code === '42501' && r9b.code === '42501', `${r9a.code}/${r9b.code}`);

        await asOwner(s);
        throw ROLLBACK; // discard every synthetic row and impersonation
      });
    } catch (e) {
      if (e !== ROLLBACK) throw e;
    }

    // 10
    const pols = await t`
      select policyname, cmd from pg_policies
      where schemaname = 'public' and tablename = 'availabilities' order by policyname`;
    const trig = await t`select 1 from pg_trigger where tgname = 'trg_prevent_self_company_change'`;
    record(10, 'exactly 3 availabilities policies + users guard trigger present',
      pols.length === 3 && pols.every((p) => ['INSERT', 'SELECT', 'UPDATE'].includes(p.cmd)) && trig.length === 1);

    const leftover = await t`select count(*)::int as n from public.availabilities where lot_number = 'RLS-0044-SYNTHETIC'`;
    if (leftover[0].n !== 0) throw new Error('synthetic rows leaked');

    if (DRY_RUN) throw new Error('DRY_RUN: rolling back');
    if (!results.every(Boolean) || results.length !== 10) throw new Error(`validation failed (${results.filter(Boolean).length}/10)`);
  });
  committed = true;
} catch (e) {
  console.log('ROLLED BACK:', e.message);
} finally {
  await sql.end();
}
console.log(committed ? 'COMMITTED: migration 0044 applied.' : 'NOT COMMITTED: database unchanged.');
process.exit(committed ? 0 : 1);
