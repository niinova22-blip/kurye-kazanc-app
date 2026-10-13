// Dinamik tarife sistemi uctan uca: gercek Postgres (PGlite) + goc + sahte web kaynaklari.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createAdmin } from '../admin.mjs';
import { dailyMaintenance, runChecks } from '../runner.mjs';
import { asRole, configureSource, fakeWeb, freshDb, noWait, PT_PROFILE, ptPage } from './helpers.mjs';

const PT = 'pakettaxi-migros-ucret';
const PT_URL = 'https://www.pakettaxi.com/migros-kurye-nasil-olunur-guncel-migros-kurye-ucretleri-nedir/';
const PT_VERSION = 'migros_hemen-esnaf-v1';

async function check(repo, web, opts = {}) {
  return runChecks({ repo, force: true, sourceId: PT, fetchPage: web.fetchPage, fetchRobots: web.fetchRobots, throttle: noWait,
    now: new Date('2026-10-11T08:00:00Z'), ...opts });
}

const candidates = (sql) => sql(`select * from public.tariff_candidates order by created_at`);
const ptItem = async (repo, key, day) => (await repo.activeItems(PT_VERSION, day)).find((i) => i.item_key === key);

test('RLS: istemci yalnizca yayindaki tarifeyi okur, yazamaz, yonetim fonksiyonlarini calistiramaz', async () => {
  const { db } = await freshDb();
  assert.equal((await asRole(db, 'anon', 'select count(*)::int n from public.tariff_versions'))[0].n, 7);
  for (const table of ['tariff_candidates', 'tariff_sources', 'tariff_audit_log', 'tariff_source_checks', 'tariff_config']) {
    await assert.rejects(asRole(db, 'anon', `select * from public.${table}`), /permission denied/, table);
  }
  await assert.rejects(asRole(db, 'authenticated', `update public.tariff_items set amount = 1`), /permission denied/);
  await assert.rejects(asRole(db, 'anon', `select public.publish_tariff_candidate('x', 'y')`), /permission denied/);
  // Taslak surum istemciye gorunmez
  await db.query(`insert into public.tariff_versions (tariff_version_id, platform_id, version_number, effective_from, source_type,
    verification_status, approval_status) values ('draft-v', 'getir', 9, '2026-12-01', 'news', 'unverified', 'draft')`);
  assert.equal((await asRole(db, 'anon', `select count(*)::int n from public.tariff_versions where tariff_version_id = 'draft-v'`))[0].n, 0);
});

test('kaynak degismediginde yeni tarife olusmaz', async () => {
  const { sql, repo } = await freshDb();
  await configureSource(sql, PT, { profile: PT_PROFILE });
  const web = fakeWeb({ [PT_URL]: ptPage() });
  const first = await check(repo, web);
  assert.equal(first.results[0].result, 'unchanged', 'ucretler tarifedekiyle ayni');
  const second = await check(repo, web);
  assert.equal(second.results[0].result, 'unchanged');
  assert.equal((await candidates(sql)).length, 0);
});

test('yalnizca baslik / tasarim degisince ucret degisti sayilmaz', async () => {
  const { sql, repo } = await freshDb();
  await configureSource(sql, PT, { profile: PT_PROFILE });
  const web = fakeWeb({ [PT_URL]: ptPage() });
  await check(repo, web);
  web.pages[PT_URL] = ptPage({ title: 'YENİ! Migros Kurye Olmak 2026', extra: '<div class="banner">Hemen başvur</div>' });
  const out = await check(repo, web);
  assert.equal(out.results[0].result, 'unchanged');
  assert.match(out.results[0].note, /ücret alanları aynı|ucret alanlari ayni/i);
  assert.equal((await candidates(sql)).length, 0);
});

test('profil yoksa sayfa degisimi yalnizca dogrulama gerekli olarak isaretlenir', async () => {
  const { sql, repo } = await freshDb();
  const web = fakeWeb({ [PT_URL]: ptPage() });
  assert.equal((await check(repo, web)).results[0].result, 'unchanged');
  web.pages[PT_URL] = ptPage({ base: '41' });
  assert.equal((await check(repo, web)).results[0].result, 'needs_verification');
  assert.equal((await candidates(sql)).length, 0, 'profil olmadan aday olusmaz');
});

