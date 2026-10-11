// Dinamik tarife takibinin saf mantigi (ag ve veritabani yok; node --test ile test edilir).
// Kesif -> dogrulama -> yayim zincirinde karar veren her kural burada.
import { createHash } from 'node:crypto';

export const OFFICIAL_TYPES = new Set(['official_announcement', 'official_channel', 'official_document']);
export const SOURCE_PRIORITY = {
  official_announcement: 1, official_channel: 2, official_document: 3, news: 4, user_upload: 5, courier_reports: 6,
};

export const CANDIDATE_STATUSES = ['draft', 'pending_verification', 'needs_more_sources', 'approved', 'published',
  'rejected', 'expired', 'withdrawn'];

// Veritabanindaki tariff_candidate_transition_ok ile ayni tablo.
const TRANSITIONS = {
  draft: ['pending_verification', 'needs_more_sources', 'approved', 'rejected'],
  pending_verification: ['approved', 'rejected', 'needs_more_sources', 'expired'],
  needs_more_sources: ['pending_verification', 'approved', 'rejected', 'expired'],
  approved: ['published', 'rejected', 'pending_verification', 'expired'],
  published: ['withdrawn', 'expired'],
  rejected: [], expired: [], withdrawn: [],
};

export function canTransition(from, to) {
  return from === to || (TRANSITIONS[from] ?? []).includes(to);
}

/** Sayfa metnini sadelestirir: etiketler, betikler, stiller, saat damgalari ve bosluklar ozete girmez. */
export function normalizeText(html) {
  return String(html)
    .replace(/<script[\s\S]*?<\/script>/gi, ' ')
    .replace(/<style[\s\S]*?<\/style>/gi, ' ')
    .replace(/<!--[\s\S]*?-->/g, ' ')
    .replace(/<[^>]+>/g, ' ')
    .replace(/&nbsp;/g, ' ')
    .replace(/&amp;/g, '&')
    .replace(/\d{1,2}:\d{2}(:\d{2})?/g, ' ')
    .replace(/\s+/g, ' ')
    .trim()
    .toLocaleLowerCase('tr-TR');
}

export function hashText(text) {
  return createHash('sha256').update(text).digest('hex');
}

/** "1.610" -> 1610, "64,50" -> 64.5, "1.234,56" -> 1234.56, "12.50" -> 12.5. Gecersizse null. */
export function parseAmount(raw) {
  if (raw === null || raw === undefined) return null;
  let t = String(raw).replace(/₺|TL/gi, '').replace(/[\s ]/g, '');
  if (!t) return null;
  const comma = t.lastIndexOf(',');
  const dot = t.lastIndexOf('.');
  if (comma >= 0 && dot >= 0) {
    t = comma > dot ? t.replace(/\./g, '').replace(',', '.') : t.replace(/,/g, '');
  } else if (comma >= 0) {
    t = t.replace(',', '.');
  } else if (dot >= 0) {
    const parts = t.split('.');
    if (parts.length > 2 || parts[parts.length - 1].length === 3) t = t.replace(/\./g, '');
  }
  if (!/^-?\d+(\.\d+)?$/.test(t)) return null;
  return Math.round(Number(t) * 100) / 100;
}

/**
 * Yapilandirilmis alan cikarimi. Profil: [{item_key, pattern, field='amount'}]; pattern'in 1. grubu sayi.
 * Donus: {values: {item_key: {amount?, amount_upper?, lower_threshold?}}, matched, total, confidence}.
 */
export function extractValues(text, profile) {
  const values = {};
  let matched = 0;
  const rules = Array.isArray(profile) ? profile : [];
  for (const rule of rules) {
    let re;
    try { re = new RegExp(rule.pattern, 'iu'); } catch { continue; }
    const m = text.match(re);
    if (!m || m[1] === undefined) continue;
    const value = parseAmount(m[1]);
    if (value === null) continue;
    const field = rule.field ?? 'amount';
    values[rule.item_key] = { ...(values[rule.item_key] ?? {}), [field]: value };
    matched += 1;
  }
  const total = rules.length;
  return { values, matched, total, confidence: total === 0 ? 0 : Math.round((matched / total) * 100) / 100 };
}

