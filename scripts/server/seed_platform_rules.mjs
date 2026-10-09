// Gomulu baslangic kurallarini (BundledRules.swift icindeki JSON) platform_rules tablosuna yazar.
// Ayni (id, version) varsa dokunmaz: sunucudaki onayli surumler ezilmez. Kural degisikligi icin approve_rule.mjs.
import { readFileSync } from 'node:fs';
import { sql } from './lib.mjs';

const source = readFileSync('KuryeKazanc/Core/Planner/BundledRules.swift', 'utf8');
const match = source.match(/#"""\s*([\s\S]*?)\s*"""#/);
if (!match) { console.error('JSON bulunamadi'); process.exit(1); }
const rules = JSON.parse(match[1]);
const q = (v) => (v === null || v === undefined ? 'null' : `'${String(v).replace(/'/g, "''")}'`);
for (const r of rules) {
  await sql(`insert into public.platform_rules (id, version, platform_code, category, kind, params, description, source_url,
      source_kind, published_on, last_checked_on, valid_from, valid_to, status, confidence, courier_model, region, previous_id, approved_by)
    values (${q(r.id)}, ${Number(r.version)}, ${q(r.platform_code)}, ${q(r.category)}, ${q(r.kind)}, ${q(JSON.stringify(r.params))}::jsonb,
      ${q(r.description)}, ${q(r.source_url)}, ${q(r.source_kind)}, ${q(r.published_on)}, ${q(r.last_checked_on)},
      ${q(r.valid_from)}, ${q(r.valid_to)}, ${q(r.status)}, ${Number(r.confidence)}, ${q(r.courier_model)}, ${q(r.region)},
      ${q(r.previous_id)}, 'seed')
    on conflict (id, version) do nothing`);
  console.log(`kural: ${r.id} v${r.version}`);
}
console.log(`${rules.length} kural islendi`);
