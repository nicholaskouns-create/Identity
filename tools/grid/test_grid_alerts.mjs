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
// ODIN fixtures in the feed's own shape (each utility named and identified by EIA id), and feed status as
// /odi/status returns it.
const U = (name, id) => [{ name, nameType: 'UtilityName' }, { name: id, nameType: 'UtilityId' }];
const odin = { outage: [
  { communityDescriptor: '32003', metersAffected: 9000, names: U('NV Energy', '13407'), estimatedRestorationTime: { ert: '2026-11-22T23:00:00Z' } },
  { communityDescriptor: '32003', metersAffected: 3345, names: U('NV Energy', '13407') },
  { communityDescriptor: '21049', metersAffected: 4, names: U('CLARK ENERGY COOP INC', '3632') },
  { communityDescriptor: '6037', metersAffected: 700, names: U('LADWP', '11208') },
  { communityDescriptor: 'bogus', metersAffected: 5 },
] };
const tot = L.countyTotals(odin);
assert.equal(tot.get('32003').customers, 12345); assert.equal(tot.get('32003').util, 'NV Energy'); assert.deepEqual([...tot.get('32003').utils], ['13407']);
assert.equal(tot.get('06037').customers, 700); assert.equal(tot.has('bogus'), false);
for (const odd of [{}, [], { outages: [] }, { error: 'maintenance' }, { outage: [] }, { outage: 'none' }, null, { outage: [{ foo: 1 }, { bar: 2 }, { communityDescriptor: '32003', metersAffected: 3 }] }])
  assert.equal(L.countyTotals(odd), null, JSON.stringify(odd));
assert.equal(L.feedStatus({}), null); assert.equal(L.feedStatus([]), null);
ok('ODIN: county totals with utility ids; any response that is not a readable, non-empty ODIN feed means "cannot be trusted", never "no outages"');

const now = Date.parse('2026-11-22T20:00:00Z');
const place = { fips: '32003', label: 'Clark County, NV' };
const statusAt = (at, err = false) => L.feedStatus([['13407', err], ['3632', false], ['11208', false]].map(([eiaId, hasError]) => ({ eiaId, hasError, receivedDate: new Date(at).toISOString(), name: 'feed ' + eiaId })));
const feed = (n) => L.countyTotals({ outage: [...(n ? [{ communityDescriptor: '32003', metersAffected: n, names: U('NV Energy', '13407') }] : []), { communityDescriptor: '06037', metersAffected: 50, names: U('LADWP', '11208') }] });
// One county through a list of [odin, minutes later] readings, every planned notice delivered.
function run(readings, minOut = 10, restore = true) {
  let s = {}; const notes = [];
  for (const [o, min] of readings) { const r = L.outageStep(s, place, o, minOut, restore, now + min * 60e3); s = L.commit(r.state, r.notes); notes.push(r.notes); }
  return { s, notes, titles: notes.map((ns) => ns.map((x) => x.title)) };
}
const live = (n, min, err = false) => [{ totals: feed(n), status: statusAt(now + (min - 1) * 60e3, err) }, min];

let r = L.outageStep({}, place, { totals: tot, status: statusAt(now - 60e3) }, 10, true, now);
assert.equal(r.notes.length, 1); assert.match(r.notes[0].title, /^Power outage · Clark County, NV/); assert.match(r.notes[0].body, /12,345 customers out · NV Energy/); assert.match(r.notes[0].body, /about 3 h/); assert.match(r.notes[0].body, /20\+ ft/);
assert.deepEqual(r.state, {}, 'an alert is recorded only once it is delivered');
r = L.outageStep({}, { fips: '21049', label: 'Clark County, KY' }, { totals: tot, status: null }, 10, true, now); assert.equal(r.notes.length, 0, '4 out is under 10');
r = L.outageStep({}, { fips: '21049', label: 'Clark County, KY' }, { totals: tot, status: null }, 1, true, now); assert.equal(r.notes.length, 1, 'threshold 1 catches 4');
assert.match(r.notes[0].body, /^4 customers out · Clark Energy Coop Inc\./);
ok('outage alert at the threshold, with utility, estimate and the generator line; threshold 1 catches small outages');

