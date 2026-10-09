// Gomulu sablonlari (BundledTemplates.swift icindeki JSON) ocr_templates tablosuna yazar.
import { readFileSync } from 'node:fs';
import { sql } from './lib.mjs';

const source = readFileSync('KuryeKazanc/Core/OCR/BundledTemplates.swift', 'utf8');
const match = source.match(/#"""\s*([\s\S]*?)\s*"""#/);
if (!match) { console.error('JSON bulunamadi'); process.exit(1); }
const templates = JSON.parse(match[1]);
const q = (s) => String(s).replace(/'/g, "''");
for (const t of templates) {
  const body = q(JSON.stringify(t));
  await sql(`insert into public.ocr_templates (id, platform_code, version, status, body)
    values ('${q(t.id)}', '${q(t.platformCode)}', ${Number(t.version)}, '${q(t.status)}', '${body}'::jsonb)
    on conflict (id, version) do update set body = excluded.body, status = excluded.status, updated_at = now()`);
  console.log(`sablon: ${t.id} v${t.version}`);
}