test('degisiklik dogru algilanir, ayni degisiklik iki kez aday olmaz', async () => {
  const { sql, repo } = await freshDb();
  await configureSource(sql, PT, { profile: PT_PROFILE });
  const web = fakeWeb({ [PT_URL]: ptPage({ tier: '41', extra: '<p>1 Kasım 2026 itibarıyla geçerlidir.</p>' }) });
  const out = await check(repo, web);
  assert.equal(out.results[0].result, 'new_candidate');
  const [c] = await candidates(sql);
  assert.equal(c.status, 'pending_verification', 'ayar kapali: insan onayi');
  assert.equal(c.effective_from, '2026-11-01');
  assert.equal(c.changes.length, 1);
  assert.deepEqual(c.changes[0], { kind: 'changed', item_key: 'package.performance.1100', label: 'Paket başı 1.100+',
    old_amount: 40, new_amount: 41, abs: 1, pct: 2.5 });
  // Ayni sayfa yeniden (ozet degismedi) ve ayni degisiklik baska kaynaktan: tek aday
  assert.equal((await check(repo, web)).results[0].result, 'unchanged');
  await sql(`update public.tariff_sources set content_hash = null where source_id = '${PT}'`);
  assert.equal((await check(repo, web)).results[0].result, 'changed');
  assert.equal((await candidates(sql)).length, 1);
  // Aktif tarife degismedi
  assert.equal(Number((await ptItem(repo, 'package.performance.1100', '2026-11-05')).amount), 40);
});

test('tek ikincil kaynak ek kaynak ister; ikinci bagimsiz kaynak dogrulamaya tasir', async () => {
  const { sql, repo } = await freshDb();
  await configureSource(sql, PT, { type: 'news', profile: PT_PROFILE });
  await sql(`insert into public.tariff_sources (source_id, platform_id, tariff_version_id, url, source_type, priority, extraction_profile)
    values ('second', 'migros_hemen', '${PT_VERSION}', 'https://haber.example/pt', 'news', 4, '${JSON.stringify(PT_PROFILE)}'::jsonb)`);
  const page = ptPage({ tier: '41', extra: '<p>1 Kasım 2026 itibarıyla</p>' });
  const web = fakeWeb({ [PT_URL]: page, 'https://haber.example/pt': page });
  await check(repo, web);
  let [c] = await candidates(sql);
  assert.equal(c.status, 'needs_more_sources');
  assert.ok(c.reasons.includes('Tek ikincil kaynak'));
  await runChecks({ repo, force: true, sourceId: 'second', fetchPage: web.fetchPage, fetchRobots: web.fetchRobots, throttle: noWait });
  [c] = await candidates(sql);
  assert.equal((await candidates(sql)).length, 1);
  assert.deepEqual(c.source_ids, [PT, 'second']);
  assert.equal(c.status, 'pending_verification');
});

test('celisen kaynaklar insan onayina duser', async () => {
  const { sql, repo } = await freshDb({ autoPublish: true });
  await configureSource(sql, PT, { profile: PT_PROFILE });
  await sql(`insert into public.tariff_sources (source_id, platform_id, tariff_version_id, url, source_type, priority, extraction_profile)
    values ('other', 'migros_hemen', '${PT_VERSION}', 'https://pt.example/2', 'official_document', 3, '${JSON.stringify(PT_PROFILE)}'::jsonb)`);
  const web = fakeWeb({
    [PT_URL]: ptPage({ tier: '41', extra: '<p>1 Kasım 2026 itibarıyla</p>' }),
    'https://pt.example/2': ptPage({ tier: '43', extra: '<p>1 Kasım 2026 itibarıyla</p>' }),
  });
  // Ilk kaynak tek basina otomatik yayima uygun olurdu; once ikinciyi kontrol edip celiski yaratalim
  await runChecks({ repo, force: true, sourceId: 'other', fetchPage: web.fetchPage, fetchRobots: web.fetchRobots, throttle: noWait });
  const out = await check(repo, web);
  const all = await candidates(sql);
  assert.equal(all.length, 2);
  // Ilk aday otomatik yayimlanmis olabilir; ikinci (celisen) aday kesinlikle insan onayinda
  const conflicted = all.find((c) => c.candidate_id === out.results[0].candidate_id);
  assert.equal(conflicted.status, 'pending_verification');
  assert.ok(conflicted.reasons.includes('Çelişen kaynaklar'));
});

