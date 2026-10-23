// Optional cross-device sync. The publishable key identifies the project; it is not a service key.
import { planSync, toLocalRow, toRemoteRow } from './sync-merge.js';

const PROJECT = 'https://gpkjvihkyectnenvnbng.supabase.co';
const PUBLISHABLE = 'sb_publishable_iTAWrGCDmKaJt9ADfJLnsw_rWCizCDo';
const SESSION_KEY = 'mnemosyne-sync-session';

const el = id => document.getElementById(id);
const say = message => {
  const node = el('sync-status');
  if (node) node.textContent = message;
};

function readSession() {
  try { return JSON.parse(localStorage.getItem(SESSION_KEY) || 'null'); }
  catch { return null; }
}
function writeSession(session) {
  if (!session) localStorage.removeItem(SESSION_KEY);
  else localStorage.setItem(SESSION_KEY, JSON.stringify(session));
}
function claims(jwt) {
  const body = jwt.split('.')[1].replace(/-/g, '+').replace(/_/g, '/');
  const json = atob(body + '='.repeat((4 - body.length % 4) % 4));
  return JSON.parse(json);
}
function pack(data) {
  const access = data.access_token;
  const payload = claims(access);
  return {
    access_token: access,
    refresh_token: data.refresh_token,
    expires_at: data.expires_at || payload.exp || Math.floor(Date.now() / 1000) + (data.expires_in || 3600),
    user_id: (data.user && data.user.id) || payload.sub
  };
}
async function api(path, options = {}, token) {
  const headers = {
    apikey: PUBLISHABLE,
    Authorization: 'Bearer ' + (token || PUBLISHABLE),
    'Content-Type': 'application/json',
    ...(options.headers || {})
  };
  const response = await fetch(PROJECT + path, { ...options, headers });
  const text = await response.text();
  if (!response.ok) {
    let message = text.slice(0, 180);
    try {
      const body = JSON.parse(text);
      message = body.msg || body.message || body.error_description || message;
    } catch { /* keep the short body */ }
    const error = new Error(message || response.statusText);
    error.status = response.status;
    throw error;
  }
  return text ? JSON.parse(text) : null;
}
async function refreshSession(current) {
  const data = await api('/auth/v1/token?grant_type=refresh_token', {
    method: 'POST',
    body: JSON.stringify({ refresh_token: current.refresh_token })
  });
  const next = pack(data);
  writeSession(next);
  return next;
}
async function freshSession() {
  const current = readSession();
  if (!current) return null;
  if ((current.expires_at || 0) * 1000 > Date.now() + 20000) return current;
  try { return await refreshSession(current); }
  catch (error) {
    writeSession(null);
    throw error;
  }
}
async function rest(path, options, session) {
  try { return await api(path, options, session.access_token); }
  catch (error) {
    if (error.status !== 401) throw error;
    const next = await refreshSession(session);
    Object.assign(session, next);
    return api(path, options, next.access_token);
  }
}

let syncing = false;
let again = false;
let timer = 0;
let socket = null;
let heartbeat = 0;
let socketTries = 0;

