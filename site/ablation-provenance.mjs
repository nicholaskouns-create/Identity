/** SHA-256 fingerprint of the exact fetched JSON bytes, not an authenticity signature. */
export async function sha256Hex(text, subtle = globalThis.crypto?.subtle) {
  if (typeof text !== 'string') throw new TypeError('Expected JSON source text');
  if (!subtle || typeof subtle.digest !== 'function') throw new Error('SHA-256 is unavailable');
  const digest = await subtle.digest('SHA-256', new TextEncoder().encode(text));
  return Array.from(new Uint8Array(digest), b => b.toString(16).padStart(2, '0')).join('');
}
