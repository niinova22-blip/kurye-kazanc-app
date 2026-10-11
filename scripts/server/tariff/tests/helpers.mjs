// Test yardimcilari. Veritabani: ../pglite_db.mjs (gercek Postgres, goc + tohum).
import { freshDb } from '../pglite_db.mjs';

export { freshDb };

/** Rol olarak sorgu (RLS testleri). */
export async function asRole(db, role, query) {
  await db.exec(`set role ${role}`);
  try {
    return (await db.query(query)).rows;
  } finally {
    await db.exec('reset role');
  }
}

/** URL -> sayfa; fonksiyonla degistirilebilir. */
export function fakeWeb(pages = {}) {
  const calls = [];
  return {
    pages,
    calls,
    fetchPage: async (url) => {
      calls.push(url);
      const page = pages[url];
      if (page instanceof Error) throw page;
      if (page === undefined) return { status: 404, ok: false, text: '' };
      if (typeof page === 'object') return page;
      return { status: 200, ok: true, text: page };
    },
    fetchRobots: async () => '',
  };
}

export const noWait = async () => {};

/** Bir kaynaga alan cikarim profili ve resmi tur atar. */
export async function configureSource(sql, sourceId, { url, type, profile, versionId }) {
  await sql(`update public.tariff_sources set
      ${url ? `url = '${url}',` : ''}
      ${type ? `source_type = '${type}',` : ''}
      ${versionId ? `tariff_version_id = '${versionId}',` : ''}
      extraction_profile = '${JSON.stringify(profile ?? []).replace(/'/g, "''")}'::jsonb
    where source_id = '${sourceId}'`);
}

export const PT_PROFILE = [
  { item_key: 'package.performance.0', pattern: 'paket başı performans ücreti:?\\s*([\\d.,]+)\\s*tl' },
  { item_key: 'package.performance.1100', pattern: '1\\.100\\+? paket:?\\s*([\\d.,]+)\\s*tl' },
];

export function ptPage({ base = '38', tier = '40', title = 'Migros Kurye Ücretleri', extra = '' } = {}) {
  return `<html><head><title>${title}</title></head><body><h1>${title}</h1>
    <p>Paket başı performans ücreti: ${base} TL</p><p>1.100+ paket: ${tier} TL</p>${extra}</body></html>`;
}