function archive() {
  const local = globalThis.MnemosyneArchive;
  if (!local) throw new Error('Archive is still opening');
  return local;
}
async function pullAndPush(session) {
  const local = await archive().all();
  const remote = await rest('/rest/v1/mnemosyne_records?select=id,title,kind,content,created_at,sha256,updated_at', { method: 'GET' }, session);
  const verifiedRemote = [];
  for (const row of remote || []) if (await archive().verify(row)) verifiedRemote.push(row);
  const verifiedLocal = [];
  for (const row of local) if (await archive().verify(row)) verifiedLocal.push(row);
  const plan = planSync(verifiedLocal, verifiedRemote);
  if (plan.pull.length) {
    await archive().putMany(plan.pull.map(toLocalRow));
    archive().announce();
  }
  let pushed = 0;
  if (plan.push.length) {
    const now = new Date().toISOString();
    const rows = plan.push.map(row => toRemoteRow(row, session.user_id, now));
    for (let i = 0; i < rows.length; i += 40) {
      await rest('/rest/v1/mnemosyne_records?on_conflict=id', {
        method: 'POST',
        headers: { Prefer: 'resolution=merge-duplicates,return=minimal' },
        body: JSON.stringify(rows.slice(i, i + 40))
      }, session);
    }
    await archive().putMany(plan.push.map(row => ({ ...toLocalRow(row), updated_at: now })));
    pushed = rows.length;
  }
  if ((plan.pull.length || plan.push.length) && archive().refresh) await archive().refresh();
  return {
    pulled: plan.pull.length,
    pushed,
    count: (await archive().all()).length,
    skipped: (remote || []).length - verifiedRemote.length
  };
}
async function syncNow() {
  if (syncing) { again = true; return; }
  syncing = true;
  try {
    do {
      again = false;
      const session = await freshSession();
      paint(session);
      if (!session) return;
      const result = await pullAndPush(session);
      const skip = result.skipped ? ' ' + result.skipped + ' remote row(s) failed the receipt check and were left untouched.' : '';
      say('Synced. Pulled ' + result.pulled + ', pushed ' + result.pushed + '. ' + result.count + ' local record(s).' + skip);
    } while (again);
  } catch (error) {
    say('Sync failed: ' + error.message);
    paint(readSession());
  } finally {
    syncing = false;
  }
}
function paint(session) {
  const state = el('sync-state');
  const signedIn = Boolean(session && session.access_token);
  if (state) state.textContent = signedIn
    ? 'Signed in. Other devices pick up changes about every 12 seconds.'
    : 'Not signed in. This browser keeps records locally only.';
  const emailForm = el('sync-email');
  const codeForm = el('sync-code');
  if (emailForm) emailForm.hidden = signedIn;
  if (codeForm) codeForm.hidden = signedIn || codeForm.dataset.pending !== '1';
  const now = el('sync-now');
  const out = el('sync-out');
  if (now) now.hidden = !signedIn;
  if (out) out.hidden = !signedIn;
}
function startLoop() {
  if (timer) clearInterval(timer);
  timer = setInterval(() => { if (readSession()) syncNow(); }, 12000);
  connectSocket();
}
function connectSocket() {
  const session = readSession();
  if (!session || socket || socketTries >= 3) return;
  socketTries += 1;
  let ws;
  try {
    ws = new WebSocket(PROJECT.replace('https://', 'wss://') + '/realtime/v1/websocket?apikey=' + encodeURIComponent(PUBLISHABLE) + '&vsn=1.0.0');
  } catch { return; }
  socket = ws;
  let ref = 0;
  const send = (topic, event, payload) => {
    if (ws.readyState === 1) ws.send(JSON.stringify({ topic, event, payload, ref: String(++ref) }));
  };
  ws.onopen = () => {
    send('realtime:public:mnemosyne_records', 'phx_join', {
      config: {
        broadcast: { self: false },
        presence: { key: '' },
        postgres_changes: [{ event: '*', schema: 'public', table: 'mnemosyne_records', filter: 'owner_id=eq.' + session.user_id }]
      },
      access_token: session.access_token
    });
    heartbeat = setInterval(() => send('phoenix', 'heartbeat', {}), 25000);
  };
  ws.onmessage = event => {
    try {
      const message = JSON.parse(event.data);
      if (message.event === 'postgres_changes') syncNow();
    } catch { /* ignore malformed frames */ }
  };
  const stop = () => {
    if (socket === ws) socket = null;
    if (heartbeat) { clearInterval(heartbeat); heartbeat = 0; }
  };
  ws.onerror = stop;
  ws.onclose = stop;
}
function boot() {
  const emailForm = el('sync-email');
  const codeForm = el('sync-code');
  if (!emailForm || !codeForm || !el('sync-now') || !el('sync-out')) return;
  emailForm.addEventListener('submit', async event => {
    event.preventDefault();
    const email = String(new FormData(emailForm).get('email') || '').trim();
    try {
      say('Sending a code…');
      await api('/auth/v1/otp', { method: 'POST', body: JSON.stringify({ email, create_user: true }) });
      codeForm.dataset.email = email;
      codeForm.dataset.pending = '1';
      codeForm.hidden = false;
      say('Check that inbox for a 6-digit code. You can ignore the link in the email.');
    } catch (error) {
      say('Could not send the code: ' + error.message);
    }
  });
  codeForm.addEventListener('submit', async event => {
    event.preventDefault();
    const token = String(new FormData(codeForm).get('code') || '').trim();
    const email = codeForm.dataset.email || '';
    try {
      say('Checking the code…');
      let data;
      try {
        data = await api('/auth/v1/verify', { method: 'POST', body: JSON.stringify({ email, token, type: 'email' }) });
      } catch (error) {
        if (error.status !== 403 && error.status !== 422 && error.status !== 400) throw error;
        data = await api('/auth/v1/verify', { method: 'POST', body: JSON.stringify({ email, token, type: 'signup' }) });
      }
      writeSession(pack(data));
      codeForm.dataset.pending = '';
      socketTries = 0;
      paint(readSession());
      startLoop();
      await syncNow();
    } catch (error) {
      say('Code rejected: ' + error.message);
    }
  });
  el('sync-now').addEventListener('click', () => syncNow());
  el('sync-out').addEventListener('click', () => {
    writeSession(null);
    if (socket) { try { socket.close(); } catch { /* already closed */ } socket = null; }
    paint(null);
    say('Signed out on this browser. Local records were kept.');
  });
  document.addEventListener('mnemosyne-local-change', () => { if (readSession()) syncNow(); });
  document.addEventListener('visibilitychange', () => {
    if (document.visibilityState === 'visible' && readSession()) syncNow();
  });
  freshSession().then(session => {
    paint(session);
    if (!session) return;
    startLoop();
    return syncNow();
  }).catch(error => {
    paint(null);
    say('Saved session could not be restored: ' + error.message);
  });
}
boot();