const MONTHS = { ocak: 1, şubat: 2, subat: 2, mart: 3, nisan: 4, mayıs: 5, mayis: 5, haziran: 6, temmuz: 7, ağustos: 8,
  agustos: 8, eylül: 9, eylul: 9, ekim: 10, kasım: 11, kasim: 11, aralık: 12, aralik: 12 };

/** "1 Kasım 2026 itibarıyla" -> {date: '2026-11-01', certain: true}. Anahtar kelime yoksa certain false. */
export function extractEffectiveDate(text) {
  const re = /(\d{1,2})\s+(ocak|şubat|subat|mart|nisan|mayıs|mayis|haziran|temmuz|ağustos|agustos|eylül|eylul|ekim|kasım|kasim|aralık|aralik)\s+(20\d{2})(.{0,40})/iu;
  const m = String(text).toLocaleLowerCase('tr-TR').match(re);
  if (!m) return { date: null, certain: false };
  const month = MONTHS[m[2]];
  const day = Number(m[1]);
  if (!month || day < 1 || day > 31) return { date: null, certain: false };
  const date = `${m[3]}-${String(month).padStart(2, '0')}-${String(day).padStart(2, '0')}`;
  const certain = /(itibar|geçerli|gecerli|yürürlü|yururlu|başla|basla)/u.test(m[4]);
  return { date, certain };
}

const round2 = (n) => Math.round(n * 100) / 100;

/**
 * Aktif kalemler ile cikarilan degerleri karsilastirir. Yalnizca ucreti etkileyen alanlar.
 * activeItems: [{item_key, label, amount, amount_upper, lower_threshold, upper_threshold}] (sayilar number|string).
 */
export function diffItems(activeItems, extracted) {
  const byKey = new Map(activeItems.map((i) => [i.item_key, i]));
  const changes = [];
  for (const key of Object.keys(extracted).sort()) {
    const next = extracted[key];
    const current = byKey.get(key);
    if (!current) {
      if (next.amount === undefined) continue;
      changes.push({ kind: 'added', item_key: key, label: key, old_amount: null, new_amount: next.amount,
        ...(next.amount_upper !== undefined ? { new_amount_upper: next.amount_upper } : {}),
        ...(next.lower_threshold !== undefined ? { new_lower_threshold: next.lower_threshold } : {}) });
      continue;
    }
    const fields = [['amount', 'old_amount', 'new_amount'], ['amount_upper', 'old_amount_upper', 'new_amount_upper'],
      ['lower_threshold', 'old_lower_threshold', 'new_lower_threshold'], ['upper_threshold', 'old_upper_threshold', 'new_upper_threshold']];
    const change = { kind: 'changed', item_key: key, label: current.label ?? key };
    let differs = false;
    for (const [field, oldName, newName] of fields) {
      if (next[field] === undefined) continue;
      const before = current[field] === null || current[field] === undefined ? null : Number(current[field]);
      if (before === null || round2(before) !== round2(next[field])) differs = true;
      change[oldName] = before;
      change[newName] = next[field];
    }
    if (!differs) continue;
    if (change.old_amount !== undefined && change.new_amount !== undefined && change.old_amount) {
      change.abs = round2(change.new_amount - change.old_amount);
      change.pct = round2(((change.new_amount - change.old_amount) / change.old_amount) * 100);
    } else if (change.new_amount === undefined) {
      change.old_amount = current.amount === null ? null : Number(current.amount);
      change.new_amount = change.old_amount;
    }
    changes.push(change);
  }
  return changes;
}

/** Ayni degisiklik (ayni surum, ayni tarih, ayni yeni degerler) her zaman ayni parmak izini verir. */
export function fingerprint({ platform_id, tariff_version_id, effective_from, changes }) {
  const canonical = changes
    .map((c) => ({ k: c.item_key, kind: c.kind, a: c.new_amount ?? null, u: c.new_amount_upper ?? null,
      l: c.new_lower_threshold ?? null, h: c.new_upper_threshold ?? null }))
    .sort((a, b) => (a.k < b.k ? -1 : a.k > b.k ? 1 : 0));
  return hashText(JSON.stringify({ p: platform_id, v: tariff_version_id, e: effective_from ?? null, c: canonical }));
}

/**
 * Insan onayi gereken durumlari belirler. Otomatik yayim yalnizca: ayar acik + tek ve guvenilir resmi kaynak +
 * baska hicbir belirsizlik yok. Ekonomik gostergeler asla aday uretmez.
 */
