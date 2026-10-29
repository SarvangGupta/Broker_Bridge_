// Local staging-equivalent: replays the repo's applied migration history into an in-memory
// PGlite database (no network, no production connection), then validates proposed 0052.
// Usage: node staging_replay.mjs <repoRoot> <dartDataFile>
import fs from 'node:fs';
import path from 'node:path';
import { PGlite } from '@electric-sql/pglite';

const [repoRoot, dartData] = process.argv.slice(2);
const mig = (f) => path.join(repoRoot, 'supabase', 'migrations', f);
const db = new PGlite();
const results = [];
const check = (name, ok, detail = '') => {
  results.push({ name, ok });
  console.log(`${ok ? 'PASS' : 'FAIL'}  ${name}${detail ? '  — ' + detail : ''}`);
};
const rows = async (sql, p) => (await db.query(sql, p)).rows;
const one = async (sql, p) => Object.values((await rows(sql, p))[0])[0];

// --- Supabase platform stubs (only what the migrations reference) ---
await db.exec(`
  CREATE ROLE anon NOLOGIN; CREATE ROLE authenticated NOLOGIN; CREATE ROLE service_role NOLOGIN BYPASSRLS;
  CREATE SCHEMA auth;
  CREATE TABLE auth.users (id uuid PRIMARY KEY, email text, raw_user_meta_data jsonb DEFAULT '{}'::jsonb,
    raw_app_meta_data jsonb DEFAULT '{}'::jsonb, created_at timestamptz DEFAULT now());
  CREATE FUNCTION auth.uid() RETURNS uuid LANGUAGE sql STABLE AS
    $$ SELECT nullif(current_setting('request.jwt.claim.sub', true), '')::uuid $$;
  CREATE FUNCTION auth.role() RETURNS text LANGUAGE sql STABLE AS
    $$ SELECT current_setting('request.jwt.claim.role', true) $$;
  CREATE FUNCTION auth.jwt() RETURNS jsonb LANGUAGE sql STABLE AS
    $$ SELECT coalesce(nullif(current_setting('request.jwt.claims', true), ''), '{}')::jsonb $$;
  CREATE SCHEMA storage;
  CREATE TABLE storage.buckets (id text PRIMARY KEY, name text, public boolean DEFAULT false);
  CREATE TABLE storage.objects (id uuid PRIMARY KEY DEFAULT gen_random_uuid(), bucket_id text, name text, owner uuid);
  CREATE FUNCTION storage.foldername(name text) RETURNS text[] LANGUAGE sql IMMUTABLE AS $$ SELECT string_to_array(name, '/') $$;
  CREATE PUBLICATION supabase_realtime;
`);

// --- Replay applied history in order ---
const files = fs.readdirSync(path.join(repoRoot, 'supabase', 'migrations'))
  .filter((f) => /^\d{4}_.*\.sql$/.test(f)).sort();
const ordered = [...files.filter((f) => f <= '0002~'), 'seed_states_rajasthan_districts.sql', ...files.filter((f) => f > '0002~')];
// Split SQL into statements, respecting $tag$ … $tag$ bodies, quotes and comments.
function splitSql(sql) {
  const out = []; let cur = ''; let i = 0; let dollar = null; let quote = false;
  while (i < sql.length) {
    const c = sql[i];
    if (!dollar && !quote && c === '-' && sql[i + 1] === '-') { const e = sql.indexOf('\n', i); i = e < 0 ? sql.length : e; continue; }
    if (!quote && c === '$') {
      const m = sql.slice(i).match(/^\$[A-Za-z_]*\$/);
      if (m) { if (!dollar) dollar = m[0]; else if (m[0] === dollar) dollar = null; cur += m[0]; i += m[0].length; continue; }
    }
    if (!dollar && c === "'") quote = !quote;
    if (!dollar && !quote && c === ';') { if (cur.trim()) out.push(cur.trim()); cur = ''; i++; continue; }
    cur += c; i++;
  }
  if (cur.trim()) out.push(cur.trim());
  return out.filter((s) => !/^(BEGIN|COMMIT)$/i.test(s));
}

const replay = [];
const drift = [];
// Drift patch: production has these columns but no repo migration creates them (found by a
// clean replay — 0038/0039/0044 policies reference them). Applied before 0038 and reported.
const DRIFT_PATCH = `ALTER TABLE public.requirements ADD COLUMN IF NOT EXISTS broker_id uuid;
  ALTER TABLE public.availabilities ADD COLUMN IF NOT EXISTS broker_id uuid;`;
