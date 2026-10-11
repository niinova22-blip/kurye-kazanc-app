import { test } from 'node:test';
import assert from 'node:assert/strict';
import { canTransition, diffItems, evaluatePolicy, extractEffectiveDate, extractValues, fingerprint, hashText, indicatorAlerts,
  isDue, normalizeText, parseAmount, robotsAllows, upcoming } from '../core.mjs';

const config = { auto_publish_official: true, min_ocr_confidence: 0.9, large_change_pct: 25 };

test('normalize: saat damgasi, betik ve bicim degisikligi ozeti degistirmez', () => {
  const a = '<html><script>x=1</script><h1>Ücretler</h1><p>Paket   başı 38 TL</p><small>Son güncelleme 10:45</small></html>';
  const b = '<html><style>.x{}</style><div><h1>Ücretler</h1></div><p>Paket başı 38 TL</p><small>Son güncelleme 18:02:11</small></html>';
  assert.equal(hashText(normalizeText(a)), hashText(normalizeText(b)));
});

test('parseAmount Turkce yazimlar', () => {
  assert.equal(parseAmount('1.610'), 1610);
  assert.equal(parseAmount('64,50'), 64.5);
  assert.equal(parseAmount('1.234,56 TL'), 1234.56);
  assert.equal(parseAmount('12.50'), 12.5);
  assert.equal(parseAmount('abc'), null);
});

test('extractValues profil ve guven', () => {
  const text = normalizeText('<p>Paket başı ücret: 40 TL</p><p>1.100 paket üstü 42,5 TL</p>');
  const r = extractValues(text, [
    { item_key: 'package.performance.0', pattern: 'paket başı ücret:\\s*([\\d.,]+)' },
    { item_key: 'package.performance.1100', pattern: '1\\.100 paket üstü\\s*([\\d.,]+)' },
    { item_key: 'fixed.region.plus', pattern: 'plus\\s*([\\d.,]+)' },
  ]);
  assert.deepEqual(r.values, { 'package.performance.0': { amount: 40 }, 'package.performance.1100': { amount: 42.5 } });
  assert.equal(r.matched, 2);
  assert.equal(r.confidence, 0.67);
});

test('yururluk tarihi: anahtar kelimeyle kesin, yalniz tarih belirsiz', () => {
  assert.deepEqual(extractEffectiveDate('1 Kasım 2026 itibarıyla yeni ücretler'), { date: '2026-11-01', certain: true });
  assert.deepEqual(extractEffectiveDate('Yayın: 3 Ekim 2026'), { date: '2026-10-03', certain: false });
  assert.deepEqual(extractEffectiveDate('tarih yok'), { date: null, certain: false });
});

test('diffItems: ayni degerler degisiklik degil, farkli deger mutlak ve yuzde farkla', () => {
  const active = [{ item_key: 'a', label: 'Paket', amount: '38.00', amount_upper: null, lower_threshold: '0', upper_threshold: null }];
  assert.deepEqual(diffItems(active, { a: { amount: 38 } }), []);
  const changes = diffItems(active, { a: { amount: 40 } });
  assert.equal(changes.length, 1);
  assert.equal(changes[0].old_amount, 38);
  assert.equal(changes[0].new_amount, 40);
  assert.equal(changes[0].abs, 2);
  assert.equal(changes[0].pct, 5.26);
  const threshold = diffItems(active, { a: { lower_threshold: 5 } });
  assert.equal(threshold[0].new_lower_threshold, 5);
  assert.equal(threshold[0].new_amount, 38, 'tutar degismeden esik degisikligi');
  const added = diffItems(active, { b: { amount: 10 } });
  assert.equal(added[0].kind, 'added');
});

test('fingerprint degisiklik sirasindan bagimsiz, deger degisince farkli', () => {
  const c1 = [{ item_key: 'a', kind: 'changed', new_amount: 1 }, { item_key: 'b', kind: 'changed', new_amount: 2 }];
  const base = { platform_id: 'p', tariff_version_id: 'v', effective_from: '2026-11-01' };
  assert.equal(fingerprint({ ...base, changes: c1 }), fingerprint({ ...base, changes: [...c1].reverse() }));
  assert.notEqual(fingerprint({ ...base, changes: c1 }), fingerprint({ ...base, changes: [{ ...c1[0], new_amount: 3 }, c1[1]] }));
});

