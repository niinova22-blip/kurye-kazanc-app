// pgTAP testlerini yukler ve calistirir. Basarisizlikta cikis kodu 1. Bitince tests semasini siler.
import { readdirSync, readFileSync } from 'node:fs';
import { join } from 'node:path';
import { sql } from './lib.mjs';

const dir = 'supabase/tests';
let code = 1;
try {
  for (const name of readdirSync(dir).filter((f) => f.endsWith('.sql')).sort()) {
    await sql(readFileSync(join(dir, name), 'utf8'));
  }
  const rows = await sql("set search_path = public, extensions; select * from extensions.runtests('tests'::name)");
  const lines = rows.map((r) => Object.values(r)[0]);
  for (const line of lines) console.log(line);
  const failed = lines.filter((l) => /^\s*not ok/.test(l));
  const passed = lines.filter((l) => /^\s*ok/.test(l));
  if (lines.length === 0 || passed.length === 0) {
    console.log('HIC SONUC YOK: testler calismadi');
  } else if (failed.length > 0) {
    console.log(`${failed.length} TEST BASARISIZ`);
  } else {
    console.log('TUM TESTLER GECTI');
    code = 0;
  }
} catch (err) {
  console.error(String(err));
} finally {
  try { await sql('drop schema if exists tests cascade'); } catch (err) { console.error(`tests semasi silinemedi: ${err}`); }
}
process.exit(code);
