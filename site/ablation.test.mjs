import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {summarize, compare, ARMS} from './ablation-math.mjs';
import {webcrypto, createHash} from 'node:crypto';
import {sha256Hex} from './ablation-provenance.mjs';
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

test('SHA-256 fingerprints the exact archived JSON bytes, not reserialized data', async () => {
  const source = readFileSync(new URL('../experiments/e47_ablation_results.json', import.meta.url), 'utf8');
  const expected = createHash('sha256').update(source).digest('hex');
  assert.equal(await sha256Hex(source, webcrypto.subtle), expected);
  assert.notEqual(await sha256Hex(source + '\n', webcrypto.subtle), expected);
  assert.equal(await sha256Hex('abc', webcrypto.subtle), 'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad');
  await assert.rejects(sha256Hex(null, webcrypto.subtle), /Expected JSON source text/);
  await assert.rejects(sha256Hex('{}', null), /SHA-256 is unavailable/);
});
test('ablation explorer exposes its fingerprint and an immutable dataset link', () => {
  const html = readFileSync(new URL('./ablation.html', import.meta.url), 'utf8');
  const app = readFileSync(new URL('./ablation.js', import.meta.url), 'utf8');
  assert.match(html, /id="source-digest"/);
  assert.match(html, /blob\/edb517cb65fe64fae479fe113d4ec5a4b95b2a19\/experiments\/e47_ablation_results\.json/);
  assert.match(app, /source_sha256: sha256/);
  assert.match(app, /await sha256Hex\(jsonText\)/);
});
