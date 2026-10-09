// Anon anahtarla gercek uclara uctan uca kontrol. Biri basarisizsa cikis kodu 1.
import { randomUUID, createHash } from 'node:crypto';
import { env } from './lib.mjs';

const url = env('SUPABASE_URL');
const anon = env('SUPABASE_ANON_KEY');
let failures = 0;
const check = (cond, label) => { console.log(`${cond ? 'OK  ' : 'HATA'} ${label}`); if (!cond) failures++; };

const signup = await fetch(`${url}/auth/v1/signup`, {
  method: 'POST', headers: { apikey: anon, 'Content-Type': 'application/json' }, body: '{}',
});
const session = await signup.json();
check(signup.ok && session.access_token, 'anonim oturum');
const auth = { apikey: anon, Authorization: `Bearer ${session.access_token}`, 'Content-Type': 'application/json' };

const payload = {
  client_record_id: randomUUID(), platform_code: 'getir', province: 'İstanbul', district: 'Kadıköy',
  vehicle: 'motorcycle', weekday: 1, start_slot: 74, duration_min: 153, gross: 900, bonus: 100,
  packages: 12, distance_km: 41.5, level: 'ocrUnverified', template_id: 'getir.earnings',
  template_version: 1, text_hash: createHash('sha256').update(randomUUID()).digest('hex'),
};
const rpc = (fn, body) => fetch(`${url}/rest/v1/rpc/${fn}`, { method: 'POST', headers: auth, body: JSON.stringify(body) });

const first = await (await rpc('submit_shift', { payload })).json();
check(first === 'ok', `ilk gonderim: ${JSON.stringify(first)}`);
const second = await (await rpc('submit_shift', { payload })).json();
check(second === 'duplicate', `tekrar: ${JSON.stringify(second)}`);
const read = await fetch(`${url}/rest/v1/shifts?select=*`, { headers: auth });
check(!read.ok, `shifts okunamaz (HTTP ${read.status})`);
const templates = await (await fetch(`${url}/rest/v1/ocr_templates?select=id,version,status`, { headers: { apikey: anon } })).json();
check(Array.isArray(templates) && templates.length >= 4, `sablonlar okunur (${Array.isArray(templates) ? templates.length : JSON.stringify(templates)})`);
const del = await rpc('delete_my_data', {});
check(del.ok, `verilerimi sil (HTTP ${del.status})`);
process.exit(failures === 0 ? 0 : 1);
