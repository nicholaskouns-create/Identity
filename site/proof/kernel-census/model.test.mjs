import test from 'node:test';
import assert from 'node:assert/strict';
import { EIGENVALUES, SECTOR_DIMENSIONS, CARRIER_DIMENSION,
  E47_MASK, kernelForMask, allKernels, selectorAtNode } from './model.mjs';

test('exact seven-sector carrier', () => {
  assert.deepEqual(EIGENVALUES, [0, 2, 6, 12, 20, 30, 42]);
  assert.deepEqual(SECTOR_DIMENSIONS, [1, 9, 25, 28, 27, 22, 13]);
  assert.equal(SECTOR_DIMENSIONS.reduce((a, b) => a + b, 0), CARRIER_DIMENSION);
});

test('all 128 kernels have exact ranks, complements and selector zeros', () => {
  const rows = allKernels();
  assert.equal(rows.length, 128);
  assert.equal(new Set(rows.map(row => row.mask)).size, 128);
  const degreeCounts = Array(8).fill(0);
  for (const row of rows) {
    degreeCounts[row.degree] += 1;
    assert.equal(row.rank + row.codimension, 125);
    assert.equal(row.rank + kernelForMask(row.mask ^ 127).rank, 125);
    assert.equal(row.rank, row.spins.reduce((n, i) => n + SECTOR_DIMENSIONS[i], 0));
    for (const node of EIGENVALUES) {
      assert.equal(selectorAtNode(node, row.roots) === 0, row.roots.includes(node));
    }
  }
  assert.deepEqual(degreeCounts, [1, 7, 21, 35, 35, 21, 7, 1]);
});

test('canonical E47 and maximal quadratic rank are distinguished', () => {
  const rows = allKernels();
  assert.deepEqual(kernelForMask(E47_MASK).roots, [6, 30]);
  assert.equal(kernelForMask(E47_MASK).rank, 47);
  assert.equal(rows.filter(row => row.rank === 47 && row.roots.join(',') === '6,30').length, 1);
  assert.equal(Math.max(...rows.filter(row => row.degree === 2).map(row => row.rank)), 55);
  assert.equal(kernelForMask(0).rank, 0);
  assert.equal(kernelForMask(127).rank, 125);
});

test('invalid masks are rejected rather than silently coerced', () => {
  for (const mask of [-1, 128, 1.5, NaN, '36', null]) {
    assert.throws(() => kernelForMask(mask), RangeError);
  }
});