// Review case 1: threshold 10,000, then two readings of 4,999. Nothing may say "restored".
let x = run([live(12000, 0), live(4999, 5), live(4999, 10)], 10000);
assert.deepEqual(x.titles, [['Power outage · Clark County, NV'], ['Reported outages down to 4,999 · Clark County, NV'], []]);
assert.match(x.notes[1][0].body, /still reports 4,999 customers out\. Confirm service at your address with NV Energy\./);
assert.ok(!/restor/i.test(JSON.stringify(x.notes)));
ok('review case 1: 12,000 → 4,999 → 4,999 at a 10,000 threshold says "Reported outages down to 4,999" once and never "restored"');
x = run([live(12000, 0), live(4999, 5), live(0, 10), live(0, 15), live(0, 20)], 10000);
assert.deepEqual(x.titles, [['Power outage · Clark County, NV'], ['Reported outages down to 4,999 · Clark County, NV'], [], ['No outages reported · Clark County, NV'], []]);
assert.match(x.notes[3][0].body, /NV Energy reports no outages in Clark County, NV now\. If your power is still out, report it to NV Energy: it may not know about your address\./);
assert.deepEqual(x.s.out, {});
x = run([live(12000, 0), live(4999, 5), live(12500, 10), live(12500, 15)], 10000);
assert.deepEqual(x.titles, [['Power outage · Clark County, NV'], ['Reported outages down to 4,999 · Clark County, NV'], ['Power outage · Clark County, NV'], []]);
x = run([live(12000, 0), live(7000, 5), live(9000, 10)], 10000);
assert.deepEqual(x.titles, [['Power outage · Clark County, NV'], [], []], 'between half the threshold and the threshold: no follow-up');
x = run([live(12000, 0), live(4999, 5), live(0, 10), live(0, 15)], 10000, false);
assert.deepEqual(x.titles, [['Power outage · Clark County, NV'], [], [], []], 'follow-ups off: silent'); assert.deepEqual(x.s.out, {});
ok('falls and clears: "down to" once, "No outages reported" after two verified empty readings, a new alert if it climbs back; all point to the utility');