test('kaynak hatasinda eski tarife korunur ve sonuc kaydedilir', async () => {
  const { sql, repo } = await freshDb();
  await configureSource(sql, PT, { profile: PT_PROFILE });
  const web = fakeWeb({ [PT_URL]: ptPage() });
  await check(repo, web);
  const before = await sql(`select * from public.tariff_items where tariff_version_id = '${PT_VERSION}' order by tariff_item_id`);
  const hash = (await sql(`select content_hash from public.tariff_sources where source_id = '${PT}'`))[0].content_hash;
  web.pages[PT_URL] = { status: 503, ok: false, text: '' };
  assert.equal((await check(repo, web)).results[0].result, 'unreachable');
  web.pages[PT_URL] = new Error('ECONNRESET');
  assert.equal((await check(repo, web)).results[0].result, 'unreachable');
  const after = await sql(`select * from public.tariff_items where tariff_version_id = '${PT_VERSION}' order by tariff_item_id`);
  assert.deepEqual(after, before);
  assert.equal((await sql(`select content_hash from public.tariff_sources where source_id = '${PT}'`))[0].content_hash, hash);
  const results = (await sql(`select result from public.tariff_source_checks where source_id = '${PT}' order by check_id`)).map((r) => r.result);
  assert.deepEqual(results, ['unchanged', 'unreachable', 'unreachable']);
  const platform = (await sql(`select last_successful_check_at from public.tariff_platforms where platform_id = 'migros_hemen'`))[0];
  assert.ok(platform.last_successful_check_at, 'son basarili kontrol ilk kontrolde kaldi');
});

test('robots.txt izin vermezse sayfa indirilmez', async () => {
  const { sql, repo } = await freshDb();
  const web = fakeWeb({ [PT_URL]: ptPage() });
  web.fetchRobots = async () => 'User-agent: *\nDisallow: /migros';
  const out = await check(repo, web);
  assert.equal(out.results[0].result, 'unreachable');
  assert.equal(web.calls.length, 0);
  assert.equal((await candidates(sql)).length, 0);
});

test('dusuk OCR / cikarim guveni otomatik yayimlanmaz', async () => {
  const { sql, repo } = await freshDb({ autoPublish: true });
  await configureSource(sql, PT, { profile: [...PT_PROFILE, { item_key: 'fixed.region.plus', pattern: 'plus ücret:\\s*([\\d.,]+)' }] });
  const web = fakeWeb({ [PT_URL]: ptPage({ tier: '41', extra: '<p>1 Kasım 2026 itibarıyla</p>' }) });
  const out = await check(repo, web);
  assert.equal(out.results[0].result, 'needs_verification');
  const [c] = await candidates(sql);
  assert.equal(c.status, 'pending_verification');
  assert.ok(c.reasons.includes('Düşük OCR / metin çıkarım güveni'));
  assert.equal((await sql(`select count(*)::int n from public.tariff_change_events`))[0].n, 0);
});

test('tek guvenilir resmi kaynak ayar aciksa otomatik yayimlanir; ileri tarihli kalem erken uygulanmaz', async () => {
  const { sql, repo } = await freshDb({ autoPublish: true });
  await configureSource(sql, PT, { profile: PT_PROFILE });
  const web = fakeWeb({ [PT_URL]: ptPage({ tier: '41', extra: '<p>1 Kasım 2026 itibarıyla geçerli</p>' }) });
  const out = await check(repo, web);
  assert.match(out.results[0].note, /otomatik yayimlandi/);
  const [c] = await candidates(sql);
  assert.equal(c.status, 'published');
  assert.equal(c.verification, 'verified');
  assert.equal(Number((await ptItem(repo, 'package.performance.1100', '2026-10-31')).amount), 40, 'yururlukten once eski');
  assert.equal(Number((await ptItem(repo, 'package.performance.1100', '2026-11-01')).amount), 41, 'yururlukte yeni');
  const events = await sql(`select * from public.tariff_change_events`);
  assert.equal(events.length, 1);
  assert.equal(events[0].verification, 'verified');
  assert.equal(events[0].effective_from, '2026-11-01');
  const audit = await sql(`select actor, action from public.tariff_audit_log where action = 'publish'`);
  assert.deepEqual(audit, [{ actor: 'tarife-kontrol (otomatik)', action: 'publish' }]);
});

