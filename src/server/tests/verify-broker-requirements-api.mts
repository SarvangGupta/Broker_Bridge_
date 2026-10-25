/**
 * RB-REQUIREMENTS-API-01 focused verification. Read-only: every query runs in
 * a `begin read only` transaction on a reserved connection, so no live data
 * can change. Run: npx tsx src/server/tests/verify-broker-requirements-api.mts
 */
import 'dotenv/config';
import postgres from 'postgres';
import { drizzle } from 'drizzle-orm/postgres-js';
import { queryBrokerRequirements } from '../utils/broker-requirements-query';
import { decodeDirectoryCursor } from '../utils/broker-directory-query';

const VARUN = 'b354958e-779a-41f2-b7a3-5899eca32e32';
let failures = 0;
function check(name: string, ok: boolean, detail = '') {
  console.log(`${ok ? 'PASS' : 'FAIL'}  ${name}${detail ? `  (${detail})` : ''}`);
  if (!ok) failures++;
}

const conn = postgres(process.env.DATABASE_URL!, { prepare: false, max: 1 });
const reserved = await conn.reserve();
(reserved as any).options = (conn as any).options;
const db = drizzle(reserved as any);

try {
  await reserved`begin read only`;

  const truth = await reserved`select id from requirements where broker_id = ${VARUN}::uuid`;
  const all = await queryBrokerRequirements(db as any, VARUN);
  check('authorized broker gets all assigned requirements', all.requirements.length === truth.length,
    `${all.requirements.length}/${truth.length}`);
  check('every row is assigned to the broker', all.requirements.every((r) => r.broker_id === VARUN));
  check('full list has no pageInfo continuation', !all.hasMore && all.nextCursor === null);

  const r0 = all.requirements[0] as Record<string, any> | undefined;
  check('row has fields RequirementItem.fromJson reads',
    !!r0 && ['id', 'company_id', 'commodity_id', 'grade_id', 'unit_id', 'quantity', 'fulfilled_quantity',
      'target_price', 'target_date', 'status', 'created_at', 'commodity_name', 'unit_symbol']
      .every((k) => k in r0) && typeof r0.quantity === 'number' && !Number.isNaN(Date.parse(r0.target_date)));

  const other = await reserved`
    select u.id from users u where lower(u.role) = 'broker' and u.id <> ${VARUN}::uuid limit 1`;
  if (other.length) {
    const theirs = await queryBrokerRequirements(db as any, other[0].id);
    const varunIds = new Set(truth.map((t) => t.id));
    check('another broker never receives this broker\'s requirements',
      theirs.requirements.every((r) => !varunIds.has(r.id as string) && r.broker_id === other[0].id));
  }

  // Buyer company-name visibility (approved rule): every assigned buyer's
  // company name is returned, including buyers not in the broker's Directory.
  const notInDirectory = await reserved`
    select distinct r.company_id from requirements r
    where r.broker_id = ${VARUN}::uuid and not exists (
      select 1 from crm_contacts cc where cc.broker_id = ${VARUN}::uuid and cc.company_id = r.company_id)`;
  const named = new Map(all.requirements.map((r) => [r.company_id as string, r.buyer_company_name]));
  check('assigned buyers absent from the Directory still have a company name',
    notInDirectory.length > 0 && notInDirectory.every((c) => typeof named.get(c.company_id) === 'string'),
    `${notInDirectory.length} such buyer companies`);
  const truthNames = await reserved`
    select r.id, c.name from requirements r join companies c on c.id = r.company_id
    where r.broker_id = ${VARUN}::uuid`;
  const byId = new Map(all.requirements.map((r) => [r.id as string, r.buyer_company_name]));
  check('company name matches the requirement\'s own buyer company',
    truthNames.every((t) => byId.get(t.id) === t.name));
  const foreignOnly = await reserved`
    select distinct r.company_id from requirements r
    where r.broker_id is not null and r.broker_id <> ${VARUN}::uuid
      and r.company_id not in (select company_id from requirements where broker_id = ${VARUN}::uuid)`;
  check('buyers assigned only to other brokers never appear',
    all.requirements.every((r) => !foreignOnly.some((f) => f.company_id === r.company_id)),
    `${foreignOnly.length} foreign-only buyer companies`);
  const unassigned = await reserved`
    select distinct company_id from requirements where broker_id is null
      and company_id not in (select company_id from requirements where broker_id = ${VARUN}::uuid)`;
  check('buyers with no assignment to this broker are not introduced',
    all.requirements.every((r) => !unassigned.some((u) => u.company_id === r.company_id)),
    `${unassigned.length} unassigned-only buyer companies`);

  const none = await queryBrokerRequirements(db as any, '00000000-0000-0000-0000-000000000000', { limit: 5 });
  check('empty result is an empty page', none.requirements.length === 0 && !none.hasMore && none.nextCursor === null);

  const seen: string[] = [];
  let cursor = null;
  for (let i = 0; i < 100; i++) {
    const page = await queryBrokerRequirements(db as any, VARUN, { limit: 4, after: cursor });
    seen.push(...page.requirements.map((r) => r.id as string));
    if (!page.hasMore) break;
    cursor = decodeDirectoryCursor(page.nextCursor);
    if (!cursor) { check('cursor round-trips', false, String(page.nextCursor)); break; }
  }
  check('keyset pages cover the list exactly once', seen.length === truth.length && new Set(seen).size === seen.length,
    `${seen.length} rows`);
  check('page order equals full-list order', seen.join() === all.requirements.map((r) => r.id).join());
  check('malformed cursors are rejected by the decoder',
    ['garbage', '2026-10-19 22:08:46|not-a-uuid', `x|${VARUN}`, "2026-10-19'; drop|" + VARUN]
      .every((c) => decodeDirectoryCursor(c) === null));

  await reserved`rollback`;
} finally {
  reserved.release();
  await conn.end();
}

// Route: no bearer token -> 401 before any database access.
const { GET } = await import('../../../app/api/v1/broker/requirements/route');
const { NextRequest } = await import('next/server');
const unauth = await GET(new NextRequest('http://localhost/api/v1/broker/requirements'));
check('unauthenticated request rejected with 401', unauth.status === 401, String(unauth.status));
const bad = await GET(new NextRequest('http://localhost/api/v1/broker/requirements',
  { headers: { authorization: 'Bearer not-a-real-token' } }));
check('invalid token rejected with 401', bad.status === 401, String(bad.status));

// The route module opened the app's pool; close it so the process exits cleanly.
const appDb = (await import('../db')).db as any;
await appDb.$client?.end?.({ timeout: 5 });

console.log(failures ? `\n${failures} check(s) failed` : '\nAll checks passed');
process.exit(failures ? 1 : 0);
