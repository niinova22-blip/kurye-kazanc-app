// Tarife Merkezi: yalnizca bu bilgisayarda (127.0.0.1) calisan yonetim paneli.
// Yetki: sunucu anahtari yalnizca ortam degiskeninde (.env.supabase); panel her acilista uretilen tek kullanimlik
// belirtecle korunur; her onay / yayim / geri cekme yonetici adiyla denetim kaydina yazilir.
//
//   node --env-file=.env.supabase scripts/server/tariff_center.mjs --admin "Ad Soyad" [--port 8787]
import { randomBytes } from 'node:crypto';
import { sql } from './lib.mjs';
import { createAdmin } from './tariff/admin.mjs';
import { createRepo } from './tariff/repo.mjs';
import { createCenterServer } from './tariff/center_server.mjs';

const args = process.argv.slice(2);
const get = (flag) => { const i = args.indexOf(flag); return i >= 0 ? args[i + 1] : undefined; };
const actor = get('--admin') ?? process.env.TARIFF_ADMIN;
if (!actor) {
  console.error('Yonetici adi gerekli: --admin "Ad Soyad" (denetim kaydi icin)');
  process.exit(2);
}
const port = Number(get('--port') ?? 8787);
const token = randomBytes(24).toString('hex');
const admin = createAdmin(createRepo(sql));

createCenterServer({ admin, actor, token, port }).listen(port, '127.0.0.1', () => {
  console.log(`Tarife Merkezi: http://127.0.0.1:${port}/#${token}`);
  console.log(`Yonetici: ${actor}. Bu adres yalnizca bu bilgisayardan acilir; belirtec her baslatmada degisir.`);
});
