// Tarife Merkezi DEMO: kimlik bilgisi ve canli veritabani olmadan, bellekte Postgres (PGlite) + ornek tohum + sahte kaynak.
// "Kontrol et" Paket Taxi sayfasinin degismis bir kopyasini okur ve aday uretir. Hicbir yere ag istegi yapilmaz.
//   cd scripts/server && npm install && node tariff/demo_center.mjs [--port 8788]
import { randomBytes } from 'node:crypto';
import { createAdmin } from './admin.mjs';
import { createCenterServer } from './center_server.mjs';
import { freshDb } from './pglite_db.mjs';

const args = process.argv.slice(2);
const port = Number(args[args.indexOf('--port') + 1] || 8788);
const { sql, repo } = await freshDb();
const profile = [
  { item_key: 'package.performance.0', pattern: String.raw`paket başı performans ücreti:?\s*([\d.,]+)\s*tl` },
  { item_key: 'package.performance.1100', pattern: String.raw`1\.100\+? paket:?\s*([\d.,]+)\s*tl` },
];
await sql(`update public.tariff_sources set extraction_profile = '${JSON.stringify(profile)}'::jsonb
  where source_id = 'pakettaxi-migros-ucret'`);
const page = '<h1>Migros Kurye Ücretleri (DEMO)</h1><p>Paket başı performans ücreti: 38 TL</p><p>1.100+ paket: 41 TL</p>'
  + '<p>1 Kasım 2026 itibarıyla geçerlidir.</p>';
const fetchPage = async (url) => (url.includes('pakettaxi') ? { status: 200, ok: true, text: page } : { status: 503, ok: false, text: '' });
const admin = createAdmin(repo, { checkOptions: { fetchPage, fetchRobots: async () => '', throttle: async () => {} } });
const token = randomBytes(24).toString('hex');
createCenterServer({ admin, actor: 'demo-yonetici', token, port }).listen(port, '127.0.0.1', () => {
  console.log(`DEMO Tarife Merkezi: http://127.0.0.1:${port}/#${token}`);
  console.log('Veriler bellekte; kapatinca silinir. Canli panel: tariff_center.mjs');
});
