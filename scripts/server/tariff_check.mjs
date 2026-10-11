// Zamanlanmis tarife kaynak kontrolu (gunluk calistirilir; GitHub Actions `tariff-check.yml` ya da elle).
// Tarifeyi DEGISTIRMEZ (otomatik yayim ayari kapaliyken): degisiklikler aday olur, Tarife Merkezi'nde onaylanir.
//
//   node --env-file=.env.supabase scripts/server/tariff_check.mjs              zamani gelen kaynaklar + gunluk bakim
//   node --env-file=.env.supabase scripts/server/tariff_check.mjs --all        tum kaynaklar (siklik yok sayilir)
//   node --env-file=.env.supabase scripts/server/tariff_check.mjs --platform getir
//   node --env-file=.env.supabase scripts/server/tariff_check.mjs --source pakettaxi-migros-ucret
//   node --env-file=.env.supabase scripts/server/tariff_check.mjs --maintenance-only
import { sql } from './lib.mjs';
import { createRepo } from './tariff/repo.mjs';
import { dailyMaintenance, runChecks } from './tariff/runner.mjs';

const args = process.argv.slice(2);
const get = (flag) => { const i = args.indexOf(flag); return i >= 0 ? args[i + 1] : undefined; };
const repo = createRepo(sql);
const log = (line) => console.log(line);

let failed = false;
if (!args.includes('--maintenance-only')) {
  try {
    const { results } = await runChecks({ repo, force: args.includes('--all') || Boolean(get('--source')) || Boolean(get('--platform')),
      platform: get('--platform'), sourceId: get('--source'), log });
    const summary = {};
    for (const r of results) summary[r.result] = (summary[r.result] ?? 0) + 1;
    console.log(`kontrol: ${results.length} kaynak ${JSON.stringify(summary)}`);
  } catch (err) {
    // Kontrol hatasi tarifeyi etkilemez; uygulama son yayimlanan tarifeyle calismaya devam eder
    console.error(`kontrol calismasi hatasi: ${err}`);
    failed = true;
  }
}
try {
  const maintenance = await dailyMaintenance({ repo, log });
  console.log(`bakim: ${maintenance.expired.length} aday suresi doldu, ${maintenance.upcoming.length} yaklasan yururluk`);
} catch (err) {
  console.error(`bakim hatasi: ${err}`);
  failed = true;
}
console.log('Bekleyen adaylar icin: node --env-file=.env.supabase scripts/server/tariff_center.mjs --admin <ad>');
process.exit(failed ? 1 : 0);
