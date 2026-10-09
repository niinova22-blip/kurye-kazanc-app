// Yonetici onayi: kurala yeni surum ekler ya da kaynak kontrolunu kapatir. Kurallar yalnizca bu betikle degisir.
//
//   node scripts/server/approve_rule.mjs --list
//       Incelemede bekleyen kaynak kontrolleri.
//   node scripts/server/approve_rule.mjs --rule tgo-peak --set status=verified --set confidence=0.8 [--set params='{"hours":18}'] [--check 12]
//       tgo-peak'in son surumunu kopyalar, verilen alanlari degistirir, version+1 ve last_checked_on=bugun ile ekler.
//       --check verilirse o kaynak kontrolu "approved" olur.
//   node scripts/server/approve_rule.mjs --recheck tgo-peak [--check 12]
//       Icerik ayni, kaynak yeniden okundu: yalnizca last_checked_on bugune cekilen yeni surum.
//   node scripts/server/approve_rule.mjs --ignore 12 --note "yalnizca tasarim degisikligi"
import { sql } from './lib.mjs';

const args = process.argv.slice(2);
const get = (flag) => { const i = args.indexOf(flag); return i >= 0 ? args[i + 1] : undefined; };
const all = (flag) => args.flatMap((a, i) => (a === flag ? [args[i + 1]] : []));
const q = (v) => (v === null || v === undefined ? 'null' : `'${String(v).replace(/'/g, "''")}'`);

const editable = new Set(['description', 'source_url', 'source_kind', 'published_on', 'valid_from', 'valid_to', 'status',
  'confidence', 'courier_model', 'region', 'params', 'kind', 'category']);

if (args.includes('--list')) {
  const rows = await sql(`select id, source_url, rule_ids, checked_at, review_status, note from public.rule_source_checks
    where review_status in ('pending','error') order by checked_at desc limit 100`);
  for (const r of rows) console.log(`#${r.id} ${r.review_status} ${r.checked_at} ${r.source_url} [${r.rule_ids}] ${r.note ?? ''}`);
  if (rows.length === 0) console.log('Bekleyen kontrol yok.');
  process.exit(0);
}

const ignore = get('--ignore');
if (ignore) {
  await sql(`update public.rule_source_checks set review_status = 'ignored', note = ${q(get('--note') ?? 'yonetici: degisiklik kurala etki etmiyor')}
    where id = ${Number(ignore)}`);
  console.log(`kontrol #${ignore} kapatildi`);
  process.exit(0);
}

const ruleID = get('--rule') ?? get('--recheck');
if (!ruleID) { console.error('Kullanim icin dosya basindaki aciklamaya bakin.'); process.exit(2); }
const current = (await sql(`select * from public.platform_rules where id = ${q(ruleID)} order by version desc limit 1`))[0];
if (!current) { console.error(`kural yok: ${ruleID}`); process.exit(1); }

const next = { ...current };
for (const pair of all('--set')) {
  const eq = pair.indexOf('=');
  const key = pair.slice(0, eq);
  const value = pair.slice(eq + 1);
  if (!editable.has(key)) { console.error(`degistirilemez alan: ${key}`); process.exit(2); }
  next[key] = key === 'params' ? JSON.parse(value) : key === 'confidence' ? Number(value) : value === 'null' ? null : value;
}
next.version = Number(current.version) + 1;
next.last_checked_on = new Date().toISOString().slice(0, 10);

await sql(`insert into public.platform_rules (id, version, platform_code, category, kind, params, description, source_url,
    source_kind, published_on, last_checked_on, valid_from, valid_to, status, confidence, courier_model, region, previous_id, approved_by)
  values (${q(next.id)}, ${next.version}, ${q(next.platform_code)}, ${q(next.category)}, ${q(next.kind)},
    ${q(JSON.stringify(typeof next.params === 'string' ? JSON.parse(next.params) : next.params))}::jsonb, ${q(next.description)},
    ${q(next.source_url)}, ${q(next.source_kind)}, ${q(next.published_on)}, ${q(next.last_checked_on)}, ${q(next.valid_from)},
    ${q(next.valid_to)}, ${q(next.status)}, ${Number(next.confidence)}, ${q(next.courier_model)}, ${q(next.region)},
    ${q(current.previous_id)}, ${q(process.env.USER ?? process.env.USERNAME ?? 'admin')})`);
console.log(`${next.id} v${next.version} eklendi (durum ${next.status}, guven ${next.confidence})`);

const check = get('--check');
if (check) {
  await sql(`update public.rule_source_checks set review_status = 'approved', note = ${q(`${next.id} v${next.version}`)}
    where id = ${Number(check)}`);
  console.log(`kontrol #${check} onaylandi`);
}
console.log('Not: gomulu yedek (BundledRules.swift) sonraki surumde guncellenmeli.');
