// Runs the real buyer discovery and link SQL on a throwaway in-memory PGlite.
// Never connects to a real database. PGlite is not a project dependency:
//   PGLITE_PATH=<...>/@electric-sql/pglite/dist/index.js npx tsx src/server/tests/verify-buyer-discovery-offline.ts
import assert from 'node:assert/strict';
import { pathToFileURL } from 'node:url';
import { PgDialect } from 'drizzle-orm/pg-core';
import {
  categoryPreferencesAvailable,
  linkExistingBuyer,
  queryBuyerCategories,
  queryDiscoverableBuyers,
} from '../utils/broker-directory-query';

const id = (n: number) => `00000000-0000-4000-8000-${String(n).padStart(12, '0')}`;
const BROKER_A = id(1), BROKER_B = id(2), ADMIN = id(3);
const GRAINS = id(50), OILSEEDS = id(51);
const AUTH_BUYER = id(10), ADMIN_BUYER = id(11), BACKEND_BUYER = id(12), PRIVATE_BUYER = id(13);
const SELLER = id(14), INACTIVE = id(15), GRAINS_BUYER = id(16), MULTI_BUYER = id(17);

const dialect = new PgDialect();
function adapter(pg: any): any {
  return {
    execute: async (q: any) => {
      const { sql, params } = dialect.sqlToQuery(q);
      return (await pg.query(sql, params)).rows;
    },
    transaction: (fn: any) => pg.transaction((t: any) => fn(adapter(t))),
  };
}

