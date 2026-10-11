// Tarife tablolarina SQL erisimi. `sql(query) -> rows` ile calisir: canlida Management API (lib.mjs),
// testlerde PGlite. Degerler q()/j() ile tirnaklanir (Management API parametre baglama desteklemez).
export const q = (v) => (v === null || v === undefined ? 'null' : `'${String(v).replace(/'/g, "''")}'`);
export const j = (v) => `${q(JSON.stringify(v ?? null))}::jsonb`;
export const arr = (list) => `array[${(list ?? []).map(q).join(',')}]::text[]`;
const num = (v) => (v === null || v === undefined || v === '' ? 'null' : Number(v));

export function createRepo(sql) {
  return {
    sql,

    async config() {
      const rows = await sql('select key, value from public.tariff_config');
      const out = {};
      for (const r of rows) out[r.key] = typeof r.value === 'string' ? JSON.parse(r.value) : r.value;
      return out;
    },

    async sources({ platform, sourceId, onlyActive = true } = {}) {
      const where = [];
      if (onlyActive) where.push('active');
      if (platform) where.push(`platform_id = ${q(platform)}`);
      if (sourceId) where.push(`source_id = ${q(sourceId)}`);
      return sql(`select * from public.tariff_sources ${where.length ? `where ${where.join(' and ')}` : ''} order by platform_id, priority, source_id`);
    },

    /** Kaynagi kontrol icin kilitler; baska calisma kilitliyse false (eszamanli kontrol tutarliligi). */
    async lockSource(sourceId, minutes = 10) {
      const rows = await sql(`update public.tariff_sources set lock_until = now() + interval '${Number(minutes)} minutes'
        where source_id = ${q(sourceId)} and (lock_until is null or lock_until < now()) returning source_id`);
      return rows.length === 1;
    },

    async unlockSource(sourceId) {
      await sql(`update public.tariff_sources set lock_until = null where source_id = ${q(sourceId)}`);
    },

    async markChecked(sourceId, { success, hash }) {
      await sql(`update public.tariff_sources set last_checked_at = now()
        ${success ? ', last_success_at = now()' : ''}${hash ? `, content_hash = ${q(hash)}` : ''}
        where source_id = ${q(sourceId)}`);
    },

    async recordCheck(c) {
      const rows = await sql(`insert into public.tariff_source_checks (source_id, result, http_status, content_hash, previous_hash,
          extracted, ocr_confidence, candidate_id, note, run_id)
        values (${q(c.source_id)}, ${q(c.result)}, ${num(c.http_status)}, ${q(c.content_hash)}, ${q(c.previous_hash)},
          ${c.extracted ? j(c.extracted) : 'null'}, ${num(c.ocr_confidence)}, ${q(c.candidate_id)}, ${q(c.note)}, ${q(c.run_id)})
        returning check_id`);
      return rows[0]?.check_id;
    },

    /** Surumun verilen gunde gecerli (geri cekilmemis) kalemleri. */
    async activeItems(versionId, day) {
      return sql(`select item_key, label, amount, amount_upper, lower_threshold, upper_threshold, item_type, unit,
          calculation_method, effective_from, effective_until
        from public.tariff_items where tariff_version_id = ${q(versionId)} and not withdrawn
          and (effective_from is null or effective_from <= ${q(day)}::date)
          and (effective_until is null or effective_until > ${q(day)}::date)
        order by item_key`);
    },

    async version(versionId) {
      return (await sql(`select * from public.tariff_versions where tariff_version_id = ${q(versionId)}`))[0] ?? null;
    },

    /** Celiski kontrolu icin: acik adaylar + son 30 gunde yayimlananlar. */
    async recentCandidates(versionId) {
      return sql(`select * from public.tariff_candidates where tariff_version_id = ${q(versionId)}
        and (status in ('draft','pending_verification','needs_more_sources','approved')
             or (status = 'published' and published_at > now() - interval '30 days'))
        order by created_at`);
    },

    async openCandidates(versionId) {
      return sql(`select * from public.tariff_candidates where tariff_version_id = ${q(versionId)}
        and status in ('draft','pending_verification','needs_more_sources','approved') order by created_at`);
    },

    /** Ayni parmak izi varsa eklemez (idempotent). Donus: {inserted, candidate}. */
    async insertCandidate(c) {
      const rows = await sql(`insert into public.tariff_candidates (candidate_id, platform_id, tariff_version_id, fingerprint, status,
          changes, effective_from, effective_date_certain, source_ids, source_types, ocr_confidence, requires_human, reasons,
          verification, note)
        values (coalesce(${q(c.candidate_id)}, gen_random_uuid()::text), ${q(c.platform_id)}, ${q(c.tariff_version_id)},
          ${q(c.fingerprint)}, ${q(c.status)}, ${j(c.changes)}, ${c.effective_from ? `${q(c.effective_from)}::date` : 'null'},
          ${c.effective_date_certain ? 'true' : 'false'}, ${arr(c.source_ids)}, ${arr(c.source_types)}, ${num(c.ocr_confidence)},
          ${c.requires_human ? 'true' : 'false'}, ${arr(c.reasons)}, ${q(c.verification ?? 'needs_verification')}, ${q(c.note)})
        on conflict (fingerprint) do nothing
        returning *`);
      if (rows.length === 1) return { inserted: true, candidate: rows[0] };
      const existing = (await sql(`select * from public.tariff_candidates where fingerprint = ${q(c.fingerprint)}`))[0];
      return { inserted: false, candidate: existing };
    },

    /** Ayni degisikligi bildiren yeni bagimsiz kaynak: kaynak listesine eklenir; yeterli kaynak olunca dogrulamaya gecer. */
    async addSourceToCandidate(candidateId, sourceId, sourceType) {
      const rows = await sql(`update public.tariff_candidates
          set source_ids = case when ${q(sourceId)} = any(source_ids) then source_ids else array_append(source_ids, ${q(sourceId)}) end,
              source_types = case when ${q(sourceId)} = any(source_ids) then source_types else array_append(source_types, ${q(sourceType)}) end,
              status = case when status = 'needs_more_sources' and cardinality(source_ids) + 1 >= 2
                            and not (${q(sourceId)} = any(source_ids)) then 'pending_verification' else status end
        where candidate_id = ${q(candidateId)} returning *`);
      return rows[0];
    },

    async flagConflict(candidateId) {
      await sql(`update public.tariff_candidates
          set reasons = case when 'Çelişen kaynaklar' = any(reasons) then reasons else array_append(reasons, 'Çelişen kaynaklar') end,
              requires_human = true,
              status = case when status = 'approved' then 'pending_verification' else status end
        where candidate_id = ${q(candidateId)} and status in ('draft','pending_verification','needs_more_sources','approved')`);
    },

    async decide(candidateId, status, actor, note, effectiveFrom) {
      const rows = await sql(`select public.decide_tariff_candidate(${q(candidateId)}, ${q(status)}, ${q(actor)}, ${q(note)},
        ${effectiveFrom ? `${q(effectiveFrom)}::date` : 'null'}) as r`);
      return rows[0].r;
    },

    async publish(candidateId, actor) {
      const rows = await sql(`select public.publish_tariff_candidate(${q(candidateId)}, ${q(actor)}) as r`);
      return rows[0].r;
    },

    async withdrawCandidate(candidateId, actor, reason) {
      const rows = await sql(`select public.withdraw_tariff_candidate(${q(candidateId)}, ${q(actor)}, ${q(reason)}) as r`);
      return rows[0].r;
    },

    async withdrawVersion(versionId, actor, reason) {
      const rows = await sql(`select public.withdraw_tariff_version(${q(versionId)}, ${q(actor)}, ${q(reason)}) as r`);
      return rows[0].r;
    },

    async audit(actor, action, entity, entityId, before, after, note) {
      await sql(`insert into public.tariff_audit_log (actor, action, entity, entity_id, before, after, note)
        values (${q(actor)}, ${q(action)}, ${q(entity)}, ${q(entityId)}, ${before ? j(before) : 'null'}, ${after ? j(after) : 'null'}, ${q(note)})`);
    },

    async markPlatformChecked(platformId, success) {
      await sql(`update public.tariff_platforms p set
          ${success ? 'last_successful_check_at = now(),' : ''}
          next_scheduled_check_at = (select min(coalesce(s.last_checked_at, now()) + make_interval(mins => s.check_interval_minutes))
            from public.tariff_sources s where s.platform_id = p.platform_id and s.active)
        where platform_id = ${q(platformId)}`);
    },

    /** Uzun suredir karar bekleyen adaylar suresi dolmus sayilir. */
    async expireStaleCandidates(days) {
      return sql(`update public.tariff_candidates set status = 'expired'
        where status in ('pending_verification','needs_more_sources') and created_at < now() - make_interval(days => ${Number(days)})
        returning candidate_id`);
    },
  };
}
