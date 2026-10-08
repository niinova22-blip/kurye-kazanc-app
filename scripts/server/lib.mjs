// Ortak yardimcilar: Management API SQL ucu ve REST cagrilari. Gizli degerler yalnizca ortam degiskeninden.
export function env(name) {
  const value = process.env[name];
  if (!value) {
    console.error(`Eksik ortam degiskeni: ${name}`);
    process.exit(2);
  }
  return value;
}

export async function sql(query) {
  const ref = env('SUPABASE_PROJECT_REF');
  const token = env('SUPABASE_ACCESS_TOKEN');
  const res = await fetch(`https://api.supabase.com/v1/projects/${ref}/database/query`, {
    method: 'POST',
    headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({ query }),
  });
  const text = await res.text();
  if (!res.ok) throw new Error(`SQL hatasi ${res.status}: ${text}`);
  return text ? JSON.parse(text) : [];
}
