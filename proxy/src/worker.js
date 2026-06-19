// Koi fuel-price proxy.
//
// Caches and re-serves the Spanish government (minetur) fuel feed over clean modern HTTPS.
// Why it exists:
//   1. The app can then drop its NSAppTransportSecurity exception entirely (the proxy speaks
//      TLS 1.2+ to the app; it absorbs minetur's weaker transport server-side).
//   2. minetur is hit at most once per province per cache window instead of once per user —
//      and if minetur changes/breaks, you patch the proxy, not ship an app update.
//
// Endpoint:  GET /province/{2-digit INE code}   e.g. /province/28  (Madrid)
// Returns:   minetur's JSON verbatim (BOM included — the app already strips it).

const MINETUR =
  "https://sedeaplicaciones.minetur.gob.es/ServiciosRESTCarburantes/PreciosCarburantes/EstacionesTerrestres/FiltroProvincia";
const CACHE_TTL = 3600; // seconds — fuel prices move ~daily, so an hour is plenty fresh

export default {
  async fetch(request, ctx) {
    if (request.method !== "GET") {
      return new Response("Method not allowed", { status: 405 });
    }

    const url = new URL(request.url);
    const match = url.pathname.match(/^\/province\/(\d{2})$/);
    if (!match) {
      return new Response("Not found — use /province/{2-digit code}", { status: 404 });
    }
    const province = match[1];

    // Edge cache: serve a hit immediately.
    const cache = caches.default;
    const cacheKey = new Request(url.toString(), { method: "GET" });
    const cached = await cache.match(cacheKey);
    if (cached) return cached;

    let upstream;
    try {
      upstream = await fetch(`${MINETUR}/${province}`, {
        headers: { accept: "application/json" },
        cf: { cacheTtl: CACHE_TTL, cacheEverything: true },
      });
    } catch (_e) {
      return new Response("Upstream fetch failed", { status: 502 });
    }
    if (!upstream.ok) {
      return new Response(`Upstream error (${upstream.status})`, { status: 502 });
    }

    const body = await upstream.arrayBuffer();
    const response = new Response(body, {
      status: 200,
      headers: {
        "content-type": "application/json; charset=utf-8",
        "cache-control": `public, max-age=${CACHE_TTL}`,
      },
    });

    ctx.waitUntil(cache.put(cacheKey, response.clone()));
    return response;
  },
};
