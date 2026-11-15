// Exact, browser-independent spectral model. No proof compilation takes place here.
export const SPECTRUM = Object.freeze([0, 2, 6, 12, 20, 30, 42]);
export const MULTIPLICITIES = Object.freeze([1, 9, 25, 28, 27, 22, 13]);
export const EPSILON_DENOMINATOR = 99144;
export const K = Object.freeze(SPECTRUM.map(c => (c - 6) * (c - 30)));
export const K2 = Object.freeze(K.map(k => k * k));
export const GAINS = Object.freeze(K2.map(k2 => 1 - k2 / EPSILON_DENOMINATOR));
export const rank = MULTIPLICITIES.reduce((s, m, i) => s + ((K2[i] === 0) ? m : 0), 0);
export const dimension = MULTIPLICITIES.reduce((a,b) => a+b, 0);
export const complement = dimension - rank;
export const maxComplementGain = Math.max(...GAINS.filter((g,i) => K2[i] !== 0).map(Math.abs));

// Isotropic unit norm in the seven Casimir eigenspaces: initial weight = dim/125.
export function contraction(n) {
  if (!Number.isInteger(n) || n < 0 || n > 10000) throw new RangeError('n must be an integer in [0,10000]');
  const weights = MULTIPLICITIES.map((m,i) => m / dimension * Math.pow(GAINS[i], 2*n));
  const kept = rank / dimension; // kernel eigenspaces have gain 1
  const complementEnergy = weights.reduce((s,w,i) => s + (K2[i] === 0 ? 0 : w), 0);
  const norm2 = kept + complementEnergy;
  return {
    n, norm2, kept, complement: complementEnergy,
    fractionKernel: kept / norm2,
    fractionComplement: complementEnergy / norm2,
    bound: Math.pow(maxComplementGain,n),
    weights
  };
}

export function runExactChecks() {
  return [
    ['Carrier dimension',dimension === 125,'Σ(2J+1)mJ = 125'],
    ['Kernel rank',rank === 47,'5×5 + 2×11 = 47'],
    ['Complement dimension',complement === 78,'125 − 47 = 78'],
    ['Spectral zero set',SPECTRUM.filter((_,i)=>K2[i]===0).join(',') === '6,30','ker K = E₆ ⊕ E₃₀'],
    ['Positive semidefinite K²',K2.every(v=>Number.isInteger(v)&&v>=0),'K² eigenvalues ≥ 0'],
    ['Exact contraction endpoint',17*(EPSILON_DENOMINATOR-11664) === 15*EPSILON_DENOMINATOR,'gain at C=12 equals 15/17'],
    ['Exact contraction endpoint',17*(EPSILON_DENOMINATOR-186624) === -15*EPSILON_DENOMINATOR,'gain at C=42 equals −15/17'],
    ['Kernel fixed point',GAINS.every((g,i)=>K2[i]!==0||g===1),'Γ acts as identity on ker K']
  ].map(([name,passed,detail])=>({name,passed,detail}));
}
