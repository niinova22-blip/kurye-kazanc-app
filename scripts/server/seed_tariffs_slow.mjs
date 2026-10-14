// seed_tariffs.mjs ile ayni (insert-only), ama Management API hiz sinirina takilmasin diye istekler aralikli ve 429'da tekrar denenir.
//   node --env-file=.env.supabase scripts/server/seed_tariffs_slow.mjs
import { sql } from './lib.mjs';
import { seedStatements } from './tariff/seed.mjs';

const wait = (ms) => new Promise((r) => setTimeout(r, ms));
const statements = seedStatements();
let done = 0;
for (const statement of statements) {
  for (let attempt = 0; ; attempt++) {
    try {
      await sql(statement);
      break;
    } catch (error) {
      if (!String(error.message).includes('429') || attempt > 8) throw error;
      await wait(5000 * (attempt + 1));
    }
  }
  done++;
  if (done % 25 === 0) console.log(`${done}/${statements.length}`);
  await wait(400);
}
const counts = await sql(`select (select count(*) from public.tariff_versions) as versions,
  (select count(*) from public.tariff_items) as items, (select count(*) from public.tariff_sources) as sources`);
console.log(`tohum tamam: ${JSON.stringify(counts[0])}`);
