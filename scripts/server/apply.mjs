// supabase/migrations/*.sql dosyalarini sirayla, bir kez uygular.
import { readdirSync, readFileSync } from 'node:fs';
import { join } from 'node:path';
import { sql } from './lib.mjs';

const dir = 'supabase/migrations';
await sql('create table if not exists public.schema_migrations (name text primary key, applied_at timestamptz default now())');
await sql('revoke all on public.schema_migrations from anon, authenticated');
const done = new Set((await sql('select name from public.schema_migrations')).map((r) => r.name));
for (const name of readdirSync(dir).filter((f) => f.endsWith('.sql')).sort()) {
  if (done.has(name)) { console.log(`atlandi: ${name}`); continue; }
  await sql(readFileSync(join(dir, name), 'utf8'));
  await sql(`insert into public.schema_migrations (name) values ('${name.replace(/'/g, "''")}')`);
  console.log(`uygulandi: ${name}`);
}