const usePatch = process.env.NO_DRIFT_PATCH !== '1';
for (const f of [...ordered, 'manual_rls_companies.sql', 'manual_storage_rls.sql', 'manual_lab_storage_rls.sql']) {
  if (usePatch && f.startsWith('0038')) { await db.exec(DRIFT_PATCH); console.log('replay DRIFT PATCH (requirements/availabilities.broker_id) applied'); }
  const sql = fs.readFileSync(mig(f), 'utf8').replace(/--> statement-breakpoint/g, '');
  try { await db.exec(sql); replay.push([f, 'ok']); continue; }
  catch { await db.exec('ROLLBACK').catch(() => {}); }
  // Statement-by-statement fallback; each failing statement is recorded as schema drift.
  let failedStmts = 0;
  for (const stmt of splitSql(sql)) {
    try { await db.exec(stmt); }
    catch (e) {
      await db.exec('ROLLBACK').catch(() => {});
      failedStmts++;
      drift.push(`${f}: ${e.message.split('\n')[0]} :: ${stmt.replace(/\s+/g, ' ').slice(0, 110)}`);
    }
  }
  replay.push([f, `partial (${failedStmts} statement(s) failed)`]);
}
for (const [f, s] of replay) console.log(`replay ${f.padEnd(55)} ${s}`);
console.log(`\nSchema drift (repo migrations that do not apply to a clean replay): ${drift.length}`);
for (const d of drift) console.log('  DRIFT ' + d);
const replayFailures = replay.filter(([, s]) => s !== 'ok');
console.log(replayFailures.length ? `\nNOTE: ${replayFailures.length} file(s) replayed partially — see DRIFT lines.` : '');
const masterOk = (await one(`SELECT count(*)::int FROM pg_policies WHERE tablename IN ('master_states','master_districts')`)) >= 2;
check('master_states/master_districts RLS from 0038 present in staging', masterOk);

// Synthetic demo seed reproduces the live duplicate RJ/MP state rows (no personal data used).
try {
  await db.exec(fs.readFileSync(path.join(repoRoot, 'supabase', 'seed_broker_demo_dataset.sql'), 'utf8'));
  console.log('replay seed_broker_demo_dataset.sql ok');
} catch (e) {
  // Only the master-data part is needed; apply it directly if the full demo seed needs auth rows.
  console.log('demo seed (full) skipped: ' + e.message.split('\n')[0]);
  await db.exec('ROLLBACK').catch(() => {});
  await db.exec(`
    INSERT INTO public.master_states (id, name, code) VALUES
      ('10000000-0000-0000-0000-000000000001','Rajasthan','RJ'),('10000000-0000-0000-0000-000000000002','Madhya Pradesh','MP')
    ON CONFLICT (id) DO NOTHING;
    INSERT INTO public.master_districts (id, name, state_id) VALUES
      ('11000000-0000-0000-0000-000000000001','Kota','10000000-0000-0000-0000-000000000001'),
      ('11000000-0000-0000-0000-000000000002','Jaipur','10000000-0000-0000-0000-000000000001'),
      ('11000000-0000-0000-0000-000000000003','Baran','10000000-0000-0000-0000-000000000001'),
      ('11000000-0000-0000-0000-000000000004','Ujjain','10000000-0000-0000-0000-000000000002')
    ON CONFLICT (id) DO NOTHING;`);
  console.log('demo master rows applied');
}

const baseStates = await one(`SELECT count(*)::int FROM master_states`);
const baseDistricts = await one(`SELECT count(*)::int FROM master_districts`);
check('staging baseline mirrors live shape (38 states / 54 districts)', baseStates === 38 && baseDistricts === 54,
  `${baseStates} states, ${baseDistricts} districts`);
const snapshot = async () => (await rows(`SELECT id::text||'|'||name||'|'||state_id::text AS r FROM master_districts ORDER BY id`)).map((r) => r.r).join('\n');
const before = await snapshot();

// --- Apply 0052 (proposed) twice ---
const m0052 = fs.readFileSync(path.join(repoRoot, 'supabase', 'proposed', '0052_seed_national_districts.sql'), 'utf8');
const r0052 = fs.readFileSync(path.join(repoRoot, 'supabase', 'proposed', 'rollback_0052.sql'), 'utf8');
await db.exec(m0052);
const after1 = await one(`SELECT count(*)::int FROM master_districts`);
check('0052 inserts exactly 703 districts', after1 - baseDistricts === 703, `${baseDistricts} -> ${after1}`);
const preserved = (await rows(`SELECT id::text||'|'||name||'|'||state_id::text AS r FROM master_districts WHERE id::text IN (${before.split('\n').map((l) => `'${l.split('|')[0]}'`).join(',')}) ORDER BY id`)).map((r) => r.r).join('\n');
check('pre-existing districts unchanged', preserved === before);
await db.exec(m0052);
check('re-running 0052 is a no-op', (await one(`SELECT count(*)::int FROM master_districts`)) === after1);

// --- Duplicates / aliases ---
const dup = await rows(`SELECT s.code, regexp_replace(lower(d.name),'[^a-z]','','g') k FROM master_districts d
  JOIN master_states s ON s.id=d.state_id WHERE s.id::text NOT LIKE '10000000-0000-0000-0000-%' GROUP BY 1,2 HAVING count(*)>1`);
