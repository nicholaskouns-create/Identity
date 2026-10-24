import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {summarize, compare, ARMS} from './ablation-math.mjs';
const raw = JSON.parse(readFileSync(new URL('../experiments/e47_ablation_results.json', import.meta.url), 'utf8'));
test('all four arms have eight valid seeds and means match archived JSON', () => {
  const result = summarize(raw);
  assert.equal(result.seeds, 8);
  assert.equal(Object.keys(result.arms).length, 4);
  for (const [id] of ARMS) assert.ok(Math.abs(result.arms[id].mean - raw.means[id]) < 1e-12);
});
test('full E47 has the highest mean on this synthetic experiment', () => {
  const result = summarize(raw);
  assert.ok(result.arms.E47full125.mean > result.arms.baseline64.mean);
  assert.ok(result.arms.E47derived24.mean > result.arms.random24.mean);
});
test('paired differences are recomputed from matching seed indices', () => {
  const result = compare(summarize(raw), 'E47derived24', 'random24');
  assert.equal(result.wins, 8);
  assert.equal(result.ties, 0);
  assert.equal(result.losses, 0);
  assert.ok(Math.abs(result.meanDifference - (raw.means.E47derived24 - raw.means.random24)) < 1e-12);
});
test('rejects missing seeds, invalid AUC, and altered aggregate means', () => {
  const missing = structuredClone(raw); missing.auc_by_seed.random24.pop();
  assert.throws(() => summarize(missing), /Invalid AUC/);
  const invalid = structuredClone(raw); invalid.auc_by_seed.baseline64[0] = 1.2;
  assert.throws(() => summarize(invalid), /Invalid AUC/);
  const changed = structuredClone(raw); changed.means.E47full125 = 0.2;
  assert.throws(() => summarize(changed), /disagrees/);
});
