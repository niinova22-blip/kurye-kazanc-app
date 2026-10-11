// Tarife Merkezi HTTP sunucusu (yalnizca 127.0.0.1). Belirtec URL parcasinda (#) tasinir, sunucuya basliktan gelir.
import { createServer } from 'node:http';
import { timingSafeEqual } from 'node:crypto';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

const html = readFileSync(join(dirname(fileURLToPath(import.meta.url)), 'center.html'), 'utf8');

export function createCenterServer({ admin, actor, token, port = 8787 }) {
  function authorized(req) {
    const given = Buffer.from(String(req.headers['x-admin-token'] ?? ''));
    const expected = Buffer.from(token);
    return given.length === expected.length && timingSafeEqual(given, expected);
  }

  async function body(req) {
    const chunks = [];
    for await (const chunk of req) chunks.push(chunk);
    if (chunks.length === 0) return {};
    return JSON.parse(Buffer.concat(chunks).toString('utf8'));
  }

  const routes = [
    ['GET', /^\/api\/overview$/, () => admin.overview()],
    ['GET', /^\/api\/candidates$/, (m, b, url) => admin.candidates({ platform: url.searchParams.get('platform') || undefined,
      status: url.searchParams.get('status') || undefined })],
    ['GET', /^\/api\/candidates\/([^/]+)$/, (m) => admin.candidate(m[1])],
    ['POST', /^\/api\/candidates$/, (m, b) => admin.createManual(actor, b)],
    ['POST', /^\/api\/candidates\/([^/]+)\/decision$/, (m, b) => admin.decide(m[1], b.status, actor, { note: b.note,
      effectiveFrom: b.effectiveFrom || undefined })],
    ['POST', /^\/api\/candidates\/([^/]+)\/edit$/, (m, b) => admin.edit(m[1], actor, b)],
    ['POST', /^\/api\/candidates\/([^/]+)\/publish$/, (m) => admin.publish(m[1], actor)],
    ['POST', /^\/api\/candidates\/([^/]+)\/withdraw$/, (m, b) => admin.withdrawCandidate(m[1], actor, b.reason)],
    ['POST', /^\/api\/versions\/([^/]+)\/withdraw$/, (m, b) => admin.withdrawVersion(m[1], actor, b.reason)],
    ['GET', /^\/api\/versions$/, (m, b, url) => admin.versions(url.searchParams.get('platform') || undefined)],
    ['GET', /^\/api\/audit$/, () => admin.auditLog(200)],
    ['GET', /^\/api\/checks$/, () => admin.checks(200)],
    ['POST', /^\/api\/check$/, (m, b) => admin.runCheck(actor, { sourceId: b.sourceId, platform: b.platform })],
  ];

  const server = createServer(async (req, res) => {
    const url = new URL(req.url, `http://127.0.0.1:${port}`);
    if (req.method === 'GET' && url.pathname === '/') {
      res.writeHead(200, { 'Content-Type': 'text/html; charset=utf-8', 'Cache-Control': 'no-store',
        'Content-Security-Policy': "default-src 'self'; style-src 'unsafe-inline'; script-src 'unsafe-inline'; connect-src 'self'" });
      res.end(html.replace('__ACTOR__', actor.replace(/[<>&"]/g, '')));
      return;
    }
    if (!url.pathname.startsWith('/api/')) { res.writeHead(404); res.end(); return; }
    if (!authorized(req)) { res.writeHead(401, { 'Content-Type': 'application/json' }); res.end('{"error":"yetkisiz"}'); return; }
    for (const [method, pattern, handler] of routes) {
      const match = url.pathname.match(pattern);
      if (!match || method !== req.method) continue;
      try {
        const result = await handler(match, req.method === 'POST' ? await body(req) : {}, url);
        res.writeHead(200, { 'Content-Type': 'application/json; charset=utf-8' });
        res.end(JSON.stringify(result));
      } catch (err) {
        res.writeHead(400, { 'Content-Type': 'application/json; charset=utf-8' });
        res.end(JSON.stringify({ error: String(err.message ?? err) }));
      }
      return;
    }
    res.writeHead(404, { 'Content-Type': 'application/json' });
    res.end('{"error":"bulunamadi"}');
  });
  return server;
}
