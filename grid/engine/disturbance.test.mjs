// node --test grid/engine/disturbance.test.mjs
//
// The detector is only worth having if it stays quiet. Most of what follows
// checks silence: noise, ramps, gaps and malformed samples must produce no
// event, because a false "something tripped" on a grid app is worse than no
// feature at all. The rest checks that a real step is measured correctly and
// that the derived bound is the swing equation and nothing more.

import test from 'node:test';
import assert from 'node:assert/strict';
import {
  F0, DEADBAND_HZ, UFLS_STAGES, SAMPLING, DEFAULTS,
  pairs, lossFloorMw, severity, detect, latest,
} from './disturbance.js';

const T0 = Date.UTC(2026, 10, 25, 18, 0, 0);
/** A trace at the publisher's cadence from a list of frequencies. */
const trace = (fs, stepMs = SAMPLING.nominalMs, t0 = T0) => fs.map((f, i) => ({ t: t0 + i * stepMs, f }));
const flat = (n, f = 60) => new Array(n).fill(f);

test('a clean step is detected, with the right direction and rate', () => {
  // Quiet at 60.000, then 60 mHz down in one 10 s interval, then settling.
  const h = trace([...flat(6), 59.94, 59.95, 59.96, 59.97]);
  const ev = detect(h, { inertiaMwS: 300000 });
  assert.equal(ev.length, 1);
  const e = ev[0];
  assert.equal(e.direction, 'loss');
  assert.ok(Math.abs(e.stepHz + 0.06) < 1e-9, 'step is −60 mHz');
  assert.ok(Math.abs(e.rocofHzPerS + 0.006) < 1e-9, 'rate is −6 mHz/s over 10 s');
  assert.ok(Math.abs(e.nadirHz - 59.94) < 1e-9, 'nadir is the lowest sample');
  assert.equal(e.basis, 'inferred from the ERCOT frequency trace; not a reported line trip');
});

test('an upward step reads as a gain, not a loss', () => {
  const h = trace([...flat(6), 60.06, 60.05, 60.04]);
  const [e] = detect(h);
  assert.equal(e.direction, 'gain');
  assert.ok(e.peakHz >= 60.06 - 1e-9);
});

test('the MW floor is exactly the swing equation', () => {
  // ΔP = 2·H·(df/dt)/f0 = 2 · 300000 · 0.006 / 60 = 60 MW
  assert.equal(lossFloorMw({ rocofHzPerS: -0.006, inertiaMwS: 300000 }), 60);
  assert.equal(lossFloorMw({ rocofHzPerS: 0.006, inertiaMwS: 300000 }), 60, 'sign-free magnitude');
  const h = trace([...flat(6), 59.94, 59.95]);
  const [e] = detect(h, { inertiaMwS: 300000 });
  assert.ok(Math.abs(e.mwFloor - 60) < 1e-9);
});

test('without published inertia the floor is null, never a guess', () => {
  assert.equal(lossFloorMw({ rocofHzPerS: -0.006, inertiaMwS: undefined }), null);
  assert.equal(lossFloorMw({ rocofHzPerS: -0.006, inertiaMwS: 0 }), null);
  const h = trace([...flat(6), 59.94, 59.95]);
  const [e] = detect(h);
  assert.equal(e.mwFloor, null);
});

test('ordinary regulation inside the governor deadband is not a disturbance', () => {
  // Wander of ±15 mHz, under the ±17 mHz standard deadband, never stepping
  // more than the mechanical deadband between samples.
  const fs = [];
  for (let i = 0; i < 40; i += 1) fs.push(60 + 0.015 * Math.sin(i / 2));
  assert.deepEqual(detect(trace(fs), { inertiaMwS: 300000 }), []);
});

test('a slow ramp is not a step, however far it travels', () => {
  // 4 mHz per sample for 40 samples: 160 mHz of travel, beyond the ACE limit,
  // but no single interval clears the deadband and the run-up is never quiet.
  const fs = [];
  for (let i = 0; i < 40; i += 1) fs.push(60 - 0.004 * i);
  assert.deepEqual(detect(trace(fs)), []);
});

test('a gap in the feed never reads as a disturbance', () => {
  // Quiet at 60.000; the feed goes away; it returns far below. The jump across
  // the gap is large, and must still produce nothing.
  const before = trace(flat(6));
  const after = trace([59.90, 59.91, 59.92], SAMPLING.nominalMs, T0 + 6 * SAMPLING.nominalMs + 10 * 60000);
  assert.deepEqual(detect([...before, ...after], { inertiaMwS: 300000 }), []);
});

test('duplicate, out-of-order and malformed samples are dropped, not interpreted', () => {
  const h = [
    { t: T0, f: 60 }, { t: T0, f: 60 },                        // duplicate timestamp
    { t: T0 + 10000, f: 60 }, { t: T0 + 5000, f: 59.9 },       // out of order
    { t: T0 + 20000, f: NaN }, { t: T0 + 30000, f: 60 },       // malformed
    { t: null, f: 60 }, { f: 60 }, null,                        // junk
  ];
  for (const p of pairs(h)) {
    assert.ok(Number.isFinite(p.dHz) && p.dtMs >= SAMPLING.minGapMs && p.dtMs <= SAMPLING.maxGapMs);
  }
  assert.deepEqual(detect(h, { inertiaMwS: 300000 }), []);
});