check('no duplicate district within a state', dup.length === 0, dup.map((d) => d.code + ':' + d.k).join(','));
check('alias respected: no "Ganganagar" next to "Sri Ganganagar"',
  (await one(`SELECT count(*)::int FROM master_districts WHERE name='Ganganagar'`)) === 0);

// --- Every district the app can resolve from a PIN exists in the staging master ---
const dart = fs.readFileSync(dartData, 'utf8');
const list = (name) => [...dart.match(new RegExp(`const List<String> ${name} = \\[([\\s\\S]*?)\\];`))[1].matchAll(/'((?:[^'\\]|\\.)*)'/g)].map((m) => m[1].replace(/\\'/g, "'"));
const pinStates = list('kPinStates');
const pinDistricts = list('kPinDistricts').map((e) => { const [n, i] = e.split('|'); return { name: n, state: pinStates[+i] }; });
const codeOf = {};
for (const s of await rows(`SELECT name, code FROM master_states`)) codeOf[s.name.toLowerCase()] = s.code;
const norm = (s) => s.toLowerCase().replace(/^the\s+/, '').replace(/&/g, 'and');
const aliases = { ganganagar: 'sriganganagar' };
const key = (n) => { const k = n.toLowerCase().replace(/[^a-z]/g, ''); return aliases[k] ?? k; };
const dbKeys = new Set((await rows(`SELECT s.code, d.name FROM master_districts d JOIN master_states s ON s.id=d.state_id`)).map((r) => `${r.code}|${key(r.name)}`));
const missing = pinDistricts.filter((d) => !dbKeys.has(`${codeOf[norm(d.state)]}|${key(d.name)}`));
check(`all ${pinDistricts.length} app PIN districts resolvable in staging master`, missing.length === 0,
  missing.slice(0, 5).map((d) => `${d.state}/${d.name}`).join('; '));

// --- Representative PIN districts per state/UT (same set as national_pin_coverage_test.dart) ---
const reps = [['AN','South Andamans'],['AP','Krishna'],['AR','Papum Pare'],['AS','Kamrup Metro'],['BR','Patna'],['CH','Chandigarh'],
  ['CT','Raipur'],['DN','Daman'],['DL','North'],['GA','North Goa'],['GJ','Ahmadabad'],['HR','Gurugram'],['HP','Shimla'],
  ['JK','Srinagar'],['JH','Ranchi'],['KA','Bengaluru Urban'],['KL','Thiruvananthapuram'],['LA','Leh Ladakh'],
  ['LD','Lakshadweep District'],['MP','Bhopal'],['MH','Mumbai'],['MN','Imphal East'],['ML','East Khasi Hills'],['MZ','Aizawl'],
  ['NL','Kohima'],['OR','Khordha'],['PY','Pondicherry'],['PB','Ludhiana'],['RJ','Jaipur'],['SK','East District'],['TN','Chennai'],
  ['TG','Hyderabad'],['TR','West Tripura'],['UP','Kaushambi'],['UT','Dehradun'],['WB','Kolkata']];
const repMissing = reps.filter(([c, n]) => !dbKeys.has(`${c}|${key(n)}`));
check('representative district present for all 36 states/UTs', repMissing.length === 0, repMissing.map((r) => r.join('/')).join(', '));

// --- RLS: an authenticated seller can read the new districts (policy from 0038) ---
await db.exec(`SET ROLE authenticated; SET request.jwt.claim.sub = '00000000-0000-0000-0000-0000000000aa';`);
const visible = await one(`SELECT count(*)::int FROM master_districts`);
await db.exec(`RESET ROLE;`);
check('authenticated role can read all districts under RLS', visible === after1, `${visible}`);

// --- FK-guarded rollback ---
const ksb = await one(`SELECT d.id::text FROM master_districts d JOIN master_states s ON s.id=d.state_id WHERE s.code='UP' AND d.name='Kaushambi'`);
const cols = await rows(`SELECT column_name FROM information_schema.columns WHERE table_name='availabilities' AND is_nullable='NO' AND column_default IS NULL`);
let refused = false;
try {
  await db.exec(`CREATE TEMP TABLE _ref (d uuid REFERENCES master_districts(id)); INSERT INTO _ref VALUES ('${ksb}');`);
  await db.exec(r0052);
} catch { refused = true; await db.exec('ROLLBACK').catch(() => {}); }
check('rollback refuses while a new district is referenced', refused && (await one(`SELECT count(*)::int FROM master_districts`)) === after1,
  `required availabilities cols: ${cols.length}`);
await db.exec(`DROP TABLE IF EXISTS _ref;`);
await db.exec(r0052);
check('rollback restores the exact pre-0052 master', (await snapshot()) === before);
await db.exec(r0052);
check('rollback is idempotent', (await snapshot()) === before);

const failed = results.filter((r) => !r.ok).length;
console.log(`\n${results.length - failed} passed, ${failed} failed`);
process.exit(failed ? 1 : 0);
