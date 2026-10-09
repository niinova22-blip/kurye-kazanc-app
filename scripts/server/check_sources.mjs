// Kural kaynaklarini indirir, metin ozetini (SHA-256) bir onceki kontrolle karsilastirir ve rule_source_checks'e yazar.
// KURALLARI DEGISTIRMEZ: degisen kaynak "pending" olarak isaretlenir; yonetici inceleyip approve_rule.mjs ile onaylar.
// Kullanim: node scripts/server/check_sources.mjs            (tum kaynaklar)
//           node scripts/server/check_sources.mjs --dry-run  (veritabanina yazmadan rapor)
import { createHash } from 'node:crypto';
import { sql } from './lib.mjs';

const dryRun = process.argv.includes('--dry-run');
const q = (v) => (v === null || v === undefined ? 'null' : `'${String(v).replace(/'/g, "''")}'`);

// En yuksek surumdeki kurallarin kaynaklari
const rows = await sql(`select distinct on (id) id, source_url from public.platform_rules
  where source_url is not null order by id, version desc`);
const bySource = new Map();
for (const r of rows) {
  if (!bySource.has(r.source_url)) bySource.set(r.source_url, []);
  bySource.get(r.source_url).push(r.id);
}

// Sayfa metnini sadelestir: etiketler, betikler ve tarih/saat gibi her yuklemede degisen parcalar ozete girmesin.
function normalize(html) {
  return html
    .replace(/<script[\s\S]*?<\/script>/gi, ' ')
    .replace(/<style[\s\S]*?<\/style>/gi, ' ')
    .replace(/<[^>]+>/g, ' ')
    .replace(/&nbsp;/g, ' ')
    .replace(/\d{1,2}:\d{2}(:\d{2})?/g, ' ')
    .replace(/\s+/g, ' ')
    .trim()
    .toLowerCase();
}

let changedCount = 0;
for (const [url, ids] of bySource) {
  const prev = (await sql(`select content_hash from public.rule_source_checks
    where source_url = ${q(url)} and content_hash is not null order by checked_at desc limit 1`))[0]?.content_hash ?? null;
  let status = null;
  let hash = null;
  let note = null;
  try {
    const res = await fetch(url, { headers: { 'User-Agent': 'KuryeKazanc-RuleCheck/1.0' }, redirect: 'follow' });
    status = res.status;
    if (res.ok) {
      const text = normalize(await res.text());
      hash = createHash('sha256').update(text).digest('hex');
    } else {
      note = `HTTP ${res.status}`;
    }
  } catch (err) {
    note = String(err).slice(0, 300);
  }
  const changed = hash !== null && prev !== null && hash !== prev;
  const review = hash === null ? 'error' : changed ? 'pending' : prev === null ? 'pending' : 'unchanged';
  if (changed) changedCount += 1;
  console.log(`${review.padEnd(9)} ${url} [${ids.join(', ')}]${note ? ` — ${note}` : ''}`);
  if (!dryRun) {
    await sql(`insert into public.rule_source_checks (source_url, rule_ids, http_status, content_hash, previous_hash, changed, review_status, note)
      values (${q(url)}, array[${ids.map(q).join(',')}]::text[], ${status ?? 'null'}, ${q(hash)}, ${q(prev)}, ${changed}, ${q(review)}, ${q(note)})`);
  }
}
console.log(`${bySource.size} kaynak kontrol edildi, ${changedCount} degisiklik incelemeye alindi.`);
console.log('Degisen kaynaklar icin: node scripts/server/approve_rule.mjs --list');