test('onaysiz aday yayimlanamaz; yayim idempotent; geri cekilebilir', async () => {
  const { sql, repo } = await freshDb();
  const admin = createAdmin(repo);
  await configureSource(sql, PT, { profile: PT_PROFILE });
  const web = fakeWeb({ [PT_URL]: ptPage({ tier: '41' }) });
  await check(repo, web);
  const [c] = await candidates(sql);
  assert.equal(c.effective_from, null, 'tarih belirsiz');
  await assert.rejects(admin.publish(c.candidate_id, 'yonetici'), /onaylanmamis/);
  await assert.rejects(admin.decide(c.candidate_id, 'approved', 'yonetici'), /yururluk tarihi/);
  await assert.rejects(admin.decide(c.candidate_id, 'approved', ''), /Yonetici adi/);
  await admin.decide(c.candidate_id, 'approved', 'ayse', { effectiveFrom: '2026-11-01', note: 'Resmi duyuru teyit' });
  const first = await admin.publish(c.candidate_id, 'ayse');
  assert.equal(first.status, 'published');
  const again = await admin.publish(c.candidate_id, 'ayse');
  assert.equal(again.status, 'already_published');
  assert.equal((await sql(`select revision from public.tariff_versions where tariff_version_id = '${PT_VERSION}'`))[0].revision, 1);
  assert.equal((await sql(`select count(*)::int n from public.tariff_change_events`))[0].n, 1);
  assert.equal((await sql(`select count(*)::int n from public.tariff_items where item_key = 'package.performance.1100'`))[0].n, 2);

  // Gecmis kayitlar (uygulamada) dondurulmus sonucu korur; sunucuda geri cekme onceki gecerliligi geri yukler
  await assert.rejects(admin.withdrawCandidate(c.candidate_id, 'ayse', ''), /neden/);
  await admin.withdrawCandidate(c.candidate_id, 'ayse', 'Kaynak yanlis anlasildi');
  assert.equal(Number((await ptItem(repo, 'package.performance.1100', '2026-11-05')).amount), 40);
  const kinds = (await sql(`select kind from public.tariff_change_events order by event_id`)).map((e) => e.kind);
  assert.deepEqual(kinds, ['published', 'withdrawn']);
  const actions = (await sql(`select actor, action from public.tariff_audit_log where actor = 'ayse' order by audit_id`));
  assert.deepEqual(actions.map((a) => a.action), ['candidate_approved', 'publish', 'withdraw']);
});

test('gecersiz durum gecisi veritabaninda reddedilir', async () => {
  const { sql, repo } = await freshDb();
  const admin = createAdmin(repo);
  const created = await admin.createManual('ayse', { platform: 'getir', versionId: 'getir-esnaf-motorcycle-v1',
    changes: [{ kind: 'changed', item_key: 'hourly', label: 'Saatlik', old_amount: 50, new_amount: 55, abs: 5, pct: 10 }],
    effectiveFrom: '2026-11-01', sourceRef: 'Kurye sözleşmesi ek protokol, Ekim 2026', note: 'Elle' });
  await admin.decide(created.candidate_id, 'rejected', 'ayse', { note: 'Belge eski' });
  await assert.rejects(sql(`update public.tariff_candidates set status = 'approved' where candidate_id = '${created.candidate_id}'`),
    /gecersiz aday durum gecisi/);
});

