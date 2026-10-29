// Applies 0052 + rollback_0052 to an in-memory PGlite database seeded with the live
// master_states / master_districts snapshot. Never connects to any remote database.
// Usage: node migration_test.mjs <live_states.json> <live_districts.json> <0052.sql> <rollback.sql>
import fs from 'node:fs';
import { PGlite } from '@electric-sql/pglite';

const [statesPath, districtsPath, migPath, rbPath] = process.argv.slice(2);
const readJson = (p) => JSON.parse(fs.readFileSync(p, 'utf8').replace(/^﻿/, ''));
const liveStates = readJson(statesPath);
const liveDistricts = readJson(districtsPath);
const migration = fs.readFileSync(migPath, 'utf8');
const rollback = fs.readFileSync(rbPath, 'utf8');

const db = new PGlite();
const results = [];
const check = (name, ok, detail = '') => { results.push({ name, ok, detail }); console.log(`${ok ? 'PASS' : 'FAIL'}  ${name}${detail ? '  — ' + detail : ''}`); };
const q = async (sql, params) => (await db.query(sql, params)).rows;
const lit = (s) => `'${String(s).replace(/'/g, "''")}'`;

// Schema as in migrations 0002 / 0004 (FK from availabilities to districts).
await db.exec(`
  CREATE TABLE master_states (id uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL, name text NOT NULL, code text);
  CREATE TABLE master_districts (id uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL, name text NOT NULL,
    state_id uuid REFERENCES master_states(id));
  CREATE TABLE availabilities (id uuid PRIMARY KEY DEFAULT gen_random_uuid(), district_id uuid REFERENCES master_districts(id));
`);
await db.exec(`INSERT INTO master_states (id, name, code) VALUES ${liveStates.map((s) => `(${lit(s.id)}, ${lit(s.name)}, ${lit(s.code)})`).join(',')};`);
await db.exec(`INSERT INTO master_districts (id, name, state_id) VALUES ${liveDistricts.map((d) => `(${lit(d.id)}, ${lit(d.name)}, ${lit(d.state_id)})`).join(',')};`);

const snapshot = async () => (await q(`SELECT id::text, name, state_id::text FROM master_districts ORDER BY id`)).map((r) => `${r.id}|${r.name}|${r.state_id}`).join('\n');
const before = await snapshot();
const baseCount = liveDistricts.length;

// 1. First apply
await db.exec(migration);
const afterFirst = Number((await q(`SELECT count(*)::int AS c FROM master_districts`))[0].c);
const inserted = afterFirst - baseCount;
check('first apply inserts the new districts', inserted === 703, `${baseCount} -> ${afterFirst} (+${inserted})`);

// existing rows untouched
const existingNow = (await q(`SELECT id::text, name, state_id::text FROM master_districts WHERE id = ANY($1::uuid[]) ORDER BY id`, [liveDistricts.map((d) => d.id)]))
  .map((r) => `${r.id}|${r.name}|${r.state_id}`).join('\n');
check('existing live districts unchanged', existingNow === before);

// 2. Idempotent second apply
await db.exec(migration);
const afterSecond = Number((await q(`SELECT count(*)::int AS c FROM master_districts`))[0].c);
check('second apply is a no-op (idempotent)', afterSecond === afterFirst, `${afterSecond}`);

// 3. Every state/UT has districts; every new district under a non-demo state row
const perState = await q(`SELECT s.code, count(d.id)::int AS n FROM master_states s LEFT JOIN master_districts d ON d.state_id = s.id
  WHERE s.id::text NOT LIKE '10000000-0000-0000-0000-%' GROUP BY s.code ORDER BY s.code`);
const empty = perState.filter((r) => r.n === 0).map((r) => r.code);
check('all 36 states/UTs have at least one district', perState.length === 36 && empty.length === 0, empty.length ? `empty: ${empty}` : `${perState.length} states`);
const onDemo = Number((await q(`SELECT count(*)::int AS c FROM master_districts d WHERE d.state_id::text LIKE '10000000-0000-0000-0000-%'
  AND d.id <> ALL($1::uuid[])`, [liveDistricts.map((d) => d.id)]))[0].c);
check('no new district attached to a demo state row', onDemo === 0);

// 4. No duplicate (state code, normalised name)
const dups = await q(`SELECT s.code, regexp_replace(lower(d.name),'[^a-z]','','g') AS k, count(*)::int AS n
  FROM master_districts d JOIN master_states s ON s.id = d.state_id
  WHERE s.id::text NOT LIKE '10000000-0000-0000-0000-%' GROUP BY 1,2 HAVING count(*) > 1`);
check('no duplicate district per state (non-demo rows)', dups.length === 0, dups.map((d) => `${d.code}:${d.k}`).join(', '));

// 5. Spot checks
const spot = async (code, name) => Number((await q(`SELECT count(*)::int AS c FROM master_districts d JOIN master_states s ON s.id=d.state_id
  WHERE s.code=$1 AND d.name=$2`, [code, name]))[0].c);
check('UP Kaushambi present', (await spot('UP', 'Kaushambi')) === 1);
check('MP Indore present', (await spot('MP', 'Indore')) === 1);
check('RJ Jaipur not duplicated', (await spot('RJ', 'Jaipur')) === 2, 'live already has Jaipur under seed + demo rows');
check('RJ Ganganagar not inserted (alias of Sri Ganganagar)', (await spot('RJ', 'Ganganagar')) === 0);

// 6. Rollback refuses when a new district is referenced
const kaushambi = (await q(`SELECT d.id::text FROM master_districts d JOIN master_states s ON s.id=d.state_id WHERE s.code='UP' AND d.name='Kaushambi'`))[0].id;
await db.query(`INSERT INTO availabilities (district_id) VALUES ($1)`, [kaushambi]);
let refused = false;
try { await db.exec(rollback); } catch { refused = true; await db.exec('ROLLBACK').catch(() => {}); }
const afterRefused = Number((await q(`SELECT count(*)::int AS c FROM master_districts`))[0].c);
check('rollback refuses (FK) while a new district is referenced, nothing deleted', refused && afterRefused === afterFirst);
await db.query(`DELETE FROM availabilities`);

// 7. Rollback removes exactly the migration rows
await db.exec(rollback);
const after = await snapshot();
check('rollback restores the exact original district set', after === before, `${(await q('SELECT count(*)::int c FROM master_districts'))[0].c} rows`);

// 8. Rollback twice is harmless
await db.exec(rollback);
check('second rollback is a no-op', (await snapshot()) === before);

const failed = results.filter((r) => !r.ok).length;
console.log(`\n${results.length - failed} passed, ${failed} failed`);
process.exit(failed ? 1 : 0);