async function main() {
  const path = process.env.PGLITE_PATH;
  if (!path) throw new Error('Set PGLITE_PATH to the PGlite dist/index.js');
  const { PGlite } = await import(pathToFileURL(path).href);
  const pg = new PGlite();
  const db = adapter(pg);

  await pg.exec(`
    create schema auth;
    create table auth.users (id uuid primary key);
    create table companies (id uuid primary key, name text not null, district_id text, state_id text,
      status boolean not null default true, gst text, trade_name text, legal_name text, gst_verification_status text);
    create table users (id uuid primary key, name text not null, mobile text, email text, role text,
      status boolean not null default true, company_id uuid references companies(id), created_by uuid, created_at timestamp default now());
    create table crm_contacts (id uuid primary key default gen_random_uuid(), broker_id uuid not null, user_id uuid, company_id uuid,
      last_activity_at timestamp, removed_at timestamptz, created_at timestamp default now());
    create table master_districts (id uuid primary key, name text);
  `);
  const company = (uid: string, name: string, extra = "null, null") =>
    `insert into companies (id, name, gst, gst_verification_status) values ('${uid}', '${name}', ${extra});`;
  const user = (uid: string, name: string, role: string, createdBy = 'null', status = 'true', mobile = 'null') =>
    `insert into users (id, name, role, company_id, created_by, status, mobile, email) values
     ('${uid}', '${name}', '${role}', '${uid}', ${createdBy}, ${status}, ${mobile}, '${uid}@x.test');`;
  await pg.exec([
    company(ADMIN, 'Platform'), `insert into users (id, name, role) values ('${ADMIN}', 'Admin', 'admin');`,
    company(AUTH_BUYER, 'Nilesh Auth Traders', "'08ADRPK6597J1ZL', 'gst_pending'"),
    user(AUTH_BUYER, 'Nilesh One', 'buyer', 'null', 'true', "'+919876500001'"),
    `insert into auth.users values ('${AUTH_BUYER}');`,
    company(ADMIN_BUYER, 'Nilesh Admin Foods'), user(ADMIN_BUYER, 'Nilesh Two', 'Buyer', `'${ADMIN}'`),
    company(BACKEND_BUYER, 'Nilesh Backend Mills'), user(BACKEND_BUYER, 'Nilesh Three', 'buyer'),
    company(PRIVATE_BUYER, 'Nilesh Private Co'), user(PRIVATE_BUYER, 'Nilesh Four', 'buyer', `'${BROKER_B}'`),
    `insert into crm_contacts (broker_id, user_id, company_id) values ('${BROKER_B}', '${PRIVATE_BUYER}', '${PRIVATE_BUYER}');`,
    company(SELLER, 'Nilesh Seller Co'), user(SELLER, 'Nilesh Five', 'seller'),
    company(INACTIVE, 'Nilesh Inactive Co'), user(INACTIVE, 'Nilesh Six', 'buyer', 'null', 'false'),
  ].join('\n'));

  const ids = async (broker: string, search: string, categoryId?: string) =>
    (await queryDiscoverableBuyers(db, broker, { search, categoryId })).map((r) => r.userId).sort();

  // Before 0064: every buyer is All Categories and a filter hides nobody.
  assert.equal(await categoryPreferencesAvailable(db), false);
  assert.equal((await queryBuyerCategories(db, [AUTH_BUYER])).size, 0);

  // Eligibility: unlinked, admin and backend buyers found; private, seller, inactive not.
  const eligible = [AUTH_BUYER, ADMIN_BUYER, BACKEND_BUYER].sort();
  assert.deepEqual(await ids(BROKER_A, 'niles'), eligible);
  // The broker who owns the private contact still sees it, as Already Added.
  const own = await queryDiscoverableBuyers(db, BROKER_B, { search: 'Private' });
  assert.equal(own.length, 1);
  assert.ok(own[0].contactId);

  // Identifiers: exact only for mobile, email, GSTIN; no contact data returned.
  assert.deepEqual(await ids(BROKER_A, '9876500001'), [AUTH_BUYER]);
  assert.deepEqual(await ids(BROKER_A, '98765'), []);
  assert.deepEqual(await ids(BROKER_A, `${AUTH_BUYER}@X.test`), [AUTH_BUYER]);
  assert.deepEqual(await ids(BROKER_A, '08adrpk6597j1zl'), [AUTH_BUYER]);
  const row = (await queryDiscoverableBuyers(db, BROKER_A, { search: 'niles' }))[0];
  for (const key of ['mobile', 'email', 'bankAccountNumber']) assert.ok(!(key in row), key);

  // Linking: only crm_contacts changes, repeats and races are idempotent.
  const counts = async () =>
    (await pg.query(`select (select count(*) from users)::int u, (select count(*) from companies)::int c`)).rows[0];
  const before = await counts();
  const first = await linkExistingBuyer(db, BROKER_A, BACKEND_BUYER);
  assert.equal(first.outcome, 'created');
  const racing = await Promise.all([1, 2, 3].map(() => linkExistingBuyer(db, BROKER_A, BACKEND_BUYER)));
  assert.ok(racing.every((r) => r.outcome === 'already'));
  const links = async (buyer: string, broker = BROKER_A) =>
    (await pg.query(`select count(*)::int n from crm_contacts where user_id = $1 and broker_id = $2`, [buyer, broker])).rows[0].n;
  assert.equal(await links(BACKEND_BUYER), 1);
  assert.deepEqual(await counts(), before);
  const linked = (await queryDiscoverableBuyers(db, BROKER_A, { search: 'Backend' }))[0];
  assert.ok(linked.contactId, 'Already Added');

  // A second broker links the same identity independently through an auth buyer.
  assert.equal((await linkExistingBuyer(db, BROKER_A, AUTH_BUYER)).outcome, 'created');
  assert.equal((await linkExistingBuyer(db, BROKER_B, AUTH_BUYER)).outcome, 'created');
  assert.equal(await links(AUTH_BUYER, BROKER_B), 1);
  assert.deepEqual(await counts(), before);

  // A removed link is reactivated, never duplicated.
  await pg.exec(`update crm_contacts set removed_at = now() where user_id = '${AUTH_BUYER}' and broker_id = '${BROKER_A}'`);
  assert.equal((await linkExistingBuyer(db, BROKER_A, AUTH_BUYER)).outcome, 'reactivated');
  assert.equal(await links(AUTH_BUYER), 1);

  // Ineligible buyers cannot be linked by id either.
  for (const blocked of [PRIVATE_BUYER, SELLER, INACTIVE, id(99)]) {
    assert.equal((await linkExistingBuyer(db, BROKER_A, blocked)).outcome, 'not_eligible');
  }

  // GST status is untouched by linking.
  const gst = (await pg.query(`select gst_verification_status s from companies where id = $1`, [AUTH_BUYER])).rows[0].s;
  assert.equal(gst, 'gst_pending');

  // After 0064: None = every filter; explicit = only those categories.
  await pg.exec(`
    create table master_categories (id uuid primary key, name text);
    insert into master_categories values ('${GRAINS}', 'Grains'), ('${OILSEEDS}', 'Oilseeds');
    create table buyer_category_preferences (buyer_id uuid, category_id uuid);
    ${company(GRAINS_BUYER, 'Nilesh Grains Co')} ${user(GRAINS_BUYER, 'Nilesh Seven', 'buyer')}
    ${company(MULTI_BUYER, 'Nilesh Multi Co')} ${user(MULTI_BUYER, 'Nilesh Eight', 'buyer')}
    insert into buyer_category_preferences values ('${GRAINS_BUYER}', '${GRAINS}'),
      ('${MULTI_BUYER}', '${GRAINS}'), ('${MULTI_BUYER}', '${OILSEEDS}');
  `);
  assert.equal(await categoryPreferencesAvailable(db), true);
  const underGrains = await ids(BROKER_A, 'niles', GRAINS);
  const underOilseeds = await ids(BROKER_A, 'niles', OILSEEDS);
  for (const b of eligible) {
    assert.ok(underGrains.includes(b) && underOilseeds.includes(b), 'no categories: every filter');
  }
  assert.ok(underGrains.includes(GRAINS_BUYER) && !underOilseeds.includes(GRAINS_BUYER));
  assert.ok(underGrains.includes(MULTI_BUYER) && underOilseeds.includes(MULTI_BUYER));
  assert.equal((await queryBuyerCategories(db, [MULTI_BUYER])).get(MULTI_BUYER)?.length, 2);

  console.log('verify-buyer-discovery-offline: all checks passed');
  await pg.close();
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