test('yeni tarife yalnizca ilgili platform / surume uygulanir; dort platform bagimsiz', async () => {
  const { sql, repo } = await freshDb();
  const admin = createAdmin(repo);
  const before = await sql(`select tariff_version_id, revision from public.tariff_versions order by 1`);
  const itemsBefore = await sql(`select * from public.tariff_items where tariff_version_id <> 'getir-esnaf-motorcycle-v1' order by 1`);
  const created = await admin.createManual('ayse', { platform: 'getir', versionId: 'getir-esnaf-motorcycle-v1',
    changes: [{ kind: 'changed', item_key: 'hourly', label: 'Saatlik', old_amount: 50, new_amount: 55, abs: 5, pct: 10 }],
    effectiveFrom: '2026-11-01', sourceRef: 'https://getir.example/duyuru', sourceType: 'official_announcement' });
  assert.equal(created.status, 'pending_verification', 'elle aday her zaman insan onayinda');
  await admin.decide(created.candidate_id, 'approved', 'ayse');
  await admin.publish(created.candidate_id, 'ayse');
  const after = await sql(`select tariff_version_id, revision from public.tariff_versions order by 1`);
  for (const row of after) {
    const old = before.find((b) => b.tariff_version_id === row.tariff_version_id);
    assert.equal(row.revision, row.tariff_version_id === 'getir-esnaf-motorcycle-v1' ? old.revision + 1 : old.revision, row.tariff_version_id);
  }
  assert.deepEqual(await sql(`select * from public.tariff_items where tariff_version_id <> 'getir-esnaf-motorcycle-v1' order by 1`), itemsBefore,
    'aracli Getir ve diger platformlar degismez');
});

test('es zamanli kontroller tek aday uretir', async () => {
  const { sql, repo } = await freshDb();
  await configureSource(sql, PT, { profile: PT_PROFILE });
  const web = fakeWeb({ [PT_URL]: ptPage({ tier: '41', extra: '<p>1 Kasım 2026 itibarıyla</p>' }) });
  const [a, b] = await Promise.all([check(repo, web), check(repo, web)]);
  const outcomes = [a.results[0].result, b.results[0].result].sort();
  assert.ok(outcomes.includes('new_candidate'));
  assert.equal((await candidates(sql)).length, 1);
  assert.equal((await sql(`select lock_until from public.tariff_sources where source_id = '${PT}'`))[0].lock_until, null);
});

test('surum geri cekme: istemci artik goremez, denetim kaydi', async () => {
  const { db, sql, repo } = await freshDb();
  const admin = createAdmin(repo);
  await admin.withdrawVersion('yemeksepeti-esnaf-v1', 'ayse', 'Yanlis yayim');
  assert.equal((await asRole(db, 'anon', `select count(*)::int n from public.tariff_items where tariff_version_id = 'yemeksepeti-esnaf-v1'`))[0].n, 0);
  assert.equal((await admin.withdrawVersion('yemeksepeti-esnaf-v1', 'ayse', 'tekrar')).status, 'already_withdrawn');
  assert.equal((await sql(`select count(*)::int n from public.tariff_audit_log where action = 'withdraw_version'`))[0].n, 1);
});

test('elle aday: kaynak zorunlu, duzenleme parmak izini gunceller ve denetlenir', async () => {
  const { sql, repo } = await freshDb();
  const admin = createAdmin(repo);
  const changes = [{ kind: 'changed', item_key: 'package.single', label: 'Tekli paket', old_amount: 75, new_amount: 80, abs: 5, pct: 6.67 }];
  await assert.rejects(admin.createManual('ayse', { platform: 'yemeksepeti', versionId: 'yemeksepeti-esnaf-v1', changes }), /Kaynak/);
  const created = await admin.createManual('ayse', { platform: 'yemeksepeti', versionId: 'yemeksepeti-esnaf-v1', changes,
    sourceRef: 'ekran-goruntusu-2026-10-11.png', ocrConfidence: 0.6 });
  assert.equal(created.status, 'needs_more_sources');
  assert.ok(created.reasons.includes('Düşük OCR / metin çıkarım güveni'));
  const detail = await admin.candidate(created.candidate_id);
  assert.equal(detail.sources[0].document_ref, 'ekran-goruntusu-2026-10-11.png');
  assert.equal(Number(detail.active.find((i) => i.item_key === 'package.single').amount), 75, 'eski/yeni karsilastirma icin aktif kalem');
  const edited = await admin.edit(created.candidate_id, 'ayse', { effectiveFrom: '2026-11-15', note: 'Tarih eklendi' });
  const row = (await sql(`select fingerprint, effective_from from public.tariff_candidates where candidate_id = '${created.candidate_id}'`))[0];
  assert.equal(row.fingerprint, edited.fingerprint);
  assert.equal(row.effective_from, '2026-11-15');
  assert.equal((await sql(`select count(*)::int n from public.tariff_audit_log where action = 'candidate_edit'`))[0].n, 1);
});

