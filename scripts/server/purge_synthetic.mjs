// Sentetik test kuryelerini temizler: auth.users satirlari silinir, vardiyalar cascade ile gider.
// Gercek yayindan once calistirin. Kullanim: node --env-file=.env.supabase scripts/server/purge_synthetic.mjs
import { sql } from './lib.mjs';

const rows = await sql(`
  with doomed as (select distinct user_id from public.shifts where is_synthetic),
       shift_count as (select count(*)::int as n from public.shifts where is_synthetic),
       gone as (delete from auth.users where id in (select user_id from doomed) returning id)
  select (select n from shift_count) as shifts, (select count(*)::int from gone) as users`);
console.log(`${rows[0].users} sentetik kullanici silindi (${rows[0].shifts} sentetik vardiya cascade ile gitti)`);
