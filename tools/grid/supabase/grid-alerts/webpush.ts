// Web Push, standards only: RFC 8291 message encryption (aes128gcm, RFC 8188) and RFC 8292 VAPID,
// on WebCrypto. No third-party code; tools/grid/test_grid_alerts.mjs checks it against the web-push
// and http_ece reference implementations in both directions.
const te = new TextEncoder();
export const b64u = {
  enc: (buf) => btoa(String.fromCharCode(...new Uint8Array(buf))).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, ''),
  dec: (s) => { const t = String(s).replace(/-/g, '+').replace(/_/g, '/'); const p = t + '==='.slice((t.length + 3) % 4); return Uint8Array.from(atob(p), (c) => c.charCodeAt(0)); },
};
const cat = (...parts) => { const n = parts.reduce((a, p) => a + p.length, 0), out = new Uint8Array(n); let o = 0; for (const p of parts) { out.set(p, o); o += p.length; } return out; };
async function hkdf(salt, ikm, info, len) {
  const k = await crypto.subtle.importKey('raw', ikm, 'HKDF', false, ['deriveBits']);
  return new Uint8Array(await crypto.subtle.deriveBits({ name: 'HKDF', hash: 'SHA-256', salt, info }, k, len * 8));
}

// Encrypt one push message for a subscription's p256dh / auth (both base64url).
export async function encrypt(plaintext, p256dh, auth, opts = {}) {
  const uaPub = b64u.dec(p256dh), authSecret = b64u.dec(auth);
  if (uaPub.length !== 65 || uaPub[0] !== 4) throw new Error('p256dh is not an uncompressed P-256 point');
  if (authSecret.length < 16) throw new Error('auth secret too short');
  const as = opts.asKeys || await crypto.subtle.generateKey({ name: 'ECDH', namedCurve: 'P-256' }, true, ['deriveBits']);
  const asPub = new Uint8Array(await crypto.subtle.exportKey('raw', as.publicKey));
  const uaKey = await crypto.subtle.importKey('raw', uaPub, { name: 'ECDH', namedCurve: 'P-256' }, false, []);
  const ecdh = new Uint8Array(await crypto.subtle.deriveBits({ name: 'ECDH', public: uaKey }, as.privateKey, 256));
  const ikm = await hkdf(authSecret, ecdh, cat(te.encode('WebPush: info\0'), uaPub, asPub), 32);
  const salt = opts.salt || crypto.getRandomValues(new Uint8Array(16));
  const cek = await hkdf(salt, ikm, te.encode('Content-Encoding: aes128gcm\0'), 16);
  const nonce = await hkdf(salt, ikm, te.encode('Content-Encoding: nonce\0'), 12);
  const record = cat(typeof plaintext === 'string' ? te.encode(plaintext) : plaintext, new Uint8Array([2]));
  const key = await crypto.subtle.importKey('raw', cek, 'AES-GCM', false, ['encrypt']);
  const ct = new Uint8Array(await crypto.subtle.encrypt({ name: 'AES-GCM', iv: nonce }, key, record));
  const rs = new Uint8Array(4); new DataView(rs.buffer).setUint32(0, 4096);
  return cat(salt, rs, new Uint8Array([asPub.length]), asPub, ct);
}

// VAPID: an ES256 JWT for the push service's origin, signed with the application server key (JWK).
export async function vapidHeader(endpoint, privateJwk, publicB64u, subject, now = Date.now()) {
  const aud = new URL(endpoint).origin;
  const head = b64u.enc(te.encode(JSON.stringify({ typ: 'JWT', alg: 'ES256' })));
  const body = b64u.enc(te.encode(JSON.stringify({ aud, exp: Math.floor(now / 1000) + 12 * 3600, sub: subject })));
  const key = await crypto.subtle.importKey('jwk', { ...privateJwk, key_ops: ['sign'] }, { name: 'ECDSA', namedCurve: 'P-256' }, false, ['sign']);
  const sig = await crypto.subtle.sign({ name: 'ECDSA', hash: 'SHA-256' }, key, te.encode(`${head}.${body}`));
  return `vapid t=${head}.${body}.${b64u.enc(sig)}, k=${publicB64u}`;
}

export async function send(sub, payload, vapid, { ttl = 3600, urgency = 'high' } = {}) {
  const body = await encrypt(JSON.stringify(payload), sub.p256dh, sub.auth);
  const r = await fetch(sub.endpoint, {
    method: 'POST',
    headers: { 'Content-Encoding': 'aes128gcm', 'Content-Type': 'application/octet-stream', TTL: String(ttl), Urgency: urgency, Authorization: await vapidHeader(sub.endpoint, vapid.privateJwk, vapid.publicKey, vapid.subject) },
    body,
  });
  return { status: r.status, ok: r.ok, gone: r.status === 404 || r.status === 410, text: r.ok ? '' : (await r.text().catch(() => '')).slice(0, 200) };
}
