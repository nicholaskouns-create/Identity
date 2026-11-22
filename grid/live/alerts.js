// Background alerts. Standard Web Push to Grid's edge function `grid-alerts` (source in
// tools/grid/supabase/grid-alerts): the browser's own push service carries each notice, so it arrives
// with Grid closed. Kept on the server: this device's push address and keys, the counties, the threshold
// and two choices. Kept only on this device: everything about medical equipment.
import { ANON } from './pulse.js';

export const ALERTS_URL = 'https://gpkjvihkyectnenvnbng.supabase.co/functions/v1/grid-alerts';
const PREFS = 'kkp-grid-alerts', HOME = 'kkp-grid-home';
export const MAX_PLACES = 5;
export const THRESHOLDS = [[1, 'any outage at all'], [10, '10 or more customers out'], [100, '100 or more'], [1000, '1,000 or more'], [10000, '10,000 or more']];

export function platform() {
  const ua = navigator.userAgent || '';
  const ios = /iPhone|iPad|iPod/.test(ua) || (/Macintosh/.test(ua) && navigator.maxTouchPoints > 1);
  const standalone = matchMedia('(display-mode: standalone)').matches || navigator.standalone === true;
  const push = isSecureContext && 'serviceWorker' in navigator && 'PushManager' in window && 'Notification' in window;
  return { ios, standalone, push, permission: 'Notification' in window ? Notification.permission : 'unsupported' };
}

const DEFAULTS = { on: false, endpoint: null, places: [], minOut: 10, weather: true, restore: true };
export function loadPrefs() { try { return { ...DEFAULTS, ...JSON.parse(localStorage.getItem(PREFS) || '{}') }; } catch { return { ...DEFAULTS }; } }
export function savePrefs(p) {
  try { localStorage.setItem(PREFS, JSON.stringify(p)); } catch { /* private mode */ }
  // The service worker cannot read localStorage; it re-subscribes from this copy if the browser rotates the subscription.
  caches.open('grid-prefs').then((c) => c.put('alerts.json', new Response(JSON.stringify({ on: p.on, places: p.places, minOut: p.minOut, weather: p.weather, restore: p.restore })))).catch(() => {});
}
export function loadHome() { try { return { medical: false, done: {}, ...JSON.parse(localStorage.getItem(HOME) || '{}') }; } catch { return { medical: false, done: {} }; } }
export function saveHome(h) { try { localStorage.setItem(HOME, JSON.stringify(h)); } catch { /* private mode */ } }

async function api(op, body) {
  const r = await fetch(`${ALERTS_URL}?op=${op}`, {
    method: body ? 'POST' : 'GET', cache: 'no-store',
    headers: { Authorization: `Bearer ${ANON}`, apikey: ANON, ...(body ? { 'content-type': 'application/json' } : {}) },
    body: body ? JSON.stringify(body) : undefined,
  });
  const j = await r.json().catch(() => null);
  if (!r.ok || !j || j.error) throw Object.assign(new Error((j && j.error) || `HTTP ${r.status}`), { status: r.status });
  return j;
}
export const serviceInfo = () => api('key');

const bytes = (s) => { const t = String(s).replace(/-/g, '+').replace(/_/g, '/'); return Uint8Array.from(atob(t + '==='.slice((t.length + 3) % 4)), (c) => c.charCodeAt(0)); };
const same = (a, b) => { if (!a || !b) return false; const x = new Uint8Array(a), y = new Uint8Array(b); return x.length === y.length && x.every((v, i) => v === y[i]); };
const ready = () => Promise.race([navigator.serviceWorker.ready, new Promise((_, no) => setTimeout(() => no(new Error('Grid’s offline worker is not running yet. Reload the page and try again.')), 10000))]);
const body = (sub, p) => ({ subscription: sub.toJSON(), places: p.places, minOut: p.minOut, weather: p.weather, restore: p.restore });

// Call straight from a tap: the permission prompt has to come from the gesture itself.
export async function turnOn(prefs, publicKey) {
  const perm = await Notification.requestPermission();
  if (perm !== 'granted') throw new Error(perm === 'denied' ? 'Notifications are blocked for this site. Allow them in the browser or phone settings, then try again.' : 'Notifications were not allowed.');
  const reg = await ready();
  const key = bytes(publicKey || (await serviceInfo()).publicKey);
  let sub = await reg.pushManager.getSubscription();
  if (sub && !same(sub.options && sub.options.applicationServerKey, key)) { await sub.unsubscribe().catch(() => {}); sub = null; }
  if (!sub) sub = await reg.pushManager.subscribe({ userVisibleOnly: true, applicationServerKey: key });
  const res = await api('subscribe', body(sub, prefs));
  const next = { ...prefs, on: true, endpoint: sub.endpoint, places: res.places };
  savePrefs(next);
  return next;
}
export async function update(prefs) {
  const sub = await (await ready()).pushManager.getSubscription();
  if (!sub) throw new Error('This browser no longer has the alert subscription. Turn alerts on again.');
  const res = await api('subscribe', body(sub, prefs));
  const next = { ...prefs, on: true, endpoint: sub.endpoint, places: res.places };
  savePrefs(next);
  return next;
}
// Sent after a short delay, so the phone can be locked or Grid closed before it arrives.
export const TEST_DELAY = 15;
export const sendTest = (prefs) => api('test', { endpoint: prefs.endpoint, delay: TEST_DELAY });
export async function turnOff(prefs) {
  const sub = await ready().then((r) => r.pushManager.getSubscription()).catch(() => null);
  const endpoint = (sub && sub.endpoint) || prefs.endpoint;
  if (endpoint) await api('unsubscribe', { endpoint }).catch(() => {});
  if (sub) await sub.unsubscribe().catch(() => {});
  const next = { ...prefs, on: false, endpoint: null };
  savePrefs(next);
  return next;
}
// On load: alerts on here must still match a live browser subscription.
export async function resync(prefs) {
  if (!prefs.on || !platform().push) return { prefs, state: prefs.on ? 'unsupported' : 'off' };
  const sub = await ready().then((r) => r.pushManager.getSubscription()).catch(() => null);
  if (!sub) { const next = { ...prefs, on: false, endpoint: null }; savePrefs(next); return { prefs: next, state: 'lost' }; }
  if (sub.endpoint !== prefs.endpoint) return { prefs: await update(prefs), state: 'moved' };
  return { prefs, state: 'ok' };
}

// For households with powered medical equipment. General preparedness steps; the device keeps the ticks.
export const PLAN = [
  ['utility', 'Tell your electric utility. Many keep a medical or life-support list that brings warnings before planned shutoffs. Utilities do not promise faster restoration, so plan as if it will not come early.'],
  ['battery', 'Know how many hours each device runs on its battery. Keep batteries charged and spares ready.'],
  ['oxygen', 'Oxygen: a concentrator stops when the power does. Keep backup oxygen cylinders, and the supplier’s 24-hour number.'],
  ['numbers', 'Write down device settings and the numbers for your equipment supplier, doctor, pharmacy and dialysis center.'],
  ['cold', 'Medicines that need a refrigerator: ask your pharmacist how long each keeps without one. Have a cooler and ice packs ready.'],
  ['dialysis', 'Dialysis: ask your center for its emergency plan and where you would go if it closed.'],
  ['go', 'Decide where you will go if the outage outlasts the batteries: family or friends with power, a cooling or warming center, or a hospital.'],
  ['co', 'Put battery-powered carbon monoxide alarms near every sleeping area.'],
];
