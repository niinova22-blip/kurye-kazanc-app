// Sincan/Ankara icin sentetik test kuryeleri: 8 anonim kullanici + son 30 gun gercekci vardiyalar.
// Tohumlu (tekrarlanabilir). Sentetik satirlar is_synthetic = true; purge_synthetic.mjs siler.
// Kullanim: node --env-file=.env.supabase scripts/server/seed_synthetic.mjs [--force]
import { randomBytes } from 'node:crypto';
import { env, sql } from './lib.mjs';

const COURIERS = 8;
const DAYS = 30;
const PLATFORMS = ['trendyol_go', 'getir', 'yemeksepeti', 'migros_hemen', 'uber'];
const force = process.argv.includes('--force');

const url = env('SUPABASE_URL');
const anon = env('SUPABASE_ANON_KEY');

const existing = await sql('select count(*)::int as n from public.shifts where is_synthetic');
if (existing[0].n > 0 && !force) {
  console.error(`Zaten ${existing[0].n} sentetik vardiya var. Once purge_synthetic.mjs calistirin veya --force kullanin.`);
  process.exit(1);
}

// mulberry32: tohumlu, tekrarlanabilir rastgele sayi uretecu.
function mulberry32(seed) {
  let a = seed >>> 0;
  return () => {
    a = (a + 0x6d2b79f5) >>> 0;
    let t = a;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}
const rnd = mulberry32(20261010);
const between = (lo, hi) => lo + rnd() * (hi - lo);
const intBetween = (lo, hi) => Math.floor(between(lo, hi + 1));
const pick = (arr) => arr[Math.floor(rnd() * arr.length)];
// text_hash ve client_record_id de tohumlu uretilir (tekrarlanabilir, benzersiz).
const hex = (n) => Array.from({ length: n }, () => Math.floor(rnd() * 16).toString(16)).join('');
const uuid = () => `${hex(8)}-${hex(4)}-4${hex(3)}-a${hex(3)}-${hex(12)}`;

function userIdFrom(session) {
  if (session?.user?.id) return session.user.id;
  const payload = session?.access_token?.split('.')[1];
  return payload ? JSON.parse(Buffer.from(payload, 'base64url').toString()).sub : null;
}

const users = [];
for (let i = 0; i < COURIERS; i++) {
  const res = await fetch(`${url}/auth/v1/signup`, {
    method: 'POST', headers: { apikey: anon, 'Content-Type': 'application/json' }, body: '{}',
  });
  const session = await res.json();
  const id = res.ok ? userIdFrom(session) : null;
  if (!id) {
    console.error(`Anonim kullanici olusturulamadi (HTTP ${res.status}): ${JSON.stringify(session)}`);
    process.exit(1);
  }
  users.push(id);
}
console.log(`${users.length} anonim kullanici olusturuldu`);

const pad = (n) => String(n).padStart(2, '0');
const today = new Date();
const base = Date.UTC(today.getUTCFullYear(), today.getUTCMonth(), today.getUTCDate());
const rows = [];

users.forEach((userId, idx) => {
  // Her kurye 1-2 platformda calisir; biri baskin.
  const main = PLATFORMS[idx % PLATFORMS.length];
  const alt = pick(PLATFORMS);
  for (let back = 1; back <= DAYS; back++) {
    if (rnd() < 0.22) continue; // izin gunu
    const date = new Date(base - back * 86400000);
    const dow = date.getUTCDay(); // 0 = Pazar
    const weekday = dow === 0 ? 7 : dow; // 1 = Pazartesi
    const weekend = weekday >= 6;
    const shiftsToday = rnd() < 0.4 ? 2 : 1;
    const kinds = shiftsToday === 2 ? ['morning', 'evening'] : [rnd() < 0.7 ? 'evening' : 'morning'];
    for (const kind of kinds) {
      let startHour, durHours, rate;
      if (kind === 'morning') {
        startHour = intBetween(9, 12);
        durHours = shiftsToday === 2 ? between(3, 4) : between(3, 6);
        rate = between(170, 260) * (weekend ? 1.1 : 1);
      } else {
        startHour = intBetween(17, 20);
        durHours = Math.min(shiftsToday === 2 ? between(3, 5) : between(3, 6), 23.5 - startHour + 1);
        rate = between(250, 380) * (weekend ? 1.1 : 1);
        rate = Math.min(rate, 420);
      }
      const startMin = intBetween(0, 3) * 15;
      const durationMin = Math.max(180, Math.round(durHours * 60 / 5) * 5);
      const hours = durationMin / 60;
      const total = Math.round(rate * hours * 100) / 100;
      const bonus = rnd() < 0.2 ? Math.round(between(20, 80)) : 0;
      const gross = Math.round((total - bonus) * 100) / 100;
      const packages = Math.max(1, Math.round(hours * between(2.2, 2.8)));
      const platform = rnd() < 0.75 ? main : alt;
      const createdAt = `${date.getUTCFullYear()}-${pad(date.getUTCMonth() + 1)}-${pad(date.getUTCDate())} ${pad(Math.min(startHour + Math.floor(durHours), 23))}:${pad(startMin)}:00+03`;
      rows.push({
        userId, platform, weekday, startSlot: startHour * 4 + startMin / 15, durationMin, gross, bonus, packages,
        distanceKm: Math.round(packages * between(2.5, 4.5) * 10) / 10, createdAt,
        hash: hex(64), recordId: uuid(),
      });
    }
  }
});

const values = (r) =>
  `('${r.userId}', '${r.recordId}', '${r.platform}', 'Ankara', 'Sincan', 'motorcycle', ${r.weekday}, ${r.startSlot}, ` +
  `${r.durationMin}, ${r.gross}, ${r.bonus}, ${r.packages}, ${r.distanceKm}, 'ocrUnverified', '${r.hash}', '${r.createdAt}', true)`;

let inserted = 0;
for (let i = 0; i < rows.length; i += 100) {
  const batch = rows.slice(i, i + 100);
  await sql(
    'insert into public.shifts (user_id, client_record_id, platform_code, province, district, vehicle, weekday, ' +
    'start_slot, duration_min, gross, bonus, packages, distance_km, level, text_hash, created_at, is_synthetic) values ' +
    batch.map(values).join(', ') + ' on conflict (text_hash) do nothing',
  );
  inserted += batch.length;
}
console.log(`${inserted} sentetik vardiya eklendi (${users.length} kurye, Ankara/Sincan)`);
const check = await sql('select count(*)::int as n, count(distinct user_id)::int as u from public.shifts where is_synthetic');
console.log(`Dogrulama: ${check[0].n} sentetik vardiya, ${check[0].u} kurye`);