test('one disturbance is one event, not a burst', () => {
  // A deep drop followed by a ragged recovery that re-crosses the threshold.
  const h = trace([...flat(6), 59.90, 59.93, 59.88, 59.95, 59.91, 59.97, 60.0]);
  assert.equal(detect(h, { inertiaMwS: 300000 }).length, 1);
});

test('severity follows ERCOT bands and the published load-shed stages', () => {
  assert.equal(severity(60.000).level, 'normal');
  assert.equal(severity(59.975).level, 'normal');          // 25 mHz: inside ±30
  assert.equal(severity(59.950).level, 'outside-normal');  // 50 mHz
  assert.equal(severity(59.880).level, 'beyond-ace');      // 120 mHz
  assert.equal(severity(59.300).level, 'ufls');            // first stage, exactly
  assert.equal(severity(59.300).stage.shedPct, 5);
  assert.equal(severity(58.400).stage.shedPct, 25);        // past the third stage
  assert.equal(severity(undefined).level, 'unknown');
});

test('the published constants are the ones cited, not drifted', () => {
  assert.equal(F0, 60);
  assert.equal(DEADBAND_HZ.standard, 0.017);               // NERC BAL-001-TRE-2 R6.1
  assert.equal(DEADBAND_HZ.mechanical, 0.034);
  assert.deepEqual(UFLS_STAGES.map((s) => s.hz), [59.3, 58.9, 58.5]);   // ERCOT LFL-31
  assert.deepEqual(UFLS_STAGES.map((s) => s.shedPct), [5, 15, 25]);
  assert.equal(DEFAULTS.stepHz, DEADBAND_HZ.mechanical, 'the conservative deadband is the trigger');
});

test('an empty, short or absent trace is handled without throwing', () => {
  for (const h of [undefined, null, [], trace(flat(2)), 'nonsense', 42]) {
    assert.deepEqual(detect(h), []);
    assert.equal(latest(h), null);
  }
});

// ---- what the panel actually says ------------------------------------------
// The engine being right is half of it. The block the reader sees must never
// claim more than the engine found, and must carry the CIP limitation every
// time it reports an event, or the feature becomes the overstatement it was
// built to avoid.

const { disturbanceHtml } = await import('../ui/panels.js');
const stFrom = (fs, inertia = 300000) => ({ ercot: { hist: trace(fs), data: { inertia } } });
const DISCLAIMER = /cannot see breaker positions/;

test('a quiet trace says so, and does not claim nothing happened', () => {
  const html = disturbanceHtml(stFrom(flat(20)));
  assert.match(html, /No step beyond/);
  assert.match(html, /not proof that nothing happened/);
  assert.doesNotMatch(html, /role="alert"/);
});

test('a reported event always carries the CIP limitation and the Model mark', () => {
  const html = disturbanceHtml(stFrom([...flat(6), 59.94, 59.95, 59.96]));
  assert.match(html, DISCLAIMER);
  assert.match(html, /ev-MODEL/);
  assert.match(html, /not which line, unit or substation/);
});

test('the MW figure is stated as a floor, never as an estimate', () => {
  const html = disturbanceHtml(stFrom([...flat(6), 59.94, 59.95]));
  assert.match(html, /no less than [\d,]+ MW/);
  assert.match(html, /floor and not an estimate/);
  assert.match(html, /true figure is larger/);
});

test('with no published inertia the panel states no size at all', () => {
  // null, not undefined: a default parameter would swallow undefined and the
  // test would silently exercise the inertia path it means to exclude.
  const html = disturbanceHtml(stFrom([...flat(6), 59.94, 59.95], null));
  assert.match(html, /did not publish inertia/);
  assert.doesNotMatch(html, /no less than/);
  assert.match(html, DISCLAIMER, 'the limitation survives the missing input');
});

test('a load-shed-depth event raises an alert and names the shedding', () => {
  const html = disturbanceHtml(stFrom([...flat(6), 59.2, 59.25, 59.3]));
  assert.match(html, /role="alert"/);
  assert.match(html, /Automatic load shedding operates at this frequency/);
  assert.match(html, /load-shed stage/);
  assert.match(html, DISCLAIMER);
});

test('an upward step is not described as a loss', () => {
  const html = disturbanceHtml(stFrom([...flat(6), 60.06, 60.05]));
  assert.match(html, /Load lost or generation surged/);
  assert.doesNotMatch(html, /Generation or load lost/);
});

test('too short a trace renders nothing rather than a guess', () => {
  assert.equal(disturbanceHtml({ ercot: { hist: trace(flat(3)), data: {} } }), '');
  assert.equal(disturbanceHtml({}), '');
});

test('latest returns the most recent event of several', () => {
  const first = trace([...flat(6), 59.93, 59.95, 59.97, 60.0]);
  const gapFree = [...first];
  // A second, separate disturbance well after the refractory window.
  let t = gapFree.at(-1).t;
  for (const f of [...flat(14, 60), 59.90, 59.93]) { t += SAMPLING.nominalMs; gapFree.push({ t, f }); }
  const ev = detect(gapFree, { inertiaMwS: 300000 });
  assert.equal(ev.length, 2);
  assert.equal(latest(gapFree, { inertiaMwS: 300000 }).atMs, ev[1].atMs);
  assert.ok(ev[1].atMs > ev[0].atMs);
});
