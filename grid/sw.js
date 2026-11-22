// Grid service worker: the instrument shell, its pinned data and visited map
// tiles work offline. Live publisher APIs are never answered from cache, so an
// offline Grid shows sources as unavailable rather than presenting old values
// as current. The relay snapshot carries its own generation time and may be cached.
const VERSION = 'grid-2026-11-22-2';
const SHELL = [
  './', 'index.html', 'grid.css', 'app.js', 'manifest.webmanifest', 'door.js',
  'map/map.js', 'map/fly.js', 'live/sources.js', 'ui/charts.js', 'ui/panels.js', 'ui/pages.js',
  'engine/prng.js', 'engine/linalg.js', 'engine/monitor.js', 'engine/rational.js', 'engine/certificate.js', 'engine/e47.js', 'engine/worker.js', 'engine/pins.js',
  'lib/maplibre/maplibre-gl.mjs', 'lib/maplibre/maplibre-gl-worker.mjs', 'lib/maplibre/maplibre-gl.css',
  'data/topology-ieee14.json', 'data/topology-ieee118.json', 'data/certificate-ieee14.json', 'data/certificate-ieee118.json',
  'data/cm2-survey-ieee14.json', 'data/cm2-survey-ieee118.json', 'data/reference-acceptance.json',
  'data/plants-us.json', 'data/us-states.json', 'data/ba-meta.json',
  'fonts/newsreader-latin-400-normal.woff2', 'fonts/newsreader-latin-400-italic.woff2', 'fonts/newsreader-latin-500-normal.woff2', 'fonts/newsreader-latin-500-italic.woff2',
  'fonts/ibm-plex-sans-latin-400-normal.woff2', 'fonts/ibm-plex-sans-latin-500-normal.woff2', 'fonts/ibm-plex-sans-latin-600-normal.woff2',
  'fonts/ibm-plex-sans-greek-400-normal.woff2', 'fonts/ibm-plex-sans-greek-500-normal.woff2',
  'fonts/ibm-plex-mono-latin-400-normal.woff2', 'fonts/ibm-plex-mono-latin-500-normal.woff2', 'fonts/ibm-plex-mono-latin-600-normal.woff2',
  'fonts/dejavu-sans-mono-math.woff2', 'cover-grid.jpg', 'icons/grid.svg', 'icons/grid-192.png', 'icons/grid-512.png',
];
const TILE_HOSTS = ['server.arcgisonline.com', 's3.amazonaws.com', 'gibs.earthdata.nasa.gov', 'demotiles.maplibre.org'];
const TILE_CACHE = 'grid-tiles-v1', TILE_LIMIT = 2500;

self.addEventListener('install', (e) => {
  e.waitUntil(caches.open(VERSION).then((c) => c.addAll(SHELL)).then(() => self.skipWaiting()));
});
self.addEventListener('activate', (e) => {
  e.waitUntil(caches.keys().then((ks) => Promise.all(ks.filter((k) => k !== VERSION && k !== TILE_CACHE).map((k) => caches.delete(k)))).then(() => self.clients.claim()));
});

async function trimTiles() {
  const c = await caches.open(TILE_CACHE); const keys = await c.keys();
  if (keys.length > TILE_LIMIT) await Promise.all(keys.slice(0, keys.length - TILE_LIMIT).map((k) => c.delete(k)));
}

self.addEventListener('fetch', (e) => {
  const req = e.request; if (req.method !== 'GET') return;
  const url = new URL(req.url);
  if (url.origin === self.location.origin && url.pathname.includes('/grid/')) {
    e.respondWith(caches.open(VERSION).then(async (c) => {
      const hit = await c.match(req, { ignoreSearch: true });
      const net = fetch(req).then((r) => { if (r.ok) c.put(req, r.clone()); return r; }).catch(() => hit);
      return hit || net;
    }));
    return;
  }
  if (TILE_HOSTS.includes(url.hostname)) {
    e.respondWith(caches.open(TILE_CACHE).then(async (c) => {
      const hit = await c.match(req); if (hit) return hit;
      const r = await fetch(req); if (r.ok || r.type === 'opaque') { c.put(req, r.clone()); trimTiles(); } return r;
    }));
    return;
  }
  if (url.hostname === 'raw.githubusercontent.com' && url.pathname.includes('/grid-live/')) {
    e.respondWith(fetch(req).then(async (r) => { const c = await caches.open(VERSION); c.put(url.origin + url.pathname, r.clone()); return r; })
      .catch(async () => (await caches.open(VERSION)).match(url.origin + url.pathname)));
  }
});
