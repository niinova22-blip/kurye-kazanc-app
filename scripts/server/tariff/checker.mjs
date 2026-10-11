// Tek kaynagin kontrolu: indir -> sadelestir -> ozet -> alan cikarimi -> aktif tarifeyle karsilastir -> aday.
// KURAL: kontrol basarisiz olursa eski tarife silinmez ve yeni tarife varmis gibi gosterilmez; yalnizca sonuc kaydedilir.
import { diffItems, evaluatePolicy, extractEffectiveDate, extractValues, fingerprint, hashText, normalizeText, robotsAllows } from './core.mjs';

export const USER_AGENT = 'KuryeKazanc-TariffCheck/1.0 (+kurye-kazanc; yalnizca herkese acik sayfalar)';

/** Varsayilan indirici: robots.txt'ye uyar, 30 sn zaman asimi, giris gerektiren sayfalara erismez. */
export async function defaultFetch(url) {
  const res = await fetch(url, {
    headers: { 'User-Agent': USER_AGENT, Accept: 'text/html,application/xhtml+xml,text/plain;q=0.9,*/*;q=0.5',
      'Accept-Language': 'tr-TR,tr;q=0.9' },
    redirect: 'follow', signal: AbortSignal.timeout(30_000),
  });
  return { status: res.status, ok: res.ok, text: res.ok ? await res.text() : '' };
}

export async function defaultRobots(url) {
  try {
    const u = new URL(url);
    const res = await fetch(`${u.origin}/robots.txt`, { headers: { 'User-Agent': USER_AGENT }, signal: AbortSignal.timeout(15_000) });
    return res.ok ? await res.text() : '';
  } catch {
    return '';
  }
}

/**
 * @param {object} p
 * @param {object} p.source tariff_sources satiri
 * @param {object} p.repo createRepo(...)
 * @param {object} p.config tariff_config
 * @param {Function} [p.fetchPage] (url) -> {status, ok, text}
 * @param {Function} [p.fetchRobots] (url) -> robots.txt metni
 * @param {string} p.today yyyy-MM-dd
 * @param {string} [p.runId]
 * @param {string} [p.actor] otomatik yayimda denetim kaydi icin
 * @returns {Promise<{result: string, candidate_id?: string, note?: string, changes?: object[]}>}
 */
