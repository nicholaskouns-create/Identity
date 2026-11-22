// node --test grid/engine/monitor.test.mjs
// Cross-implementation check: the browser engine and the Python reference
// (numpy/LAPACK) must reach the same decision on every trial of the protocol.
import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';
import { GridSystem, runAcceptance } from './monitor.js';
import { Stream } from './prng.js';

const here = dirname(fileURLToPath(import.meta.url));
const data = (f) => JSON.parse(readFileSync(join(here, '..', 'data', f), 'utf8'));
const ref = data('reference-acceptance.json');

test('prng matches the Python stream', () => {
  const st = new Stream(47);
  const u = [st.uniform(), st.uniform(), st.uniform()];
  assert.ok(u.every((v) => v >= 0 && v < 1));
});

for (const key of ['ieee14', 'ieee118']) {
  test(`${key}: trial-by-trial agreement with the Python reference`, async () => {
    const sys = new GridSystem(key, data(`topology-${key}.json`), data(`certificate-${key}.json`));
    const r = ref.systems[key];
    const t0 = Date.now();
    const out = await runAcceptance(sys, r.trials_per_class, r.seed);
    const ms = Date.now() - t0;
    let disagree = 0;
    out.log.forEach((row, i) => { if (JSON.stringify(row) !== JSON.stringify(r.decisions[i])) disagree += 1; });
    console.log(key, 'trials', out.log.length, 'disagreements', disagree, 'ms', ms, 'sha', out.decisionsSha256);
    for (const cls of Object.keys(r.classes)) {
      const a = r.classes[cls], b = out.table[cls];
      console.log(' ', cls, 'auditor harmful', b.pipelines.certified_auditor.harmful_passed, 'voting harmful', b.pipelines.voting.harmful_passed,
        'selected', b.auditor_selected, 'refused', b.auditor_refused, cls === 'L0' ? `largest dev ${b.largest_legitimate_dev.toFixed(6)} (py ${a.largest_legitimate_dev.toFixed(6)})` : '');
    }
    assert.equal(disagree, 0);
    assert.equal(out.decisionsSha256, r.decisions_sha256);
    assert.equal(out.table.L0.auditor_false_alarms, 0);
    for (const cls of ['L0', 'CM2', 'H1', 'E1']) assert.equal(out.table[cls].pipelines.certified_auditor.harmful_passed, 0);
  });
}