test('politika: tek ikincil kaynak ek kaynak ister, otomatik yayim yok', () => {
  const r = evaluatePolicy({ sourceTypes: ['news'], sourceCount: 1, effectiveDateCertain: true,
    changes: [{ kind: 'changed', pct: 5 }], config });
  assert.equal(r.autoPublish, false);
  assert.equal(r.status, 'needs_more_sources');
  assert.ok(r.reasons.includes('Tek ikincil kaynak'));
});

test('politika: tek guvenilir resmi kaynak, kesin tarih, kucuk fark -> ayar aciksa otomatik', () => {
  const ok = evaluatePolicy({ sourceTypes: ['official_announcement'], sourceCount: 1, effectiveDateCertain: true,
    ocrConfidence: 1, changes: [{ kind: 'changed', pct: 5 }], config });
  assert.equal(ok.autoPublish, true);
  assert.equal(ok.verification, 'verified');
  const off = evaluatePolicy({ sourceTypes: ['official_announcement'], sourceCount: 1, effectiveDateCertain: true,
    changes: [{ kind: 'changed', pct: 5 }], config: { ...config, auto_publish_official: false } });
  assert.equal(off.autoPublish, false);
});

test('politika: insan onayi zorunlu durumlar', () => {
  const cases = [
    [{ conflicting: true }, 'Çelişen kaynaklar'],
    [{ ocrConfidence: 0.5 }, 'Düşük OCR / metin çıkarım güveni'],
    [{ effectiveDateCertain: false }, 'Belirsiz yürürlük tarihi'],
    [{ stackingAmbiguous: true }, 'Bonusların birlikte uygulanma belirsizliği'],
    [{ scopeAmbiguous: true }, 'Bölge / çalışma modeli belirsizliği'],
    [{ changes: [{ kind: 'changed', pct: 60 }] }, 'Olağan dışı büyük fark ya da kalem ekleme/çıkarma'],
  ];
  for (const [extra, reason] of cases) {
    const r = evaluatePolicy({ sourceTypes: ['official_announcement'], sourceCount: 1, effectiveDateCertain: true,
      ocrConfidence: 1, changes: [{ kind: 'changed', pct: 5 }], config, ...extra });
    assert.equal(r.autoPublish, false, reason);
    assert.ok(r.reasons.includes(reason), reason);
  }
});

test('durum gecisleri', () => {
  assert.ok(canTransition('pending_verification', 'approved'));
  assert.ok(canTransition('approved', 'published'));
  assert.ok(canTransition('published', 'withdrawn'));
  assert.ok(!canTransition('rejected', 'approved'));
  assert.ok(!canTransition('draft', 'published'));
  assert.ok(!canTransition('withdrawn', 'published'));
});

test('zamanlama: siklik yapilandirilabilir', () => {
  const now = new Date('2026-10-11T12:00:00Z');
  assert.ok(isDue({ active: true, last_checked_at: null, check_interval_minutes: 1440 }, now));
  assert.ok(!isDue({ active: true, last_checked_at: '2026-10-11T06:00:00Z', check_interval_minutes: 1440 }, now));
  assert.ok(isDue({ active: true, last_checked_at: '2026-10-11T06:00:00Z', check_interval_minutes: 360 }, now));
  assert.ok(!isDue({ active: false, last_checked_at: null, check_interval_minutes: 60 }, now));
});

test('robots.txt', () => {
  const robots = 'User-agent: *\nDisallow: /panel\n\nUser-agent: OtherBot\nDisallow: /';
  assert.ok(robotsAllows(robots, '/ucretler'));
  assert.ok(!robotsAllows(robots, '/panel/giris'));
  assert.ok(!robotsAllows('User-agent: KuryeKazanc\nDisallow: /', '/x'));
  assert.ok(robotsAllows('', '/x'));
});

test('yaklasan yururluk tarihleri', () => {
  const list = [{ effective_from: '2026-10-15' }, { effective_from: '2026-12-01' }, { effective_from: '2026-10-01' }];
  assert.deepEqual(upcoming(list, '2026-10-11').map((x) => x.effective_from), ['2026-10-15']);
});

test('ekonomik gosterge yalnizca uyari uretir', () => {
  const alerts = indicatorAlerts({ kind: 'fuel_price', value: 55, previous: 50, period: '2026-10', fetchedAt: '2026-10-10' });
  assert.equal(alerts.length, 1);
  assert.match(alerts[0], /tarife değişmedi/);
  assert.match(indicatorAlerts({ kind: 'cpi', value: 1, fetchedAt: null })[0], /güncel sayılmaz/);
});
