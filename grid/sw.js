// Grid service worker: the instrument shell, its pinned data and visited map
// tiles work offline. Live publisher APIs are never answered from cache, so an
// offline Grid shows sources as unavailable rather than presenting old values
// as current. The relay snapshot carries its own generation time and may be cached.
// It also shows Grid's background alerts (Web Push from the grid-alerts edge function)
// and opens Grid at the county a notification is about.
const VERSION = 'grid-2026-11-27-radar-1';
const PREFS = 'grid-prefs';
const ALERTS_URL = 'https://gpkjvihkyectnenvnbng.supabase.co/functions/v1/grid-alerts';
// The City project's public anon key: it names the project and grants only public access.
const ANON = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imdwa2p2aWhreWVjdG5lbnZuYm5nIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODUxNzYwOTYsImV4cCI6MjEwMDc1MjA5Nn0.WLsj1N9akCxpNVAIPj43fO9InCTHRuNz1WTPDNyuOVM';
const SHELL = [
  './', 'index.html', 'grid.css', 'app.js', 'manifest.webmanifest', 'door.js',
  'live/radar.js', 'map/map.js', 'map/fly.js', 'live/sources.js', 'live/pulse.js', 'live/alerts.js', 'live/water.js', 'live/counties.js', 'live/enf.js', 'live/enf-worklet.js', 'ui/charts.js', 'ui/panels.js', 'ui/pages.js',
  'engine/prng.js', 'engine/linalg.js', 'engine/monitor.js', 'engine/rational.js', 'engine/certificate.js', 'engine/e47.js', 'engine/worker.js', 'engine/pins.js',
  'lib/maplibre/maplibre-gl.mjs', 'lib/maplibre/maplibre-gl-worker.mjs', 'lib/maplibre/maplibre-gl.css',
  'data/topology-ieee14.json', 'data/topology-ieee118.json', 'data/certificate-ieee14.json', 'data/certificate-ieee118.json',
  'data/cm2-survey-ieee14.json', 'data/cm2-survey-ieee118.json', 'data/reference-acceptance.json',
  'data/plants-us.json', 'data/us-states.json', 'data/us-counties-10m.json', 'data/ba-meta.json',
  'fonts/newsreader-latin-400-normal.woff2', 'fonts/newsreader-latin-400-italic.woff2', 'fonts/newsreader-latin-500-normal.woff2', 'fonts/newsreader-latin-500-italic.woff2',
  'fonts/ibm-plex-sans-latin-400-normal.woff2', 'fonts/ibm-plex-sans-latin-500-normal.woff2', 'fonts/ibm-plex-sans-latin-600-normal.woff2',
  'fonts/ibm-plex-sans-greek-400-normal.woff2', 'fonts/ibm-plex-sans-greek-500-normal.woff2',
  'fonts/ibm-plex-mono-latin-400-normal.woff2', 'fonts/ibm-plex-mono-latin-500-normal.woff2', 'fonts/ibm-plex-mono-latin-600-normal.woff2',
  'fonts/dejavu-sans-mono-math.woff2', 'cover-grid.jpg', 'icons/grid.svg', 'icons/grid-192.png', 'icons/grid-512.png', 'icons/badge-96.png',
];
const TILE_HOSTS = ['server.arcgisonline.com', 's3.amazonaws.com', 'gibs.earthdata.nasa.gov', 'demotiles.maplibre.org'];
const TILE_CACHE = 'grid-tiles-v1', TILE_LIMIT = 2500;

self.addEventListener('install', (e) => {
  e.waitUntil(caches.open(VERSION).then((c) => c.addAll(SHELL)).then(() => self.skipWaiting()));
});
self.addEventListener('activate', (e) => {
  e.waitUntil(caches.keys().then((ks) => Promise.all(ks.filter((k) => k !== VERSION && k !== TILE_CACHE && k !== PREFS).map((k) => caches.delete(k)))).then(() => self.clients.claim()));
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

// ----------------------------------------------------------------- alerts
self.addEventListener('push', (e) => {
  let d = {};
  try { d = e.data ? e.data.json() : {}; } catch { d = { body: e.data ? e.data.text() : '' }; }
  const urgent = d.kind === 'outage' || d.kind === 'weather';
  e.waitUntil(self.registration.showNotification(d.title || 'Grid', {
    body: d.body || '', tag: d.tag || 'grid', renotify: true, requireInteraction: urgent,
    icon: 'icons/grid-192.png', badge: 'icons/badge-96.png', timestamp: d.ts || Date.now(),
    vibrate: urgent ? [240, 120, 240, 120, 480] : [120],
    data: { url: d.url || self.registration.scope },
  }));
});

self.addEventListener('notificationclick', (e) => {
  e.notification.close();
  const url = new URL((e.notification.data && e.notification.data.url) || './', self.registration.scope).href;
  e.waitUntil((async () => {
    const wins = await self.clients.matchAll({ type: 'window', includeUncontrolled: true });
    const w = wins.find((c) => c.url.startsWith(self.registration.scope));
    if (w) { await w.focus(); w.postMessage({ type: 'grid-open', url }); return; }
    await self.clients.openWindow(url);
  })());
});

// When the browser rotates a push subscription, carry the same counties and choices over to the new one.
self.addEventListener('pushsubscriptionchange', (e) => {
  e.waitUntil((async () => {
    const prefs = await caches.open(PREFS).then((c) => c.match('alerts.json')).then((r) => (r ? r.json() : null)).catch(() => null);
    if (!prefs || !prefs.on || !prefs.places || !prefs.places.length) return;
    const call = (op, body) => fetch(`${ALERTS_URL}?op=${op}`, { method: body ? 'POST' : 'GET', headers: { Authorization: `Bearer ${ANON}`, apikey: ANON, 'content-type': 'application/json' }, body: body ? JSON.stringify(body) : undefined }).then((r) => r.json());
    let sub = e.newSubscription;
    if (!sub) {
      let key = e.oldSubscription && e.oldSubscription.options && e.oldSubscription.options.applicationServerKey;
      if (!key) { const t = (await call('key')).publicKey.replace(/-/g, '+').replace(/_/g, '/'); key = Uint8Array.from(atob(t + '==='.slice((t.length + 3) % 4)), (c) => c.charCodeAt(0)); }
      sub = await self.registration.pushManager.subscribe({ userVisibleOnly: true, applicationServerKey: key });
    }
    if (e.oldSubscription && e.oldSubscription.endpoint !== sub.endpoint) await call('unsubscribe', { endpoint: e.oldSubscription.endpoint }).catch(() => {});
    await call('subscribe', { subscription: sub.toJSON(), places: prefs.places, minOut: prefs.minOut, weather: prefs.weather, restore: prefs.restore });
  })().catch(() => {}));
});
