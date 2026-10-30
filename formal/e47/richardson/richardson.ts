/** Same recurrence as richardson_sim.py. Keep the two in step. */

export const K2 = [32400, 12544, 0, 11664, 19600, 0, 186624] as const;
export const MULT = [1, 9, 25, 28, 27, 22, 13] as const;
export const EPS = 1 / 99144;
export const RHO = 15 / 17;
export const ULP = 2 ** -28;

export const SECTORS = K2.map((k2, j) => {
  const multiplier = 1 - EPS * k2;
  return {
    j,
    k2,
    mult: MULT[j],
    multiplier,
    retain: k2 === 0,
  };
});

const LAM = SECTORS.flatMap((s) => Array(s.mult).fill(s.multiplier));
const KEEP = SECTORS.flatMap((s) => Array(s.mult).fill(s.retain));

function quantize(v: number) {
  return Math.floor(v / ULP + 0.5) * ULP;
}

export function initialState() {
  const raw = Array.from({ length: 125 }, (_, i) => ((17 * i + 3) % 97) - 48);
  const mean = raw.reduce((a, b) => a + b, 0) / raw.length;
  const centered = raw.map((v) => v - mean);
  const norm = Math.sqrt(centered.reduce((a, v) => a + v * v, 0));
  return centered.map((v) => v / norm);
}

function complement(x: number[]) {
  let s = 0;
  for (let i = 0; i < x.length; i++) if (!KEEP[i]) s += x[i] * x[i];
  return Math.sqrt(s);
}

function kernel(x: number[]) {
  let s = 0;
  for (let i = 0; i < x.length; i++) if (KEEP[i]) s += x[i] * x[i];
  return Math.sqrt(s);
}

function delta(a: number[], b: number[]) {
  let s = 0;
  for (let i = 0; i < a.length; i++) {
    const d = a[i] - b[i];
    s += d * d;
  }
  return Math.sqrt(s);
}

export type Frame = {
  n: number;
  floatR: number;
  fixedR: number;
  dx: number;
  kernel: number;
  kernelQ: number;
  bound: number;
};

export function frameAt(n: number): Frame {
  let x = initialState();
  let xq = x.map(quantize);
  for (let step = 0; step < n; step++) {
    x = x.map((v, i) => v * LAM[i]);
    xq = xq.map((v, i) => quantize(v * LAM[i]));
  }
  return {
    n,
    floatR: complement(x),
    fixedR: complement(xq),
    dx: delta(x, xq),
    kernel: kernel(x),
    kernelQ: kernel(xq),
    bound: RHO ** n,
  };
}

export const MARKS = [0, 1, 5, 10, 20, 50, 100, 150, 200, 220, 250];
