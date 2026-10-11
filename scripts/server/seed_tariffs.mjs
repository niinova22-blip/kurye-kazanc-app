// Gomulu ORNEK tarifeleri (BundledTariffs.swift) ve izlenecek kaynaklari (tariff/sources.json) yazar.
// Tekrar calistirilabilir: var olan kayitlara dokunmaz. Kullanim:
//   node --env-file=.env.supabase scripts/server/seed_tariffs.mjs
import { sql } from './lib.mjs';
import { seedStatements } from './tariff/seed.mjs';

const statements = seedStatements();
for (const statement of statements) await sql(statement);
const counts = await sql(`select (select count(*) from public.tariff_versions) as versions,
  (select count(*) from public.tariff_items) as items, (select count(*) from public.tariff_sources) as sources`);
console.log(`tohum tamam: ${JSON.stringify(counts[0])} (ornek tarifeler "dogrulama gerekli")`);
