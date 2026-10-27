import fs from 'node:fs';

const env = fs.readFileSync('.env.local', 'utf8');
const lines = env.split(/\r?\n/).filter(l => l.includes('=') && !l.startsWith('#'));
for (const line of lines) {
  const idx = line.indexOf('=');
  const k = line.slice(0, idx).trim();
  const v = line.slice(idx + 1).trim().replace(/^"|"$/g, '');
  if (k.includes('URL') || k.includes('PROJECT') || k.includes('ENV')) {
    try {
      const u = new URL(v);
      console.log(k, '-> host:', u.host, 'protocol:', u.protocol);
    } catch (_) {
      console.log(k, '->', v.slice(0, 20) + '...');
    }
  } else {
    console.log(k, '-> [SET, len=' + v.length + ']');
  }
}
