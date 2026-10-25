/** Exact, dependency-free combinatorial census of Casimir spectral sectors.
 * This uses the established seven-sector spectrum; it does not construct
 * or certify the concrete 125×125 Casimir matrix.
 */
export const EIGENVALUES = Object.freeze([0, 2, 6, 12, 20, 30, 42]);
export const SECTOR_DIMENSIONS = Object.freeze([1, 9, 25, 28, 27, 22, 13]);
export const CARRIER_DIMENSION = 125;
export const E47_MASK = (1 << 2) | (1 << 5); // roots 6 and 30

export function kernelForMask(mask) {
  if (!Number.isInteger(mask) || mask < 0 || mask >= (1 << EIGENVALUES.length)) {
    throw new RangeError('Kernel mask must be an integer from 0 to 127.');
  }
  const indices = EIGENVALUES.map((_, i) => i).filter(i => (mask & (1 << i)) !== 0);
  const roots = indices.map(i => EIGENVALUES[i]);
  const rank = indices.reduce((total, i) => total + SECTOR_DIMENSIONS[i], 0);
  return { mask, roots, spins: indices, degree: indices.length, rank,
    codimension: CARRIER_DIMENSION - rank };
}

export function allKernels() {
  return Array.from({ length: 1 << EIGENVALUES.length }, (_, mask) => kernelForMask(mask));
}

export function selectorAtNode(node, roots) {
  return roots.reduce((value, root) => value * (node - root), 1);
}
