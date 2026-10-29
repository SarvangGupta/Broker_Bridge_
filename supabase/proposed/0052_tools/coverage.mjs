// RB-SELLER-ADDRESS-PIN-COVERAGE-01: coverage audit + migration generator.
// Usage: node coverage.mjs <pincode.csv> <live_states.json> <live_districts.json> <outDir>
import fs from 'node:fs';
import crypto from 'node:crypto';
import path from 'node:path';

const [csvPath, statesPath, districtsPath, outDir] = process.argv.slice(2);
const readJson = (p) => JSON.parse(fs.readFileSync(p, 'utf8').replace(/^﻿/, ''));

// Official 36 states/UTs with codes (as seeded in seed_states_rajasthan_districts.sql).
const OFFICIAL = {
  'andaman and nicobar islands': 'AN', 'andhra pradesh': 'AP', 'arunachal pradesh': 'AR', 'assam': 'AS',
  'bihar': 'BR', 'chandigarh': 'CH', 'chhattisgarh': 'CT', 'dadra and nagar haveli and daman and diu': 'DN',
  'delhi': 'DL', 'goa': 'GA', 'gujarat': 'GJ', 'haryana': 'HR', 'himachal pradesh': 'HP',
  'jammu and kashmir': 'JK', 'jharkhand': 'JH', 'karnataka': 'KA', 'kerala': 'KL', 'ladakh': 'LA',
  'lakshadweep': 'LD', 'madhya pradesh': 'MP', 'maharashtra': 'MH', 'manipur': 'MN', 'meghalaya': 'ML',
  'mizoram': 'MZ', 'nagaland': 'NL', 'odisha': 'OR', 'puducherry': 'PY', 'punjab': 'PB', 'rajasthan': 'RJ',
  'sikkim': 'SK', 'tamil nadu': 'TN', 'telangana': 'TG', 'tripura': 'TR', 'uttar pradesh': 'UP',
  'uttarakhand': 'UT', 'west bengal': 'WB',
};
const normState = (s) => s.toLowerCase().replace(/^the\s+/, '').replace(/&/g, 'and').replace(/\s+/g, ' ').trim();
const normDistrict = (s) => s.toLowerCase().replace(/[^a-z]/g, '');
const titleCase = (s) => s.trim().toLowerCase().replace(/(^|[\s\-(])([a-z])/g, (m, a, b) => a + b.toUpperCase())
  .replace(/\b(And|Of)\b/g, (m) => m.toLowerCase());

// --- Parse CSV (all fields quoted) ---
const lines = fs.readFileSync(csvPath, 'utf8').split(/\r?\n/).filter(Boolean);
const header = lines[0].replace(/"/g, '').split(',');
const col = (n) => header.indexOf(n);
const iPin = col('Pincode'), iDist = col('District'), iState = col('StateName'), iOffice = col('OfficeName');
const rows = [];
let malformed = 0;
for (const line of lines.slice(1)) {
  const f = line.slice(1, -1).split('","');
  const pin = f[iPin], dist = f[iDist], state = f[iState];
  if (!/^[1-9][0-9]{5}$/.test(pin || '') || !dist || !state || dist === 'NA' || state === 'NA') { malformed++; continue; }
  rows.push({ pin, sourceDistrict: dist, sourceState: state, office: f[iOffice] });
}

// --- Coverage ---
const unknownStates = new Set();
const districts = new Map(); // key code|normDistrict -> {code, name, sourceSpellings:Set, pins:Set}
const pins = new Map(); // pin -> Set(key)
for (const r of rows) {
  const code = OFFICIAL[normState(r.sourceState)];
  if (!code) { unknownStates.add(r.sourceState); continue; }
  const key = `${code}|${normDistrict(r.sourceDistrict)}`;
  if (!districts.has(key)) districts.set(key, { code, name: titleCase(r.sourceDistrict), spellings: new Set(), pins: new Set() });
  const d = districts.get(key);
  d.spellings.add(r.sourceDistrict);
  d.pins.add(r.pin);
  if (!pins.has(r.pin)) pins.set(r.pin, new Set());
  pins.get(r.pin).add(key);
}
const byState = {};
for (const code of Object.values(OFFICIAL)) byState[code] = { districts: 0, pins: new Set() };
for (const d of districts.values()) { byState[d.code].districts++; d.pins.forEach((p) => byState[d.code].pins.add(p)); }
const ambiguous = [...pins.entries()].filter(([, s]) => s.size > 1);
const crossState = ambiguous.filter(([, s]) => new Set([...s].map((k) => k.split('|')[0])).size > 1);
const spellingVariants = [...districts.values()].filter((d) => d.spellings.size > 1);

// --- Reconcile with live snapshot ---
const liveStates = readJson(statesPath);
const liveDistricts = readJson(districtsPath);
const DEMO_STATE = /^10000000-0000-0000-0000-/; // seed_broker_demo_dataset.sql rows
const liveByCode = {};
for (const s of liveStates) (liveByCode[s.code] ??= []).push(s);
const duplicateStateCodes = Object.entries(liveByCode).filter(([, v]) => v.length > 1).map(([c, v]) => ({ code: c, ids: v.map((x) => x.id) }));
const stateIdToCode = Object.fromEntries(liveStates.map((s) => [s.id, s.code]));
const liveDistrictKeys = new Map();
for (const d of liveDistricts) liveDistrictKeys.set(`${stateIdToCode[d.state_id]}|${normDistrict(d.name)}`, d);
// Audited aliases: India Post postal name -> existing live district (same district, different official name).
const ALIASES = { 'RJ|ganganagar': 'RJ|sriganganagar' };
const isLive = (k) => liveDistrictKeys.has(k) || liveDistrictKeys.has(ALIASES[k]);
const missingLiveStates = Object.values(OFFICIAL).filter((c) => !liveByCode[c]);
const alreadyLive = [...districts.keys()].filter(isLive);
const aliasedToLive = Object.keys(ALIASES).filter((k) => districts.has(k) && liveDistrictKeys.has(ALIASES[k]));
const liveNotInPostal = [...liveDistrictKeys.entries()]
  .filter(([k]) => !districts.has(k) && !Object.values(ALIASES).includes(k))
  .map(([k, d]) => `${k.split('|')[0]}: ${d.name}`);
const toInsert = [...districts.entries()].filter(([k]) => !isLive(k));

// Near-duplicate spellings within a state (edit distance <= 2) — reported for review, not merged.
function lev(a, b) {
  const m = Array.from({ length: a.length + 1 }, (_, i) => [i, ...Array(b.length).fill(0)]);
  for (let j = 1; j <= b.length; j++) m[0][j] = j;
  for (let i = 1; i <= a.length; i++) for (let j = 1; j <= b.length; j++)
    m[i][j] = Math.min(m[i - 1][j] + 1, m[i][j - 1] + 1, m[i - 1][j - 1] + (a[i - 1] === b[j - 1] ? 0 : 1));
  return m[a.length][b.length];
}
const nearDuplicates = [];
const keysByState = {};
for (const k of districts.keys()) (keysByState[k.split('|')[0]] ??= []).push(k.split('|')[1]);
for (const [code, names] of Object.entries(keysByState))
  for (let i = 0; i < names.length; i++) for (let j = i + 1; j < names.length; j++)
    if (names[i].length > 4 && lev(names[i], names[j]) <= 2) nearDuplicates.push(`${code}: ${names[i]} ~ ${names[j]}`);

// --- Deterministic UUIDv5 ---
const NAMESPACE = 'b7e1c3a2-52d4-5c6e-9f10-2a6b8d4e0c01'; // RB-SELLER-ADDRESS-PIN-COVERAGE-01
function uuidv5(name) {
  const ns = Buffer.from(NAMESPACE.replace(/-/g, ''), 'hex');
  const h = crypto.createHash('sha1').update(Buffer.concat([ns, Buffer.from(name, 'utf8')])).digest();
  h[6] = (h[6] & 0x0f) | 0x50; h[8] = (h[8] & 0x3f) | 0x80;
  const x = h.subarray(0, 16).toString('hex');
  return `${x.slice(0, 8)}-${x.slice(8, 12)}-${x.slice(12, 16)}-${x.slice(16, 20)}-${x.slice(20)}`;
}
const q = (s) => `'${s.replace(/'/g, "''")}'`;
const values = toInsert
  .sort(([a], [b]) => a.localeCompare(b))
  .map(([k, d]) => `  (${q(uuidv5(k))}::uuid, ${q(d.code)}, ${q(d.name)})`);

const migration = `-- 0052_seed_national_districts.sql  (RB-SELLER-ADDRESS-PIN-COVERAGE-01) — NOT APPLIED; requires approval.
-- Adds districts for all 36 states/UTs from the India Post "All India Pincode Directory"
-- (data.gov.in, GODL-India; mirror github.com/dropdevrahul/pincodes-india, snapshot 2024-06-30).
-- Names are India Post postal district names (title-cased). IDs are UUIDv5(namespace ${NAMESPACE}, '<STATE_CODE>|<normalised name>').
-- Idempotent: skips any district whose normalised name already exists under any master_states row with
-- the same state code, and ON CONFLICT (id) DO NOTHING. Never updates or deletes existing rows.
-- State resolution: the non-demo master_states row for the code (demo rows 10000000-0000-0000-0000-* are excluded);
-- if several remain, the lowest id. Codes with no master_states row are skipped (reported by the final NOTICE).
BEGIN;

CREATE TEMP TABLE _rb_new_districts (id uuid PRIMARY KEY, state_code text NOT NULL, name text NOT NULL) ON COMMIT DROP;
INSERT INTO _rb_new_districts (id, state_code, name) VALUES
${values.join(',\n')};

INSERT INTO public.master_districts (id, name, state_id)
SELECT n.id, n.name, s.state_id
FROM _rb_new_districts n
JOIN LATERAL (
  SELECT ms.id AS state_id FROM public.master_states ms
  WHERE ms.code = n.state_code AND ms.id::text NOT LIKE '10000000-0000-0000-0000-%'
  ORDER BY ms.id LIMIT 1
) s ON true
WHERE NOT EXISTS (
  SELECT 1 FROM public.master_districts d
  JOIN public.master_states ms2 ON ms2.id = d.state_id
  WHERE ms2.code = n.state_code
    AND regexp_replace(lower(d.name), '[^a-z]', '', 'g') = regexp_replace(lower(n.name), '[^a-z]', '', 'g')
)
ON CONFLICT (id) DO NOTHING;

DO $$
DECLARE skipped int;
BEGIN
  SELECT count(*) INTO skipped FROM _rb_new_districts n
  WHERE NOT EXISTS (SELECT 1 FROM public.master_states ms WHERE ms.code = n.state_code);
  IF skipped > 0 THEN RAISE NOTICE '0052: % districts skipped (state code missing in master_states)', skipped; END IF;
END $$;

COMMIT;
`;

const rollback = `-- rollback_0052.sql — removes ONLY rows introduced by 0052 (deterministic ids). NOT APPLIED.
-- Refuses to run if any of these districts is referenced (availabilities/requirements/companies etc. via FK).
BEGIN;
DELETE FROM public.master_districts WHERE id IN (
${toInsert.map(([k]) => `  ${q(uuidv5(k))}`).join(',\n')}
);
COMMIT;
`;

fs.mkdirSync(outDir, { recursive: true });
fs.writeFileSync(path.join(outDir, '0052_seed_national_districts.sql'), migration);
fs.writeFileSync(path.join(outDir, 'rollback_0052.sql'), rollback);

const report = {
  source: { rows: lines.length - 1, validRows: rows.length, malformedOrNA: malformed, unknownStateNames: [...unknownStates] },
  national: {
    statesCovered: Object.entries(byState).filter(([, v]) => v.districts > 0).length,
    statesMissing: Object.entries(byState).filter(([, v]) => v.districts === 0).map(([c]) => c),
    districtCount: districts.size,
    pinCount: pins.size,
    ambiguousPins: ambiguous.length,
    crossStatePins: crossState.length,
    crossStatePinExamples: crossState.slice(0, 10).map(([p, s]) => `${p}: ${[...s].join(' / ')}`),
    districtSpellingVariantsMerged: spellingVariants.length,
    spellingVariantExamples: spellingVariants.slice(0, 8).map((d) => `${d.code}: ${[...d.spellings].join(' | ')}`),
  },
  byState: Object.fromEntries(Object.entries(byState).map(([c, v]) => [c, { districts: v.districts, pins: v.pins.size }])),
  reconciliation: {
    liveStates: liveStates.length,
    duplicateStateCodes,
    officialCodesMissingInLive: missingLiveStates,
    liveDistricts: liveDistricts.length,
    postalDistrictsAlreadyLive: alreadyLive.length,
    aliasedToLive,
    nearDuplicateSpellings: nearDuplicates,
    liveDistrictsNotInPostalData: liveNotInPostal,
    districtsToInsert: toInsert.length,
  },
  namespace: NAMESPACE,
};
fs.writeFileSync(path.join(outDir, 'coverage_report.json'), JSON.stringify(report, null, 2));
console.log(JSON.stringify(report, null, 2));