export async function checkSource({ source, repo, config, fetchPage = defaultFetch, fetchRobots = defaultRobots, today, runId,
  actor = 'tarife-kontrol (otomatik)' }) {
  const base = { source_id: source.source_id, run_id: runId, previous_hash: source.content_hash };
  const finish = async (record, success, hash) => {
    await repo.recordCheck({ ...base, ...record });
    await repo.markChecked(source.source_id, { success, hash });
    await repo.markPlatformChecked(source.platform_id, success);
    return record;
  };

  if (!source.url) {
    return finish({ result: 'unreadable', note: 'Belge kaynagi: yonetici elle inceler (URL yok).' }, false, null);
  }

  // Kullanim kosullari: robots.txt izin vermiyorsa sayfa indirilmez
  const path = (() => { try { const u = new URL(source.url); return u.pathname + u.search; } catch { return '/'; } })();
  const robots = await fetchRobots(source.url);
  if (!robotsAllows(robots, path)) {
    return finish({ result: 'unreachable', note: 'robots.txt bu sayfaya izin vermiyor; indirilmedi.' }, false, null);
  }

  let page;
  try {
    page = await fetchPage(source.url);
  } catch (err) {
    return finish({ result: 'unreachable', note: String(err).slice(0, 300) }, false, null);
  }
  if (!page.ok) {
    return finish({ result: 'unreachable', http_status: page.status, note: `HTTP ${page.status}` }, false, null);
  }

  const text = normalizeText(page.text);
  const hash = hashText(text);
  if (!text) return finish({ result: 'unreadable', http_status: page.status, note: 'Bos icerik' }, false, null);
  if (source.content_hash && hash === source.content_hash) {
    return finish({ result: 'unchanged', http_status: page.status, content_hash: hash }, true, hash);
  }

  const profile = Array.isArray(source.extraction_profile) ? source.extraction_profile
    : JSON.parse(source.extraction_profile ?? '[]');
  if (profile.length === 0) {
    // Yapilandirilmis alan yok: yalnizca sayfa degisti bilgisi. Ucret degisti sayilmaz; yonetici bakar.
    const first = !source.content_hash;
    return finish({ result: first ? 'unchanged' : 'needs_verification', http_status: page.status, content_hash: hash,
      note: first ? 'Ilk ozet kaydedildi.' : 'Sayfa icerigi degisti; alan cikarim profili yok, yonetici incelemeli.' }, true, hash);
  }

  const extracted = extractValues(text, profile);
  if (extracted.matched === 0) {
    return finish({ result: 'unreadable', http_status: page.status, content_hash: hash, extracted,
      note: 'Profildeki alanlarin hicbiri bulunamadi (sayfa yapisi degismis olabilir).' }, true, hash);
  }

  const effective = extractEffectiveDate(text);
  const day = effective.date && effective.date > today ? effective.date : today;
  const active = await repo.activeItems(source.tariff_version_id, day);
  const changes = diffItems(active, extracted.values);
  if (changes.length === 0) {
    return finish({ result: 'unchanged', http_status: page.status, content_hash: hash, extracted,
      ocr_confidence: extracted.confidence, note: 'Sayfa degisti ama ucret alanlari ayni.' }, true, hash);
  }

  const version = await repo.version(source.tariff_version_id);
  // Acik adaylar ve yakin zamanda yayimlananlar: ayni kaleme farkli deger bildiren kaynak celiski sayilir
  const recent = await repo.recentCandidates(source.tariff_version_id);
  const conflicting = recent.filter((c) => {
    const other = typeof c.changes === 'string' ? JSON.parse(c.changes) : c.changes;
    return other.some((o) => changes.some((n) => n.item_key === o.item_key && n.new_amount !== o.new_amount));
  });
  const policy = evaluatePolicy({ sourceTypes: [source.source_type], sourceCount: 1, conflicting: conflicting.length > 0,
    ocrConfidence: extracted.confidence, effectiveDateCertain: effective.certain, changes, config });
  const fp = fingerprint({ platform_id: source.platform_id, tariff_version_id: source.tariff_version_id,
    effective_from: effective.date, changes });
  const { inserted, candidate } = await repo.insertCandidate({
    platform_id: source.platform_id, tariff_version_id: source.tariff_version_id, fingerprint: fp, status: policy.status,
    changes, effective_from: effective.date, effective_date_certain: effective.certain, source_ids: [source.source_id],
    source_types: [source.source_type], ocr_confidence: extracted.confidence, requires_human: policy.requiresHuman,
    reasons: policy.reasons, verification: policy.verification,
    note: `${version?.platform_id ?? source.platform_id}: ${changes.length} kalem degisikligi (${source.source_id})`,
  });
  for (const other of conflicting) await repo.flagConflict(other.candidate_id);

  if (!inserted) {
    await repo.addSourceToCandidate(candidate.candidate_id, source.source_id, source.source_type);
    return finish({ result: 'changed', http_status: page.status, content_hash: hash, extracted, ocr_confidence: extracted.confidence,
      candidate_id: candidate.candidate_id, note: 'Ayni degisiklik zaten aday; yeni aday olusturulmadi.' }, true, hash);
  }

  let note = policy.reasons.length ? `Insan onayi gerekli: ${policy.reasons.join('; ')}` : 'Otomatik yayima uygun';
  if (policy.autoPublish) {
    const published = await repo.publish(candidate.candidate_id, actor);
    note = `Tek guvenilir resmi kaynak; otomatik yayimlandi (${published.status}).`;
  }
  const result = extracted.confidence < (config.min_ocr_confidence ?? 0.9) ? 'needs_verification' : 'new_candidate';
  return { ...(await finish({ result, http_status: page.status, content_hash: hash, extracted, ocr_confidence: extracted.confidence,
    candidate_id: candidate.candidate_id, note }, true, hash)), changes };
}

/** Ayni ana bilgisayara istekler arasinda bekleme (hiz siniri). */
export function createThrottle(delayMs, sleep = (ms) => new Promise((r) => setTimeout(r, ms))) {
  const last = new Map();
  return async (url) => {
    let host = '';
    try { host = new URL(url).host; } catch { return; }
    const prev = last.get(host);
    const now = Date.now();
    if (prev !== undefined && now - prev < delayMs) await sleep(delayMs - (now - prev));
    last.set(host, Date.now());
  };
}
