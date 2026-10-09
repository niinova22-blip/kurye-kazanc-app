// Sentetik test kuryelerini temizler: vardiyalari ve bu kullanicilari (auth.users) siler.
// Gercek yayindan once calistirin. Kullanim: node --env-file=.env.supabase scripts/server/purge_synthetic.mjs
import { sql } from './lib.mjs';

// Once kimlikleri topla (vardiyalar silinince kaybolur).
const ids = (await sql('select distinct user_id from public.shifts where is_synthetic')).map((r) => r.user_id);
if (ids.length === 0) {
  console.log('Sentetik vardiya yok; yapilacak bir sey yok.');
  process.exit(0);
}
if (!ids.every((id) => /^[0-9a-f-]{36}$/.test(id))) throw new Error('Beklenmeyen kullanici kimligi');
const list = ids.map((id) => `'${id}'`).join(', ');

const deleted = await sql('delete from public.shifts where is_synthetic returning id');
console.log(`${deleted.length} sentetik vardiya silindi`);
// Kullanicilarin baska verisi (cascade) yoksa auth.users'tan silinir; shifts/backups/calibration cascade ile gider.
const users = await sql(`delete from auth.users where id in (${list}) returning id`);
console.log(`${users.length} sentetik kullanici silindi`);