export function evaluatePolicy({ sourceTypes, sourceCount, conflicting = false, ocrConfidence = 1, effectiveDateCertain,
  stackingAmbiguous = false, scopeAmbiguous = false, changes, config }) {
  const reasons = [];
  const types = sourceTypes ?? [];
  const allOfficial = types.length > 0 && types.every((t) => OFFICIAL_TYPES.has(t));
  const independent = sourceCount ?? types.length;
  if (!allOfficial && independent < 2) reasons.push('Tek ikincil kaynak');
  if (conflicting) reasons.push('Çelişen kaynaklar');
  if (ocrConfidence < (config.min_ocr_confidence ?? 0.9)) reasons.push('Düşük OCR / metin çıkarım güveni');
  if (!effectiveDateCertain) reasons.push('Belirsiz yürürlük tarihi');
  if (stackingAmbiguous) reasons.push('Bonusların birlikte uygulanma belirsizliği');
  if (scopeAmbiguous) reasons.push('Bölge / çalışma modeli belirsizliği');
  const limit = config.large_change_pct ?? 25;
  if (changes.some((c) => c.kind !== 'changed' || (typeof c.pct === 'number' && Math.abs(c.pct) > limit))) {
    reasons.push('Olağan dışı büyük fark ya da kalem ekleme/çıkarma');
  }
  const autoPublish = config.auto_publish_official === true && allOfficial && reasons.length === 0;
  let status = 'pending_verification';
  if (autoPublish) status = 'approved';
  else if (!allOfficial && independent < 2 && !conflicting) status = 'needs_more_sources';
  return { autoPublish, requiresHuman: !autoPublish, reasons, status,
    verification: allOfficial && reasons.length === 0 ? 'verified' : 'needs_verification' };
}

/** Kaynak kontrol zamani geldi mi (yapilandirilabilir siklik). */
export function isDue(source, now) {
  if (!source.active) return false;
  if (!source.last_checked_at) return true;
  const last = new Date(source.last_checked_at).getTime();
  return now.getTime() - last >= Number(source.check_interval_minutes) * 60_000;
}

/** Basit robots.txt yorumu: bizim ajan ya da * icin Disallow on eki. */
export function robotsAllows(robotsTxt, path, agent = 'KuryeKazanc-TariffCheck') {
  if (!robotsTxt) return true;
  const lines = String(robotsTxt).split(/\r?\n/).map((l) => l.replace(/#.*/, '').trim());
  let applies = false;
  let sawSpecific = false;
  const rules = { specific: [], any: [] };
  for (const line of lines) {
    const [rawKey, ...rest] = line.split(':');
    if (!rawKey || rest.length === 0) continue;
    const key = rawKey.trim().toLowerCase();
    const value = rest.join(':').trim();
    if (key === 'user-agent') {
      applies = value === '*' ? 'any' : agent.toLowerCase().startsWith(value.toLowerCase()) ? 'specific' : false;
      if (applies === 'specific') sawSpecific = true;
    } else if (key === 'disallow' && applies) {
      rules[applies].push(value);
    }
  }
  const list = sawSpecific ? rules.specific : rules.any;
  return !list.some((prefix) => prefix && path.startsWith(prefix));
}

/** Yaklasan yururluk tarihleri (gun icinde). */
export function upcoming(dates, today, withinDays = 7) {
  const start = new Date(`${today}T00:00:00Z`).getTime();
  return dates.filter((d) => {
    if (!d.effective_from) return false;
    const t = new Date(`${String(d.effective_from).slice(0, 10)}T00:00:00Z`).getTime();
    return t >= start && t - start <= withinDays * 86_400_000;
  });
}

/** Ekonomik gosterge: yalnizca uyari. Tarife degisikligi ya da aday uretmez. */
export function indicatorAlerts({ kind, value, previous, period, fetchedAt }) {
  const alerts = [];
  if (!fetchedAt) alerts.push(`${kind}: kaynak tarihi yok, güncel sayılmaz`);
  if (previous && value > previous) {
    const pct = round2(((value - previous) / previous) * 100);
    alerts.push(`${kind} ${period ?? ''} %${pct} arttı; maliyet karşılama oranı düşmüş olabilir (tarife değişmedi).`);
  }
  return alerts;
}