// Review case 1, second part: a response that is valid JSON but not ODIN's feed, or a feed that cannot vouch for
// the fall, must read as "unavailable", never as zero.
const garbage = { totals: L.countyTotals({ unexpected: true }), status: statusAt(now) };
x = run([live(12000, 0), [garbage, 5], [garbage, 10], [garbage, 15], [garbage, 20], live(12000, 25), live(0, 30), live(0, 35)]);
assert.deepEqual(x.titles, [['Power outage · Clark County, NV'], [], [], ['Outage data unavailable · Clark County, NV'], [], [], [], ['No outages reported · Clark County, NV']]);
assert.match(x.notes[3][0].body, /Grid can't confirm outages here right now: NV Energy's outage feed isn't reporting\. Check with NV Energy for service at your address\./);
const stale = (n, min) => [{ totals: feed(n), status: statusAt(now - 60e3) }, min]; // NV Energy has sent nothing newer
x = run([live(12000, 0), stale(0, 5), stale(0, 10), stale(0, 15)]);
assert.deepEqual(x.titles, [['Power outage · Clark County, NV'], [], [], ['Outage data unavailable · Clark County, NV']], 'a vanished outage with no newer report from its utility is not believed');
x = run([live(12000, 0), live(0, 5, true), live(0, 10, true), live(0, 15, true)]);
assert.deepEqual(x.titles.at(-1), ['Outage data unavailable · Clark County, NV'], 'a utility feed in error is not believed');
const bare = (n, min) => [{ totals: feed(n), status: null }, min]; // ODIN's feed status missing or out of date
x = run([live(12000, 0), bare(4999, 5), bare(4999, 10), bare(0, 15), bare(0, 20), bare(0, 25)], 10000);
assert.deepEqual(x.titles, [['Power outage · Clark County, NV'], [], ['Reported outages down to 4,999 · Clark County, NV'], [], [], ['No outages reported · Clark County, NV']], 'without current feed status, a fall must show on two readings in a row');
x = run([live(12000, 0), bare(0, 5), bare(15000, 10), bare(15000, 15)]);
assert.deepEqual(x.titles, [['Power outage · Clark County, NV'], [], [], []], 'a one-reading dip is not believed; a rise always is');
assert.equal(x.s.out['32003'].n, 15000); assert.equal(x.s.out['32003'].pend, undefined);
assert.equal(L.liveStatus(statusAt(now - 3 * 3600e3), now), null, 'feed status older than two hours vouches for nothing');
const fresh = statusAt(now - 60e3); assert.equal(L.liveStatus(fresh, now), fresh);
assert.equal(L.feedCollapsed(L.countyTotals({ outage: Array.from({ length: 9 }, (_, i) => ({ communityDescriptor: String(32001 + 2 * i), metersAffected: 5 })) }), 130), true);
assert.equal(L.feedCollapsed(tot, 4), false); assert.equal(L.feedCollapsed(null, 130), false);
r = L.outageStep({}, place, { totals: null, status: null }, 10, true, now); assert.deepEqual([r.state, r.notes], [{}, []]);
ok('review case 1: unexpected JSON, a stale utility feed or one in error reads as "Outage data unavailable" after three sweeps, never as zero');

// Review case 3: warnings are known by their NWS identity (VTEC event), not by their name.
const TW = (id, etn, action, exp, more = {}) => ({ id: `https://api.weather.gov/alerts/${id}`, properties: { id, event: 'Tornado Warning', severity: 'Extreme', status: 'Actual', messageType: action === 'NEW' ? 'Alert' : 'Update',
  headline: `Tornado Warning ${etn} issued by NWS Louisville KY`, expires: exp, parameters: { VTEC: [`/O.${action}.KLMK.TO.W.${etn}.261122T2000Z-261122T2045Z/`] }, geocode: { SAME: ['021049', '021067'] }, references: more.refs || [] } });
const ky = { fips: '21049', label: 'Clark County, KY' };
const nws = { features: [
  TW('urn:oid:a1', '0042', 'NEW', '2026-11-22T20:45:00Z'),
  { id: 'https://api.weather.gov/alerts/urn:oid:a2', properties: { id: 'urn:oid:a2', event: 'Wind Advisory', severity: 'Moderate', status: 'Actual', messageType: 'Alert', headline: 'Wind Advisory', expires: '2026-11-22T23:00:00Z', geocode: { SAME: ['021049'] } } },
  { id: 'https://api.weather.gov/alerts/urn:oid:a3', properties: { id: 'urn:oid:a3', event: 'Extreme Heat Warning', severity: 'Severe', status: 'Actual', messageType: 'Alert', headline: 'Extreme Heat Warning', expires: '2026-11-23T03:00:00Z', parameters: { VTEC: ['/O.NEW.KVEF.XH.W.0007.261122T1800Z-261123T0300Z/'] }, geocode: { SAME: ['032003'] } } },
  { id: 'https://api.weather.gov/alerts/urn:oid:a4', properties: { id: 'urn:oid:a4', event: 'Tornado Warning', severity: 'Extreme', status: 'Test', messageType: 'Alert', headline: 'TEST', expires: '2026-11-22T23:00:00Z', geocode: { SAME: ['021049'] } } },
] };
const wx = L.weatherIndex(nws);
assert.deepEqual([...wx.keys()].sort(), ['21049', '21067', '32003']);
assert.equal(L.weatherIndex({ type: 'FeatureCollection' }), null);
let w = { state: {} }, step = (feats, min) => { const z = L.weatherStep(w.state, ky, feats === null ? null : L.weatherIndex({ features: feats }), now + min * 60e3); w = { state: L.commit(z.state, z.notes), notes: z.notes }; return z.notes.map((q) => q.body); };
assert.deepEqual(step(nws.features, 0), ['Tornado Warning 0042 issued by NWS Louisville KY']);
assert.equal(w.notes[0].urgency, 'high'); assert.match(w.notes[0].title, /^Tornado Warning · Clark County, KY$/);
assert.deepEqual(step(nws.features, 5), [], 'the same message again');
assert.deepEqual(step([TW('urn:oid:a1b', '0042', 'CON', '2026-11-22T20:45:00Z', { refs: [{ identifier: 'urn:oid:a1' }] })], 10), [], 'a continuation');
assert.deepEqual(step([TW('urn:oid:a1c', '0042', 'EXT', '2026-11-22T21:15:00Z')], 12), [], 'an extension');
assert.equal(w.state.wx['KLMK.TO.W.0042|21049'].until, Date.parse('2026-11-22T21:15:00Z'), 'extended expiry carried forward');
assert.deepEqual(step([TW('urn:oid:a1c', '0042', 'EXT', '2026-11-22T21:15:00Z'), TW('urn:oid:b1', '0043', 'NEW', '2026-11-22T21:00:00Z')], 15), ['Tornado Warning 0043 issued by NWS Louisville KY'], 'a separate warning while the first is active');
assert.deepEqual(step([TW('urn:oid:a1d', '0042', 'CAN', '2026-11-22T21:15:00Z')], 20), [], 'a cancellation is not a new warning');
const CE = (id, refs = []) => ({ id: `https://api.weather.gov/alerts/${id}`, properties: { id, event: 'Civil Emergency Message', severity: 'Extreme', status: 'Actual', messageType: refs.length ? 'Update' : 'Alert', headline: `Civil emergency ${id}`, expires: '2026-11-22T22:00:00Z', geocode: { SAME: ['021049'] }, references: refs } });
assert.deepEqual(step([CE('urn:oid:c1')], 25), ['Civil emergency urn:oid:c1'], 'no VTEC: a new message');
assert.deepEqual(step([CE('urn:oid:c2', [{ identifier: 'urn:oid:c1' }])], 30), [], 'no VTEC: an update that references it');
assert.deepEqual(step([CE('urn:oid:c3')], 35), ['Civil emergency urn:oid:c3'], 'no VTEC: an unrelated message');
step(null, 60 * 9); assert.deepEqual(Object.keys(w.state.wx), [], 'ended warnings are forgotten an hour after they end');
ok('review case 3: warnings known by VTEC event or references; continuations, extensions and cancellations silent; a separate warning gets through');

// Review case 2, in the planner: notices carry their own state, so one can fail while another is recorded.
const plan = L.planSub({ places: [place, ky], min_out: 1, weather: true, restore: true, state: {} }, { totals: tot, status: statusAt(now - 60e3) }, wx, now);
assert.deepEqual(plan.notes.map((q) => q.kind), ['outage', 'weather', 'outage', 'weather']);
const onlyOutages = L.commit(plan.state, plan.notes.filter((q) => q.kind === 'outage'));
const replan = L.planSub({ places: [place, ky], min_out: 1, weather: true, restore: true, state: onlyOutages }, { totals: tot, status: statusAt(now + 4 * 60e3) }, wx, now + 5 * 60e3);
assert.deepEqual(replan.notes.map((q) => q.title), ['Extreme Heat Warning · Clark County, NV', 'Tornado Warning · Clark County, KY'], 'undelivered warnings are planned again; delivered outages are not');
const settled = L.commit(replan.state, replan.notes);
assert.equal(L.planSub({ places: [place, ky], min_out: 1, weather: true, restore: true, state: settled }, { totals: tot, status: statusAt(now + 9 * 60e3) }, wx, now + 10 * 60e3).notes.length, 0);
ok('review case 2 (planner): each notice records only itself, so an undelivered warning is planned again while it is active');

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
const devices = new Map(); // endpoint -> { ecdh, auth, status: number or (payload) => number }
// Live-clock copies of the fixtures, so this section passes whatever day it runs.
const nwsLive = { features: nws.features.map((f) => ({ ...f, properties: { ...f.properties, expires: new Date(Date.now() + 2 * 3600e3).toISOString() } })) };
const statusNow = (dt = 0) => ['13407', '3632', '11208'].map((eiaId) => ({ eiaId, hasError: false, receivedDate: new Date(Date.now() + dt).toISOString() }));
let feeds = { odin: odin, status: statusNow(-600e3), nws: nwsLive, odinFails: false };
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
  if (u.host === 'odin.ornl.gov') { if (feeds.odinFails) throw new Error('connect timeout'); return reply(u.pathname.endsWith('/status') ? feeds.status : feeds.odin); }
  if (u.host === 'api.weather.gov') { assert.match(init.headers['user-agent'], /Grid/); return reply(feeds.nws); }
  const dev = devices.get(String(url));
  if (dev) {
    assert.equal(init.headers['Content-Encoding'], 'aes128gcm');
    const claims = await verifyVapid(init.headers.Authorization, String(url), DB.grid_alert_config[0].vapid_public);
    const plain = ece.decrypt(B(init.body), { version: 'aes128gcm', privateKey: dev.ecdh, authSecret: wp.b64u.enc(dev.auth) });
    const payload = JSON.parse(plain.toString());
    const status = typeof dev.status === 'function' ? dev.status(payload) : dev.status;
    inbox.push({ endpoint: String(url), payload, claims, ttl: +init.headers.TTL, status });
    return new Response(status === 201 ? '' : 'nope', { status });
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
assert.equal(inbox.at(-1).payload.url, `${L.GRID}?county=32003`, 'tapping the test opens the first county'); assert.match(inbox.at(-1).payload.body, /Tap to open Clark County, NV\./);
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
const titlesSince = (b, ep = phone.endpoint) => inbox.slice(b).filter((m) => m.endpoint === ep && m.status === 201).map((m) => m.payload.title).sort();
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
assert.equal(inbox.length, before, 'ODIN unreachable for two sweeps: silence');
await call('sweep', {}, { 'x-grid-sweep': tok });
assert.deepEqual(titlesSince(before), ['Outage data unavailable · Clark County, KY', 'Outage data unavailable · Clark County, NV']);
assert.ok(!inbox.some((m) => /restor|No outages/i.test(m.payload.title)), 'nothing claims the power is back');
before = inbox.length;
await call('sweep', {}, { 'x-grid-sweep': tok });
assert.equal(inbox.length, before, '"unavailable" is said once');
feeds = { odin: { outage: [{ communityDescriptor: '6037', metersAffected: 700, names: U('LADWP', '11208') }] }, status: statusNow(), nws: { features: [] }, odinFails: false };
await call('sweep', {}, { 'x-grid-sweep': tok });
assert.equal(inbox.length, before, 'first verified empty reading: wait');
await call('sweep', {}, { 'x-grid-sweep': tok });
assert.deepEqual(titlesSince(before), ['No outages reported · Clark County, KY', 'No outages reported · Clark County, NV']);
assert.ok(inbox.slice(before).every((m) => /report it to/.test(m.payload.body)));
ok('sweep: "Outage data unavailable" after three sweeps without ODIN, then "No outages reported" only from verified, newer utility reports');

devices.get(phone.endpoint).status = 503;
feeds = { odin, status: statusNow(), nws: nwsLive, odinFails: false };
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

// Review case 2, end to end: in one sweep the outage notice goes through and the tornado warning meets a
// temporary push-service error. The warning must go out on the next sweep; the outage must not repeat.
const p2 = device('https://web.push.apple.com/phone-2', (m) => (/Tornado/.test(m.title) ? 503 : 201));
const twLive = (id, etn, action, refs) => { const f = TW(id, etn, action, new Date(Date.now() + 2 * 3600e3).toISOString(), { refs }); return f; };
feeds = { odin, status: statusNow(), nws: { features: [twLive('urn:oid:t1', '0042', 'NEW')] }, odinFails: false };
assert.equal((await call('subscribe', { subscription: p2, places: [ky], minOut: 1, weather: true, restore: true })).status, 200);
before = inbox.length;
res = await call('sweep', {}, { 'x-grid-sweep': tok });
assert.deepEqual(titlesSince(before, p2.endpoint), ['Power outage · Clark County, KY']);
assert.equal(res.body.retrying, 1);
devices.get(p2.endpoint).status = 201;
before = inbox.length;
await call('sweep', {}, { 'x-grid-sweep': tok });
assert.deepEqual(titlesSince(before, p2.endpoint), ['Tornado Warning · Clark County, KY'], 'the warning is retried; the outage is not repeated');
ok('review case 2: an outage notice delivered and a warning refused for now in the same sweep; the warning goes out on the next sweep');

// Review case 3, end to end: a continuation is silent; a separate warning in the same county gets through.
before = inbox.length;
feeds.nws = { features: [twLive('urn:oid:t1b', '0042', 'CON', [{ identifier: 'urn:oid:t1' }]), twLive('urn:oid:t2', '0043', 'NEW')] };
await call('sweep', {}, { 'x-grid-sweep': tok });
const tw2 = inbox.slice(before).filter((m) => m.endpoint === p2.endpoint);
assert.equal(tw2.length, 1); assert.match(tw2[0].payload.body, /Tornado Warning 0043/);
ok('review case 3: the continuation of the first warning is silent; the second warning in the same county is delivered');
globalThis.fetch = realFetch;

console.log(`grid-alerts: ${n} checks passed`);
