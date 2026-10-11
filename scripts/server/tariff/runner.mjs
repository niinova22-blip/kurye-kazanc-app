// Zamanlanmis kontrol: zamani gelen kaynaklari sirayla (ana bilgisayar basina bekleyerek) kontrol eder,
// ardindan gunluk bakim: suresi dolan adaylar ve yaklasan yururluk tarihleri. Tekrar calistirilabilir.
import { randomUUID } from 'node:crypto';
import { checkSource, createThrottle, defaultFetch, defaultRobots } from './checker.mjs';
import { isDue, upcoming } from './core.mjs';

export async function runChecks({ repo, now = new Date(), force = false, platform, sourceId, fetchPage = defaultFetch,
  fetchRobots = defaultRobots, throttle, log = () => {} }) {
  const config = await repo.config();
  const today = now.toISOString().slice(0, 10);
  const runId = randomUUID();
  const wait = throttle ?? createThrottle(Number(config.per_host_delay_ms ?? 5000));
  const sources = await repo.sources({ platform, sourceId });
  const results = [];
  for (const source of sources) {
    if (!force && !isDue(source, now)) continue;
    if (!(await repo.lockSource(source.source_id))) {
      log(`atlandi (baska calisma kontrol ediyor): ${source.source_id}`);
      results.push({ source_id: source.source_id, result: 'skipped_locked' });
      continue;
    }
    try {
      if (source.url) await wait(source.url);
      const outcome = await checkSource({ source, repo, config, fetchPage, fetchRobots, today, runId });
      log(`${outcome.result.padEnd(18)} ${source.source_id}${outcome.note ? ` — ${outcome.note}` : ''}`);
      results.push({ source_id: source.source_id, ...outcome });
    } catch (err) {
      // Beklenmeyen hata: kaynak sonucu kaydedilir, tarife tablolarina dokunulmaz
      log(`hata ${source.source_id}: ${err}`);
      await repo.recordCheck({ source_id: source.source_id, result: 'unreachable', note: String(err).slice(0, 300), run_id: runId });
      results.push({ source_id: source.source_id, result: 'unreachable', note: String(err) });
    } finally {
      await repo.unlockSource(source.source_id);
    }
  }
  return { runId, results };
}

export async function dailyMaintenance({ repo, now = new Date(), log = () => {} }) {
  const config = await repo.config();
  const expired = await repo.expireStaleCandidates(Number(config.candidate_expiry_days ?? 60));
  for (const row of expired) {
    await repo.audit('tarife-kontrol (otomatik)', 'candidate_expired', 'tariff_candidate', row.candidate_id, null, null,
      'Karar verilmeden suresi doldu');
  }
  const today = now.toISOString().slice(0, 10);
  const candidates = await repo.sql(`select candidate_id, platform_id, status, effective_from from public.tariff_candidates
    where status in ('approved','published','pending_verification','needs_more_sources') and effective_from is not null`);
  const items = await repo.sql(`select i.tariff_item_id, v.platform_id, i.item_key, i.effective_from from public.tariff_items i
    join public.tariff_versions v using (tariff_version_id) where not i.withdrawn and i.effective_from is not null`);
  const soon = [...upcoming(candidates, today), ...upcoming(items, today)];
  for (const s of soon) log(`yaklasan yururluk: ${s.platform_id} ${String(s.effective_from).slice(0, 10)} ${s.candidate_id ?? s.item_key}`);
  return { expired: expired.map((r) => r.candidate_id), upcoming: soon };
}
