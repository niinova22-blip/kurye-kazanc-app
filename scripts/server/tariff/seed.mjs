// Gomulu ornek tarifeler (BundledTariffs.swift JSON'u, tek kaynak) ve izlenecek kaynaklar.
// Tohum tekrar calistirilabilir: var olan surum / kalem / kaynak ezilmez (sunucudaki onayli degisiklikler korunur).
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';
import { arr, j, q } from './repo.mjs';

const here = dirname(fileURLToPath(import.meta.url));
const root = join(here, '..', '..', '..');

export function bundledVersions() {
  const source = readFileSync(join(root, 'KuryeKazanc/Core/Tariff/BundledTariffs.swift'), 'utf8');
  const match = source.match(/#"""\s*([\s\S]*?)\s*"""#/);
  if (!match) throw new Error('BundledTariffs JSON bulunamadi');
  return JSON.parse(match[1]);
}

export function seedSources() {
  return JSON.parse(readFileSync(join(here, 'sources.json'), 'utf8'));
}

export const PLATFORMS = [
  ['trendyol_go', 'Trendyol GO'],
  ['getir', 'Getir'],
  ['yemeksepeti', 'Yemeksepeti Express'],
  ['migros_hemen', 'Paket Taxi / Migros Hemen'],
];

const num = (v) => (v === null || v === undefined || v === '' ? 'null' : Number(v));
const date = (v) => (v ? `${q(String(v).slice(0, 10))}::date` : 'null');

/** Tek tek calistirilacak SQL ifadeleri (Management API cagri basina tek ifade). */
export function seedStatements(versions = bundledVersions(), sources = seedSources()) {
  const out = [];
  for (const [id, name] of PLATFORMS) {
    out.push(`insert into public.tariff_platforms (platform_id, platform_name) values (${q(id)}, ${q(name)})
      on conflict (platform_id) do nothing`);
  }
  for (const v of versions) {
    out.push(`insert into public.tariff_versions (tariff_version_id, platform_id, work_model, region_id, vehicle_type, version_number,
        revision, effective_from, effective_until, source_type, verification_status, approval_status, approved_at, approved_by,
        change_summary, settings)
      values (${q(v.tariff_version_id)}, ${q(v.platform_id)}, ${q(v.work_model)}, ${q(v.region_id)}, ${q(v.vehicle_type)},
        ${num(v.version_number)}, ${num(v.revision ?? 0)}, ${date(v.effective_from)}, ${date(v.effective_until)}, ${q(v.source_type)},
        ${q(v.verification_status)}, ${q(v.approval_status)}, ${v.approved_at ? `${q(v.approved_at)}::timestamptz` : 'null'},
        ${q(v.approved_by)}, ${q(v.change_summary)}, ${j(v.settings ?? {})})
      on conflict (tariff_version_id) do nothing`);
    for (const i of v.items) {
      out.push(`insert into public.tariff_items (tariff_item_id, tariff_version_id, item_key, item_type, label, amount, amount_upper,
          currency, unit, lower_threshold, upper_threshold, calculation_method, eligibility_conditions, stacking_rule, item_group,
          effective_from, effective_until, confidence_status, is_cash, note)
        values (${q(i.tariff_item_id)}, ${q(v.tariff_version_id)}, ${q(i.item_key)}, ${q(i.item_type)}, ${q(i.label)}, ${num(i.amount)},
          ${num(i.amount_upper)}, ${q(i.currency ?? 'TRY')}, ${q(i.unit)}, ${num(i.lower_threshold)}, ${num(i.upper_threshold)},
          ${q(i.calculation_method)}, ${j(i.eligibility_conditions ?? {})}, ${q(i.stacking_rule ?? 'additive')}, ${q(i.item_group)},
          ${date(i.effective_from)}, ${date(i.effective_until)}, ${q(i.confidence_status)}, ${i.is_cash === false ? 'false' : 'true'},
          ${q(i.note)})
        on conflict (tariff_item_id) do nothing`);
    }
  }
  for (const s of sources) {
    out.push(`insert into public.tariff_sources (source_id, platform_id, tariff_version_id, url, document_ref, source_type, priority,
        check_interval_minutes, extraction_profile, reliability, summary)
      values (${q(s.source_id)}, ${q(s.platform_id)}, ${q(s.tariff_version_id)}, ${q(s.url)}, ${q(s.document_ref)}, ${q(s.source_type)},
        ${num(s.priority)}, ${num(s.check_interval_minutes ?? 1440)}, ${j(s.extraction_profile ?? [])}, ${q(s.reliability ?? 'unknown')},
        ${q(s.summary)})
      on conflict (source_id) do nothing`);
  }
  out.push(`insert into public.tariff_audit_log (actor, action, entity, entity_id, note)
    values ('seed', 'seed', 'tariff_catalog', 'bundled', ${q(`${versions.length} ornek surum, ${sources.length} kaynak (dogrulanmamis)`)})`);
  return out;
}

export { arr };
