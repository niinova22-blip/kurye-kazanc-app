// pgTAP testlerini yukler ve calistirir. Basarisizlikta cikis kodu 1.
import { readdirSync, readFileSync } from 'node:fs';
import { join } from 'node:path';
import { sql } from './lib.mjs';

const dir = 'supabase/tests';
for (const name of readdirSync(dir).filter((f) => f.endsWith('.sql')).sort()) {
  await sql(readFileSync(join(dir, name), 'utf8'));
}
const rows = await sql("select * from extensions.runtests('tests'::name)");
const lines = rows.map((r) => Object.values(r)[0]);
for (const line of lines) console.log(line);
const failed = lines.filter((l) => /^\s*not ok/.test(l));
console.log(failed.length === 0 ? 'TUM TESTLER GECTI' : `${failed.length} TEST BASARISIZ`);
process.exit(failed.length === 0 ? 0 : 1);
