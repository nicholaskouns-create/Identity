// Monorail canonical serialization + chain verification, browser side.
// Contract: monorail/CANONICAL.md v1. Must agree byte-for-byte with
// monorail/passport.py and city_formalism.monorail_canonical_json().
//
// No credentials, no database endpoint, no network. It verifies an exported
// receipt file that the visitor already has. That is the whole point: the
// check must not depend on trusting the server that served the receipts.

const UNHASHED = ["receipt_hash"];

// JSON.stringify would be wrong here. Object.keys()/default sort order is
// UTF-16 code-unit order; the contract specifies Unicode CODE POINT order.
// They differ for astral-plane keys. Compare by code point explicitly.
function codePointLess(a, b) {
  const A = Array.from(a), B = Array.from(b);
  const n = Math.min(A.length, B.length);
  for (let i = 0; i < n; i++) {
    const x = A[i].codePointAt(0), y = B[i].codePointAt(0);
    if (x !== y) return x < y ? -1 : 1;
  }
  return A.length === B.length ? 0 : (A.length < B.length ? -1 : 1);
}

export function assertCanonicalizable(v, path = "$") {
  if (v === null || typeof v === "boolean") return;
  if (typeof v === "number") {
    if (!Number.isInteger(v)) throw new Error(`${path}: floating point is outside canonical contract v1`);
    if (!Number.isSafeInteger(v)) throw new Error(`${path}: integer outside the exactly-representable range`);
    return;
  }
  if (typeof v === "string") {
    if (v.includes("\u0000")) throw new Error(`${path}: U+0000 cannot be stored in PostgreSQL jsonb`);
    return;
  }
  if (Array.isArray(v)) { v.forEach((x, i) => assertCanonicalizable(x, `${path}[${i}]`)); return; }
  if (typeof v === "object") {
    for (const k of Object.keys(v)) assertCanonicalizable(v[k], `${path}.${k}`);
    return;
  }
  throw new Error(`${path}: unsupported type ${typeof v}`);
}

export function monorailCanonical(value) {
  if (value === null) return "null";
  if (typeof value === "boolean") return value ? "true" : "false";
  if (typeof value === "number") return String(value);
  if (typeof value === "string") return JSON.stringify(value);  // minimal escaping, raw UTF-8
  if (Array.isArray(value)) return "[" + value.map(monorailCanonical).join(",") + "]";
  const keys = Object.keys(value).sort(codePointLess);
  return "{" + keys.map(k => JSON.stringify(k) + ":" + monorailCanonical(value[k])).join(",") + "}";
}

export async function receiptDigest(passport) {
  const body = {};
  for (const k of Object.keys(passport)) if (!UNHASHED.includes(k)) body[k] = passport[k];
  assertCanonicalizable(body);
  const bytes = new TextEncoder().encode(monorailCanonical(body));
  const buf = await crypto.subtle.digest("SHA-256", bytes);
  return Array.from(new Uint8Array(buf)).map(b => b.toString(16).padStart(2, "0")).join("");
}

export async function verifyReceipt(passport) {
  const actual = await receiptDigest(passport);
  const claimed = passport.receipt_hash;
  return { ok: actual === claimed, actual, claimed };
}

const GENESIS = "0".repeat(64);

export async function verifyChain(receipts) {
  const notes = [];
  let ok = true, expected = GENESIS;
  const seen = new Set();
  for (let i = 0; i < receipts.length; i++) {
    const r = receipts[i];
    const v = await verifyReceipt(r);
    if (!v.ok) { ok = false; notes.push(`[${i}] ${r.theorem_id}: digest mismatch — claims ${v.claimed.slice(0,12)}…, computes ${v.actual.slice(0,12)}…`); }
    if (r.parent_receipt_hash !== expected) { ok = false; notes.push(`[${i}] ${r.theorem_id}: broken link — parent ${String(r.parent_receipt_hash).slice(0,12)}…, expected ${expected.slice(0,12)}…`); }
    if (seen.has(r.receipt_hash)) { ok = false; notes.push(`[${i}] duplicate receipt ${String(r.receipt_hash).slice(0,12)}…`); }
    seen.add(r.receipt_hash);
    expected = r.receipt_hash;
  }
  if (ok) notes.push(`chain intact across ${receipts.length} receipt(s)`);
  return { ok, notes };
}
