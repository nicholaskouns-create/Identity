// KKP-GRID PRNG · bit-identical twin of tools/grid/prng.py
// Mulberry32 uniforms, Box–Muller normals with a cached spare.

export class Stream {
  constructor(seed) { this.s = seed >>> 0; this.spare = null; }
  uniform() {
    this.s = (this.s + 0x6D2B79F5) >>> 0;
    let t = this.s;
    t = Math.imul(t ^ (t >>> 15), t | 1) >>> 0;
    t = (t ^ ((t + (Math.imul(t ^ (t >>> 7), t | 61) >>> 0)) >>> 0)) >>> 0;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  }
  normal() {
    if (this.spare !== null) { const v = this.spare; this.spare = null; return v; }
    let u1 = this.uniform();
    const u2 = this.uniform();
    if (u1 < 1e-300) u1 = 1e-300;
    const r = Math.sqrt(-2 * Math.log(u1));
    this.spare = r * Math.sin(2 * Math.PI * u2);
    return r * Math.cos(2 * Math.PI * u2);
  }
  intBelow(n) { return Math.min(n - 1, Math.floor(this.uniform() * n)); }
}

export function fmix32(h) {
  h >>>= 0;
  h ^= h >>> 16; h = Math.imul(h, 0x85EBCA6B) >>> 0;
  h ^= h >>> 13; h = Math.imul(h, 0xC2B2AE35) >>> 0;
  h ^= h >>> 16;
  return h >>> 0;
}

export function trialSeed(seed, classIndex, t) {
  const v = seed + 0x9E3779B9 * (classIndex + 1) + 0x7F4A7C15 * (t + 1);
  return fmix32(v % 4294967296);
}
