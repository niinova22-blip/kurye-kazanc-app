// Bellekte gercek Postgres (PGlite): goc + tohum. Yerel testler ve kimlik bilgisi gerektirmeyen demo icin.
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';
import { PGlite } from '@electric-sql/pglite';
import { createRepo } from './repo.mjs';
import { bundledVersions, legacyVersions, seedStatements } from './seed.mjs';

const root = join(dirname(fileURLToPath(import.meta.url)), '..', '..', '..');
const migration = readFileSync(join(root, 'supabase/migrations/20261011000005_tariffs.sql'), 'utf8');

export async function freshDb({ autoPublish = false } = {}) {
  // Tarih ve zaman damgalari Management API'deki gibi metin doner
  const db = new PGlite({ parsers: { 1082: (v) => v, 1114: (v) => v, 1184: (v) => v, 1700: (v) => v } });
  await db.exec(`create role anon nologin; create role authenticated nologin;`);
  await db.exec(migration);
  const sql = async (query) => (await db.query(query)).rows;
  // Testler kaldirilan firmalarin surumleriyle de calisir (bkz. legacyVersions)
  for (const statement of seedStatements([...bundledVersions(), ...legacyVersions()])) await sql(statement);
  if (autoPublish) await sql(`update public.tariff_config set value = 'true'::jsonb where key = 'auto_publish_official'`);
  return { db, sql, repo: createRepo(sql) };
}