test('gunluk bakim: karar bekleyen eski adaylarin suresi dolar; ekonomik gosterge aday uretmez', async () => {
  const { sql, repo } = await freshDb();
  const admin = createAdmin(repo);
  const created = await admin.createManual('ayse', { platform: 'getir', versionId: 'getir-esnaf-car-v1',
    changes: [{ kind: 'changed', item_key: 'hourly', label: 'Saatlik', old_amount: 120, new_amount: 125, abs: 5, pct: 4.17 }],
    sourceRef: 'https://haber.example/x', sourceType: 'news' });
  await sql(`update public.tariff_candidates set created_at = now() - interval '61 days' where candidate_id = '${created.candidate_id}'`);
  await sql(`insert into public.economic_indicators (kind, value, unit, period, source_url) values ('fuel_price', 55, 'TL/L', '2026-10', null)`);
  const out = await dailyMaintenance({ repo });
  assert.deepEqual(out.expired, [created.candidate_id]);
  assert.equal((await sql(`select count(*)::int n from public.tariff_candidates`))[0].n, 1, 'gosterge aday olusturmadi');
  const items = await sql(`select count(*)::int n from public.tariff_items`);
  assert.equal(items[0].n, 83);
});

test('Tarife Merkezi genel bakis: dort platform karti', async () => {
  const { repo } = await freshDb();
  const admin = createAdmin(repo);
  const overview = await admin.overview();
  assert.deepEqual(overview.map((p) => p.platform_id), ['getir', 'migros_hemen', 'trendyol_go', 'yemeksepeti']);
  const getir = overview.find((p) => p.platform_id === 'getir');
  assert.equal(getir.versions.length, 2);
  assert.equal(getir.sources.length, 1);
});

test('Tarife Merkezi HTTP: belirtecsiz istek reddedilir, yerel API calisir', async () => {
  const { createCenterServer } = await import('../center_server.mjs');
  const { repo } = await freshDb();
  const admin = createAdmin(repo);
  const server = createCenterServer({ admin, actor: 'ayse', token: 'gizli-belirtec' });
  await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
  const base = `http://127.0.0.1:${server.address().port}`;
  try {
    const page = await fetch(`${base}/`);
    assert.equal(page.status, 200);
    assert.match(await page.text(), /Yönetici: ayse/);
    assert.equal((await fetch(`${base}/api/overview`)).status, 401);
    assert.equal((await fetch(`${base}/api/overview`, { headers: { 'X-Admin-Token': 'yanlis-belirtec' } })).status, 401);
    const headers = { 'X-Admin-Token': 'gizli-belirtec', 'Content-Type': 'application/json' };
    const overview = await (await fetch(`${base}/api/overview`, { headers })).json();
    assert.equal(overview.length, 4);
    const created = await (await fetch(`${base}/api/candidates`, { method: 'POST', headers, body: JSON.stringify({
      platform: 'trendyol_go', versionId: 'trendyol_go-esnaf-v1', effectiveFrom: '2026-11-01', sourceRef: 'https://example.com/duyuru',
      sourceType: 'official_announcement',
      changes: [{ kind: 'changed', item_key: 'package.day', label: 'Gündüz', old_amount: 64.5, new_amount: 66, abs: 1.5, pct: 2.33 }] }) })).json();
    const bad = await fetch(`${base}/api/candidates/${created.candidate_id}/publish`, { method: 'POST', headers, body: '{}' });
    assert.equal(bad.status, 400, 'onaysiz yayim reddedilir');
    await fetch(`${base}/api/candidates/${created.candidate_id}/decision`, { method: 'POST', headers, body: JSON.stringify({ status: 'approved' }) });
    const ok = await (await fetch(`${base}/api/candidates/${created.candidate_id}/publish`, { method: 'POST', headers, body: '{}' })).json();
    assert.equal(ok.status, 'published');
    const audit = await (await fetch(`${base}/api/audit`, { headers })).json();
    assert.ok(audit.some((a) => a.actor === 'ayse' && a.action === 'publish'));
  } finally {
    server.close();
  }
});
