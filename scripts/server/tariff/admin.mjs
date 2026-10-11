// Tarife Merkezi islemleri (HTTP'den bagimsiz; tariff_center.mjs bunlari sunar, testler dogrudan cagirir).
// Finansal hesaplamayi etkileyen her islem kim/ne zaman bilgisiyle tariff_audit_log'a yazilir.
import { evaluatePolicy, fingerprint } from './core.mjs';
import { arr, j, q } from './repo.mjs';
import { runChecks } from './runner.mjs';

function requireActor(actor) {
  if (!actor || !String(actor).trim()) throw new Error('Yonetici adi gerekli (denetim kaydi)');
}

const parse = (v) => (typeof v === 'string' ? JSON.parse(v) : v);

export function createAdmin(repo, { checkOptions = {} } = {}) {
  const { sql } = repo;
  return {
    async overview() {
      const platforms = await sql('select * from public.tariff_platforms order by platform_id');
      const out = [];
      for (const p of platforms) {
        const versions = await sql(`select tariff_version_id, version_number, revision, vehicle_type, region_id, effective_from,
            verification_status, approval_status, change_summary
          from public.tariff_versions where platform_id = ${q(p.platform_id)} and approval_status = 'published'
          order by tariff_version_id`);
        const pending = await sql(`select status, count(*)::int as n from public.tariff_candidates
          where platform_id = ${q(p.platform_id)} and status in ('draft','pending_verification','needs_more_sources','approved')
          group by status`);
        const sources = await sql(`select s.source_id, s.url, s.source_type, s.last_checked_at, s.last_success_at,
            (select c.result from public.tariff_source_checks c where c.source_id = s.source_id order by c.checked_at desc limit 1) as last_result
          from public.tariff_sources s where s.platform_id = ${q(p.platform_id)} order by s.priority`);
        const lastUpdate = (await sql(`select max(a.at) as at from public.tariff_audit_log a
          where a.action in ('publish','withdraw','withdraw_version','seed')`))[0]?.at ?? null;
        const upcoming = await sql(`select candidate_id, status, effective_from from public.tariff_candidates
          where platform_id = ${q(p.platform_id)} and effective_from >= current_date
            and status in ('approved','published','pending_verification','needs_more_sources') order by effective_from limit 10`);
        out.push({ ...p, versions, pending, sources, last_update: lastUpdate, upcoming });
      }
      return out;
    },

    async candidates({ platform, status } = {}) {
      const where = [];
      if (platform) where.push(`platform_id = ${q(platform)}`);
      if (status) where.push(`status = ${q(status)}`);
      return sql(`select candidate_id, platform_id, tariff_version_id, status, effective_from, effective_date_certain, reasons,
          source_ids, ocr_confidence, verification, created_at, decided_by, decided_at, published_at, note
        from public.tariff_candidates ${where.length ? `where ${where.join(' and ')}` : ''} order by created_at desc limit 200`);
    },

    /** Aday + eski/yeni karsilastirma + kaynak belgeleri + kontrol gecmisi. */
    async candidate(id) {
      const c = (await sql(`select * from public.tariff_candidates where candidate_id = ${q(id)}`))[0];
      if (!c) throw new Error('aday yok');
      const day = c.effective_from ? String(c.effective_from).slice(0, 10) : new Date().toISOString().slice(0, 10);
      const active = await repo.activeItems(c.tariff_version_id, day);
      const sources = await sql(`select source_id, url, document_ref, source_type, reliability, summary
        from public.tariff_sources where source_id = any(${arr(c.source_ids)})`);
      const checks = await sql(`select * from public.tariff_source_checks where candidate_id = ${q(id)} order by checked_at desc`);
      return { candidate: { ...c, changes: parse(c.changes) }, active, sources, checks };
    },

    async decide(id, status, actor, { note, effectiveFrom } = {}) {
      requireActor(actor);
      return repo.decide(id, status, actor, note, effectiveFrom);
    },

    /** Eksik bilgi duzenleme (yururluk tarihi, degerler, not). Yayimlanmis / kapanmis aday duzenlenmez. */
    async edit(id, actor, { changes, effectiveFrom, note }) {
      requireActor(actor);
      const c = (await sql(`select * from public.tariff_candidates where candidate_id = ${q(id)}`))[0];
      if (!c) throw new Error('aday yok');
      if (!['draft', 'pending_verification', 'needs_more_sources'].includes(c.status)) {
        throw new Error(`bu durumdaki aday duzenlenemez: ${c.status}`);
      }
      const nextChanges = changes ?? parse(c.changes);
      const nextDate = effectiveFrom ?? (c.effective_from ? String(c.effective_from).slice(0, 10) : null);
      const fp = fingerprint({ platform_id: c.platform_id, tariff_version_id: c.tariff_version_id, effective_from: nextDate,
        changes: nextChanges });
      await sql(`update public.tariff_candidates set changes = ${j(nextChanges)}, fingerprint = ${q(fp)},
          effective_from = ${nextDate ? `${q(nextDate)}::date` : 'null'},
          effective_date_certain = ${effectiveFrom ? 'true' : c.effective_date_certain ? 'true' : 'false'},
          note = coalesce(${q(note)}, note)
        where candidate_id = ${q(id)}`);
      await repo.audit(actor, 'candidate_edit', 'tariff_candidate', id,
        { changes: parse(c.changes), effective_from: c.effective_from }, { changes: nextChanges, effective_from: nextDate }, note);
      return { candidate_id: id, fingerprint: fp };
    },

    async publish(id, actor) {
      requireActor(actor);
      return repo.publish(id, actor);
    },

    async withdrawCandidate(id, actor, reason) {
      requireActor(actor);
      return repo.withdrawCandidate(id, actor, reason);
    },

    async withdrawVersion(id, actor, reason) {
      requireActor(actor);
      return repo.withdrawVersion(id, actor, reason);
    },

    /**
     * Elle aday (form, yuklenen belge/gorsel, CSV). Kaynak zorunlu; her zaman insan onayina duser.
     * OCR ile okunmussa `ocrConfidence` verilir ve dusukse gerekce eklenir.
     */
    async createManual(actor, { platform, versionId, changes, effectiveFrom, sourceType = 'user_upload', sourceRef, note,
      ocrConfidence }) {
      requireActor(actor);
      if (!sourceRef || !String(sourceRef).trim()) throw new Error('Kaynak belirtilmeli (URL ya da belge referansi)');
      if (!Array.isArray(changes) || changes.length === 0) throw new Error('En az bir kalem degisikligi gerekli');
      const config = await repo.config();
      const policy = evaluatePolicy({ sourceTypes: [sourceType], sourceCount: 1, ocrConfidence: ocrConfidence ?? 1,
        effectiveDateCertain: Boolean(effectiveFrom), changes, config: { ...config, auto_publish_official: false } });
      const sourceId = `manual-${Date.now()}`;
      await sql(`insert into public.tariff_sources (source_id, platform_id, tariff_version_id, url, document_ref, source_type, priority,
          active, summary, reliability)
        values (${q(sourceId)}, ${q(platform)}, ${q(versionId)}, ${/^https?:/.test(sourceRef) ? q(sourceRef) : 'null'},
          ${/^https?:/.test(sourceRef) ? 'null' : q(sourceRef)}, ${q(sourceType)}, ${sourceType === 'user_upload' ? 5 : 4}, false,
          ${q(note ?? 'Elle eklenen kaynak')}, 'unknown')`);
      const fp = fingerprint({ platform_id: platform, tariff_version_id: versionId, effective_from: effectiveFrom, changes });
      const { inserted, candidate } = await repo.insertCandidate({
        platform_id: platform, tariff_version_id: versionId, fingerprint: fp,
        status: policy.status === 'approved' ? 'pending_verification' : policy.status, changes, effective_from: effectiveFrom,
        effective_date_certain: Boolean(effectiveFrom), source_ids: [sourceId], source_types: [sourceType],
        ocr_confidence: ocrConfidence ?? null, requires_human: true, reasons: policy.reasons, verification: 'needs_verification', note,
      });
      await repo.audit(actor, 'candidate_create', 'tariff_candidate', candidate.candidate_id, null, { changes, effectiveFrom }, note);
      return { inserted, candidate_id: candidate.candidate_id, status: candidate.status, reasons: policy.reasons };
    },

    async versions(platform) {
      const versions = await sql(`select * from public.tariff_versions ${platform ? `where platform_id = ${q(platform)}` : ''}
        order by platform_id, version_number desc, tariff_version_id`);
      const items = await sql(`select * from public.tariff_items ${platform ? `where tariff_version_id in
        (select tariff_version_id from public.tariff_versions where platform_id = ${q(platform)})` : ''}
        order by tariff_version_id, item_key, effective_from nulls first`);
      return versions.map((v) => ({ ...v, items: items.filter((i) => i.tariff_version_id === v.tariff_version_id) }));
    },

    async auditLog(limit = 100) {
      return sql(`select * from public.tariff_audit_log order by at desc, audit_id desc limit ${Number(limit)}`);
    },

    async checks(limit = 100) {
      return sql(`select c.*, s.platform_id, s.url from public.tariff_source_checks c join public.tariff_sources s using (source_id)
        order by c.checked_at desc limit ${Number(limit)}`);
    },

    /** Manuel kontrol baslatma. */
    async runCheck(actor, { sourceId, platform } = {}) {
      requireActor(actor);
      const out = await runChecks({ repo, force: true, sourceId, platform, ...checkOptions });
      await repo.audit(actor, 'manual_check', 'tariff_source', sourceId ?? platform ?? 'all', null,
        { results: out.results.map((r) => ({ source_id: r.source_id, result: r.result })) }, null);
      return out;
    },
  };
}
