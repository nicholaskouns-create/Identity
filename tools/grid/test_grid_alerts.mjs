// Checks grid-alerts against independent references.
//   1. Message encryption (RFC 8291 / RFC 8188): byte-for-byte equal to http_ece with the same keys and salt,
//      and decryptable by http_ece with a fresh random key.
//   2. VAPID (RFC 8292): the JWT verifies under the public key, with the claims push services expect,
//      and web-push's own header passes the same verifier.
//   3. Alert logic: county totals, thresholds with hysteresis, restore notices, NWS SAME matching, dedupe,
//      the push-host allowlist and subscription validation.
//   4. The whole function end to end under Node, against an in-memory database, fixture ODIN and NWS feeds,
//      and a fake push service that decrypts every message with http_ece and checks its VAPID signature.
// Usage: node tools/grid/test_grid_alerts.mjs [path-to-node_modules containing web-push and http_ece]
import { readFileSync, writeFileSync, mkdtempSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { tmpdir } from 'node:os';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { createRequire } from 'node:module';
import nodeCrypto from 'node:crypto';
import assert from 'node:assert/strict';

const here = dirname(fileURLToPath(import.meta.url));
const src = join(here, 'supabase', 'grid-alerts');
const tmp = mkdtempSync(join(tmpdir(), 'grid-alerts-'));
for (const f of ['webpush', 'logic', 'index']) {
  const code = readFileSync(join(src, `${f}.ts`), 'utf8').replace(/from '\.\/(\w+)\.ts'/g, "from './$1.mjs'");
  writeFileSync(join(tmp, `${f}.mjs`), code);
}
const wp = await import(pathToFileURL(join(tmp, 'webpush.mjs')).href);
const L = await import(pathToFileURL(join(tmp, 'logic.mjs')).href);
const mods = process.argv[2] || '/tmp/wpt/node_modules';
const req = createRequire(join(mods, 'x.js'));
const ece = req('http_ece'), webpush = req('web-push');
const subtle = globalThis.crypto.subtle;
const B = (u8) => Buffer.from(u8);
let n = 0; const ok = (m) => { n++; console.log('  ok', m); };

// ---- 1. encryption ----------------------------------------------------------------------------------
const ua = nodeCrypto.createECDH('prime256v1'); ua.generateKeys();
const auth = nodeCrypto.randomBytes(16);
const p256dh = wp.b64u.enc(ua.getPublicKey()), authB = wp.b64u.enc(auth);
const sender = nodeCrypto.createECDH('prime256v1'); sender.generateKeys();
const sp = sender.getPublicKey();
const jwk = { kty: 'EC', crv: 'P-256', x: wp.b64u.enc(sp.subarray(1, 33)), y: wp.b64u.enc(sp.subarray(33, 65)), d: wp.b64u.enc(sender.getPrivateKey()) };
const asKeys = {
  privateKey: await subtle.importKey('jwk', jwk, { name: 'ECDH', namedCurve: 'P-256' }, false, ['deriveBits']),
  publicKey: await subtle.importKey('raw', sp, { name: 'ECDH', namedCurve: 'P-256' }, true, []),
};
const salt = nodeCrypto.randomBytes(16);
const msg = JSON.stringify({ title: 'Power outage · Clark County, NV', body: '12,345 customers out · NV Energy', url: 'https://example.org/grid/?county=32003' });
const ours = await wp.encrypt(msg, p256dh, authB, { asKeys, salt: new Uint8Array(salt) });
const ref = ece.encrypt(Buffer.from(msg), { version: 'aes128gcm', privateKey: sender, dh: wp.b64u.enc(ua.getPublicKey()), authSecret: wp.b64u.enc(auth), salt: wp.b64u.enc(salt), rs: 4096 });
assert.equal(B(ours).toString('hex'), ref.toString('hex'));
ok(`aes128gcm body identical to http_ece (${ours.length} bytes)`);
for (let i = 0; i < 25; i++) {
  const text = 'x'.repeat(i * 97) + msg;
  const body = await wp.encrypt(text, p256dh, authB);
  const plain = ece.decrypt(B(body), { version: 'aes128gcm', privateKey: ua, authSecret: wp.b64u.enc(auth) });
  assert.equal(plain.toString(), text);
}
ok('25 random-key messages decrypt with http_ece');
await assert.rejects(wp.encrypt('x', wp.b64u.enc(new Uint8Array(64)), authB), /uncompressed/);
ok('rejects a malformed p256dh');

// ---- 2. VAPID ---------------------------------------------------------------------------------------
const vk = await subtle.generateKey({ name: 'ECDSA', namedCurve: 'P-256' }, true, ['sign', 'verify']);
const privateJwk = await subtle.exportKey('jwk', vk.privateKey);
const publicKey = wp.b64u.enc(await subtle.exportKey('raw', vk.publicKey));
const subject = 'https://nicholaskouns-create.github.io/Identity/grid/';
async function verifyVapid(header, endpoint, pub) {
  const m = /^vapid t=([^,]+), k=(.+)$/.exec(header); assert.ok(m, 'header shape');
  assert.equal(m[2], pub);
  const [h, b, s] = m[1].split('.');
  const key = await subtle.importKey('raw', wp.b64u.dec(pub), { name: 'ECDSA', namedCurve: 'P-256' }, false, ['verify']);
  assert.ok(await subtle.verify({ name: 'ECDSA', hash: 'SHA-256' }, key, wp.b64u.dec(s), new TextEncoder().encode(`${h}.${b}`)), 'signature');
  const head = JSON.parse(new TextDecoder().decode(wp.b64u.dec(h))), claims = JSON.parse(new TextDecoder().decode(wp.b64u.dec(b)));
  assert.equal(head.alg, 'ES256');
  assert.equal(claims.aud, new URL(endpoint).origin);
  assert.ok(claims.exp > Date.now() / 1000 && claims.exp <= Date.now() / 1000 + 86400, 'exp within 24 h');
  return claims;
}
for (const ep of ['https://fcm.googleapis.com/fcm/send/abc', 'https://web.push.apple.com/QK1', 'https://updates.push.services.mozilla.com/wpush/v2/gAAA']) {
  const claims = await verifyVapid(await wp.vapidHeader(ep, privateJwk, publicKey, subject), ep, publicKey);
  assert.equal(claims.sub, subject);
}
ok('our VAPID JWT verifies for FCM, Apple and Mozilla audiences');
const wk = webpush.generateVAPIDKeys();
const wh = webpush.getVapidHeaders('https://fcm.googleapis.com', 'mailto:test@example.org', wk.publicKey, wk.privateKey, 'aes128gcm');
await verifyVapid(wh.Authorization, 'https://fcm.googleapis.com/fcm/send/x', wk.publicKey);
ok("web-push's VAPID header passes the same verifier");

// ---- 3. logic ---------------------------------------------------------------------------------------
const odin = { outage: [
  { communityDescriptor: '32003', metersAffected: 9000, names: [{ name: 'NV Energy', nameType: 'UtilityName' }], estimatedRestorationTime: { ert: '2026-11-22T23:00:00Z' } },
  { communityDescriptor: '32003', metersAffected: 3345, names: [{ name: 'NV Energy', nameType: 'UtilityName' }] },
  { communityDescriptor: '21049', metersAffected: 4, names: [{ name: 'CLARK ENERGY COOP INC', nameType: 'UtilityName' }] },
  { communityDescriptor: '6037', metersAffected: 700, names: [{ name: 'LADWP', nameType: 'UtilityName' }] },
  { communityDescriptor: 'bogus', metersAffected: 5 },
] };
const tot = L.countyTotals(odin);
assert.equal(tot.get('32003').customers, 12345); assert.equal(tot.get('32003').util, 'NV Energy');
assert.equal(tot.get('06037').customers, 700); assert.equal(tot.has('bogus'), false);
ok('ODIN county totals (FIPS padded, junk dropped)');

const now = Date.parse('2026-11-22T20:00:00Z');
const place = { fips: '32003', label: 'Clark County, NV' };
let st = {};
let r = L.outageStep(st, place, tot, 10, true, now);
assert.equal(r.notes.length, 1); assert.match(r.notes[0].title, /^Power outage · Clark County, NV/); assert.match(r.notes[0].body, /12,345 customers out · NV Energy/); assert.match(r.notes[0].body, /about 3 h/);
st = r.state;
r = L.outageStep(st, place, tot, 10, true, now + 3e5); assert.equal(r.notes.length, 0, 'no repeat while out');
const low = new Map([['32003', { customers: 3, events: 1, util: 'NV Energy' }]]);
r = L.outageStep(r.state, place, low, 10, true, now + 6e5); assert.equal(r.notes.length, 0, 'one low sweep is not yet a restore');
r = L.outageStep(r.state, place, tot, 10, true, now + 9e5); assert.equal(r.notes.length, 0, 'bounce back up: still the same outage');
r = L.outageStep(r.state, place, low, 10, true, now + 12e5); assert.equal(r.notes.length, 0);
r = L.outageStep(r.state, place, new Map(), 10, true, now + 15e5); assert.equal(r.notes.length, 1); assert.match(r.notes[0].title, /^Power restored/); assert.match(r.notes[0].body, /still out/);
r = L.outageStep(r.state, place, new Map(), 10, true, now + 18e5); assert.equal(r.notes.length, 0);
ok('outage → no repeats → two low sweeps → one restore notice');
r = L.outageStep({}, { fips: '21049', label: 'Clark County, KY' }, tot, 10, true, now); assert.equal(r.notes.length, 0, '4 out is under 10');
r = L.outageStep({}, { fips: '21049', label: 'Clark County, KY' }, tot, 1, true, now); assert.equal(r.notes.length, 1, 'medical threshold 1 catches 4');
assert.match(r.notes[0].body, /^4 customers out · Clark Energy Coop Inc\./);
ok('threshold respected; threshold 1 alerts on small outages');
r = L.outageStep({}, place, null, 10, true, now); assert.equal(r.notes.length, 0); assert.deepEqual(r.state, {});
const held = L.outageStep({}, place, tot, 10, true, now).state;
r = L.outageStep(held, place, null, 10, true, now + 3e5); assert.equal(r.notes.length, 0, 'a failed ODIN fetch never reads as restored'); assert.deepEqual(r.state, held);
ok('ODIN outage of its own is never reported as power restored');

const nws = { features: [
  { id: 'https://api.weather.gov/alerts/urn:a1', properties: { event: 'Tornado Warning', severity: 'Extreme', status: 'Actual', messageType: 'Alert', headline: 'Tornado Warning issued November 22 at 2:05PM CST until 2:45PM CST by NWS Louisville KY', expires: '2026-11-22T20:45:00Z', geocode: { SAME: ['021049', '021067'] } } },
  { id: 'https://api.weather.gov/alerts/urn:a2', properties: { event: 'Wind Advisory', severity: 'Moderate', status: 'Actual', messageType: 'Alert', headline: 'Wind Advisory', expires: '2026-11-22T23:00:00Z', geocode: { SAME: ['021049'] } } },
  { id: 'https://api.weather.gov/alerts/urn:a3', properties: { event: 'Extreme Heat Warning', severity: 'Severe', status: 'Actual', messageType: 'Alert', headline: 'Extreme Heat Warning', expires: '2026-11-23T03:00:00Z', geocode: { SAME: ['032003'] } } },
  { id: 'https://api.weather.gov/alerts/urn:a4', properties: { event: 'Tornado Warning', severity: 'Extreme', status: 'Test', messageType: 'Alert', headline: 'TEST', expires: '2026-11-22T23:00:00Z', geocode: { SAME: ['021049'] } } },
] };
const wx = L.weatherIndex(nws);
assert.deepEqual([...wx.keys()].sort(), ['21049', '21067', '32003']);
const ky = { fips: '21049', label: 'Clark County, KY' };
r = L.weatherStep({}, ky, wx, now); assert.equal(r.notes.length, 1); assert.match(r.notes[0].title, /^Tornado Warning · Clark County, KY/); assert.equal(r.notes[0].urgency, 'high');
r = L.weatherStep(r.state, ky, wx, now + 3e5); assert.equal(r.notes.length, 0, 'same warning is not sent twice');
const upd = L.weatherIndex({ features: [{ id: 'https://api.weather.gov/alerts/urn:a1-ext', properties: { ...nws.features[0].properties, messageType: 'Update', expires: '2026-11-22T21:15:00Z' } }] });
r = L.weatherStep(r.state, ky, upd, now + 6e5); assert.equal(r.notes.length, 0, 'an extension under a new id is not a new alert');
assert.equal(r.state.wx['Tornado Warning|21049'], Date.parse('2026-11-22T21:15:00Z'), 'extended expiry carried forward');
const later = L.weatherStep(r.state, ky, wx, Date.parse('2026-11-22T21:30:00Z')); assert.equal(later.notes.length, 1, 'same event after the first has ended alerts again');
r = L.weatherStep(r.state, ky, new Map(), Date.parse('2026-11-23T05:00:00Z')); assert.deepEqual(r.state.wx || {}, {}, 'expired ids are forgotten');
ok('NWS: severe/extreme warnings only, real messages only, SAME→FIPS, sent once per event and county, extensions silent');
const plan = L.planSub({ places: [place, ky], min_out: 10, weather: true, restore: true, state: {} }, tot, wx, now);
assert.deepEqual(plan.notes.map((x) => x.kind), ['outage', 'weather', 'weather']); assert.equal(plan.changed, true);
const again = L.planSub({ places: [place, ky], min_out: 10, weather: true, restore: true, state: plan.state }, tot, wx, now + 3e5);
assert.equal(again.notes.length, 0); assert.equal(again.changed, false);
ok('a subscriber with two counties: outage + heat + tornado once, then nothing and no write');

for (const good of ['https://fcm.googleapis.com/fcm/send/x', 'https://web.push.apple.com/abc', 'https://updates.push.services.mozilla.com/wpush/v2/x', 'https://wns2-by3p.notify.windows.com/w/?token=x'])
  assert.equal(L.allowedEndpoint(good), true, good);
for (const bad of ['http://fcm.googleapis.com/x', 'https://evil.example/fcm.googleapis.com', 'https://fcm.googleapis.com.evil.example/x', 'https://169.254.169.254/latest', 'https://localhost/x', 'https://user@fcm.googleapis.com/x', 'https://fcm.googleapis.com:8443/x', 'nonsense'])
  assert.equal(L.allowedEndpoint(bad), false, bad);
ok('push endpoint allowlist (https, known push services, no ports, no userinfo, no look-alikes)');
const sub = { endpoint: 'https://fcm.googleapis.com/fcm/send/x', keys: { p256dh, auth: authB } };
let v = L.cleanSubscribe({ subscription: sub, places: [place, { fips: '21049', label: 'Clark County, KY' }, { fips: '9999999', label: 'x' }], minOut: 1, weather: true, restore: false });
assert.equal(v.ok, true); assert.equal(v.row.places.length, 2); assert.equal(v.row.min_out, 1); assert.equal(v.row.restore, false);
assert.equal(L.cleanSubscribe({ subscription: { ...sub, endpoint: 'https://evil.example/x' }, places: [place] }).ok, false);
assert.equal(L.cleanSubscribe({ subscription: sub, places: [] }).ok, false);
v = L.cleanSubscribe({ subscription: sub, places: Array.from({ length: 9 }, (_, i) => ({ fips: String(32001 + 2 * i), label: '<b>x</b>'.repeat(40) })), minOut: -4 });
assert.equal(v.row.places.length, 5); assert.ok(v.row.places[0].label.length <= 60 && !/[<>]/.test(v.row.places[0].label)); assert.equal(v.row.min_out, 1);
ok('subscription cleaning: ≤5 counties, 5-digit FIPS, labels plain and short, threshold clamped');


// ---- 4. end to end ----------------------------------------------------------------------------------
const SB = 'https://proj.supabase.co';
let handler = null;
globalThis.Deno = { env: { get: (k) => ({ SUPABASE_URL: SB, SUPABASE_SERVICE_ROLE_KEY: 'srk' })[k] }, serve: (h) => { handler = h; } };
const DB = { grid_alert_config: [{ id: 1, vapid_public: null, vapid_private_jwk: null, sweep_token: 'tok-' + 'a'.repeat(60), last_sweep: null }], grid_push_subs: [] };
const inbox = []; // { endpoint, payload, claims }
const devices = new Map(); // endpoint -> { ecdh, auth, status }
// Live-clock copies of the NWS fixture, so this section passes whatever day it runs.
const nwsLive = { features: nws.features.map((f) => ({ ...f, properties: { ...f.properties, expires: new Date(Date.now() + 2 * 3600e3).toISOString() } })) };
let feeds = { odin: odin, nws: nwsLive, odinFails: false };
const realFetch = globalThis.fetch;
const reply = (o, status = 200) => new Response(o === null ? null : JSON.stringify(o), { status });
function matches(row, q) {
  for (const [k, v] of q) {
    if (['select', 'order', 'limit', 'offset', 'on_conflict'].includes(k)) continue;
    if (v.startsWith('eq.') && String(row[k]) !== v.slice(3)) return false;
    if (v === 'is.null' && row[k] != null) return false;
    if (v.startsWith('gt.') && !(String(row[k]) > v.slice(3))) return false;
  }
  return true;
}
globalThis.fetch = async (url, init = {}) => {
  const u = new URL(url), method = (init.method || 'GET').toUpperCase();
  if (u.origin === SB) {
    assert.equal(init.headers.authorization, 'Bearer srk');
    const table = u.pathname.replace('/rest/v1/', ''), q = [...u.searchParams.entries()], rows = DB[table];
    const body = init.body ? JSON.parse(init.body) : null, rep = /return=representation/.test(init.headers.prefer || '');
    if (method === 'GET') {
      const lim = +(u.searchParams.get('limit') || 1e9), off = +(u.searchParams.get('offset') || 0);
      return reply(rows.filter((r) => matches(r, q)).sort((a, b) => String(a.id).localeCompare(String(b.id))).slice(off, off + lim).map((r) => structuredClone(r)));
    }
    if (method === 'PATCH') { const hit = rows.filter((r) => matches(r, q)); hit.forEach((r) => Object.assign(r, body)); return rep ? reply(hit) : reply(null, 204); }
    if (method === 'DELETE') { DB[table] = rows.filter((r) => !matches(r, q)); return reply(null, 204); }
    if (method === 'POST') { const ex = rows.find((r) => r.id === body.id); if (ex) Object.assign(ex, body); else rows.push({ state: {}, fails: 0, last_test_at: null, ...body }); return reply(null, 201); }
  }
  if (u.host === 'odin.ornl.gov') { if (feeds.odinFails) throw new Error('connect timeout'); return reply(feeds.odin); }
  if (u.host === 'api.weather.gov') { assert.match(init.headers['user-agent'], /Grid/); return reply(feeds.nws); }
  const dev = devices.get(String(url));
  if (dev) {
    assert.equal(init.headers['Content-Encoding'], 'aes128gcm');
    const claims = await verifyVapid(init.headers.Authorization, String(url), DB.grid_alert_config[0].vapid_public);
    const plain = ece.decrypt(B(init.body), { version: 'aes128gcm', privateKey: dev.ecdh, authSecret: wp.b64u.enc(dev.auth) });
    inbox.push({ endpoint: String(url), payload: JSON.parse(plain.toString()), claims, ttl: +init.headers.TTL });
    return new Response(dev.status === 201 ? '' : 'nope', { status: dev.status });
  }
  throw new Error('unexpected fetch ' + url);
};
function device(endpoint, status = 201) {
  const ecdh = nodeCrypto.createECDH('prime256v1'); ecdh.generateKeys();
  const auth = nodeCrypto.randomBytes(16);
  devices.set(endpoint, { ecdh, auth, status });
  return { endpoint, keys: { p256dh: wp.b64u.enc(ecdh.getPublicKey()), auth: wp.b64u.enc(auth) } };
}
await import(pathToFileURL(join(tmp, 'index.mjs')).href);
assert.equal(typeof handler, 'function');
const call = async (op, body, headers = {}) => {
  const r = await handler(new Request(`${SB}/functions/v1/grid-alerts?op=${op}`, body === undefined ? { method: 'GET' } : { method: 'POST', headers: { 'content-type': 'application/json', ...headers }, body: JSON.stringify(body) }));
  return { status: r.status, body: await r.json() };
};
let res = await call('key');
assert.equal(res.status, 200); assert.equal(wp.b64u.dec(res.body.publicKey).length, 65);
const pub = res.body.publicKey;
assert.equal((await call('key')).body.publicKey, pub);
ok('application server key generated once, stored, served');

const phone = device('https://fcm.googleapis.com/fcm/send/phone-1');
res = await call('subscribe', { subscription: phone, places: [place], minOut: 10, weather: true, restore: true });
assert.equal(res.status, 200); assert.equal(res.body.confirmed, true);
assert.equal(inbox.length, 1); assert.equal(inbox[0].payload.title, 'Grid alerts are on'); assert.match(inbox[0].payload.body, /Clark County, NV/);
assert.equal(inbox[0].claims.aud, 'https://fcm.googleapis.com'); assert.equal(inbox[0].claims.sub, L.GRID);
assert.equal(DB.grid_push_subs.length, 1);
const row = DB.grid_push_subs[0];
assert.deepEqual(Object.keys(row).sort(), ['auth', 'endpoint', 'fails', 'id', 'last_test_at', 'min_out', 'p256dh', 'places', 'restore', 'state', 'updated_at', 'weather']);
res = await call('subscribe', { subscription: phone, places: [place, ky], minOut: 1, weather: true, restore: true });
assert.equal(res.body.confirmed, false); assert.equal(inbox.length, 1, 'no second confirmation'); assert.equal(DB.grid_push_subs[0].min_out, 1); assert.equal(DB.grid_push_subs[0].places.length, 2);
ok('subscribe: confirmation push decrypts and verifies; settings update in place; only the listed columns are stored');

const bad = device('https://fcm.googleapis.com/fcm/send/refuses', 400);
res = await call('subscribe', { subscription: bad, places: [place] });
assert.equal(res.status, 400); assert.equal(DB.grid_push_subs.length, 1);
res = await call('subscribe', { subscription: { ...phone, endpoint: 'https://example.org/push' }, places: [place] });
assert.equal(res.status, 400);
ok('a subscription the push service refuses, or one that is not a push service, is never stored');

res = await call('test', { endpoint: phone.endpoint });
assert.equal(res.status, 200); assert.equal(inbox.at(-1).payload.title, 'Grid test alert');
assert.equal((await call('test', { endpoint: phone.endpoint })).status, 429);
assert.equal((await call('test', { endpoint: 'https://fcm.googleapis.com/fcm/send/nobody' })).status, 404);
ok('test alert: delivered, then limited to one a minute; unknown endpoints get 404');

const tok = DB.grid_alert_config[0].sweep_token;
assert.equal((await call('sweep', {}, {})).status, 403);
assert.equal((await call('sweep', {}, { 'x-grid-sweep': tok.slice(0, -1) + 'b' })).status, 403);
const gone = device('https://web.push.apple.com/gone-1', 410);
DB.grid_push_subs.push({ id: 'zz', endpoint: gone.endpoint, p256dh: gone.keys.p256dh, auth: gone.keys.auth, places: [place], min_out: 10, weather: true, restore: true, state: {}, fails: 0 });
let before = inbox.length;
res = await call('sweep', {}, { 'x-grid-sweep': tok });
assert.equal(res.status, 200);
const got = inbox.slice(before).filter((m) => m.endpoint === phone.endpoint).map((m) => m.payload.title);
assert.deepEqual(got.sort(), ['Extreme Heat Warning · Clark County, NV', 'Power outage · Clark County, NV', 'Power outage · Clark County, KY', 'Tornado Warning · Clark County, KY'].sort());
assert.equal(DB.grid_push_subs.some((r) => r.id === 'zz'), false, 'gone subscription deleted');
assert.equal(res.body.removed, 1); assert.ok(DB.grid_alert_config[0].last_sweep.at);
ok('sweep: token required; outages at threshold 1 in both counties, heat and tornado warnings; a gone endpoint is deleted');

before = inbox.length;
await call('sweep', {}, { 'x-grid-sweep': tok });
assert.equal(inbox.length, before, 'nothing repeats');
feeds.odinFails = true;
await call('sweep', {}, { 'x-grid-sweep': tok });
await call('sweep', {}, { 'x-grid-sweep': tok });
assert.equal(inbox.length, before, 'ODIN down: no restore notices');
feeds = { odin: { outage: [] }, nws: { features: [] }, odinFails: false };
await call('sweep', {}, { 'x-grid-sweep': tok });
assert.equal(inbox.length, before, 'first clear sweep: wait');
await call('sweep', {}, { 'x-grid-sweep': tok });
assert.deepEqual(inbox.slice(before).map((m) => m.payload.title).sort(), ['Power restored · Clark County, KY', 'Power restored · Clark County, NV']);
ok('sweep: silence while out, silence while ODIN is down, restore notices after two clear sweeps');

devices.get(phone.endpoint).status = 503;
feeds = { odin, nws: nwsLive, odinFails: false };
before = inbox.length;
const st0 = JSON.stringify(DB.grid_push_subs[0].state);
await call('sweep', {}, { 'x-grid-sweep': tok });
assert.equal(JSON.stringify(DB.grid_push_subs[0].state), st0, 'state kept when the push service is down');
devices.get(phone.endpoint).status = 201;
await call('sweep', {}, { 'x-grid-sweep': tok });
assert.ok(inbox.slice(before).filter((m) => /Power outage/.test(m.payload.title)).length >= 2, 'retried on the next sweep');
ok('a push service outage delays the notice to the next sweep instead of losing it');

assert.equal((await call('unsubscribe', { endpoint: phone.endpoint })).status, 200);
assert.equal(DB.grid_push_subs.length, 0);
ok('unsubscribe deletes the row');
globalThis.fetch = realFetch;

console.log(`grid-alerts: ${n} checks passed`);
