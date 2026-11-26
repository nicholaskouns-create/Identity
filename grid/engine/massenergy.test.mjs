// node --test grid/engine/massenergy.test.mjs
//
// The arithmetic here is one division, so the tests are not about whether the
// division works. They are about the distinction the module exists to keep:
// stored mass is a mass, flowing mass is a rate, and nothing in the API lets
// one be mistaken for the other or summed into it.

import test from 'node:test';
import assert from 'node:assert/strict';
import {
  C, C2, HOUR, DAY, YEAR,
  storedMassKg, flowKgPerSec, overSeconds, scaleMass, tally,
} from './massenergy.js';

const close = (a, b, rel = 1e-12) => Math.abs(a - b) <= Math.abs(b) * rel;

test('c is the exact SI value and c² follows from it', () => {
  assert.equal(C, 299792458);                    // exact by definition since 1983
  assert.equal(C2, 299792458 * 299792458);
});

test('stored mass is energy over c², with MW·s converted to joules', () => {
  // 320 GW·s = 3.2e11 J; 3.2e11 / 8.98755e16 = 3.5605e-6 kg
  const m = storedMassKg(320000);
  assert.ok(close(m, 3.2e11 / C2));
  assert.ok(close(m, 3.5605e-6, 1e-4), `expected ~3.56 mg, got ${m * 1e6} mg`);
});

test('flow is a rate in kg/s, and one second of it is not the stored mass', () => {
  const r = flowKgPerSec(60000);                 // 60 GW
  assert.ok(close(r, 6e10 / C2));
  const stored = storedMassKg(320000);
  // Numerically adjacent, physically unrelated: this is the confusion the
  // module is built to prevent, so assert they are not interchangeable.
  assert.notEqual(r, stored);
  assert.ok(stored / r > 1, 'stored energy is worth more than one second of flow');
});

test('integrating the rate scales linearly and the periods are the stated ones', () => {
  const r = flowKgPerSec(60000);
  assert.ok(close(overSeconds(r, HOUR), r * 3600));
  assert.equal(HOUR, 3600);
  assert.equal(DAY, 86400);
  assert.equal(YEAR, 31557600);                  // Julian year, as documented
  assert.ok(close(overSeconds(r, YEAR), r * 31557600));
});

test('a missing or impossible input yields null, never a substitute figure', () => {
  for (const bad of [undefined, null, NaN, Infinity, -1, 0, 'nonsense', {}]) {
    assert.equal(storedMassKg(bad), null, `storedMassKg(${String(bad)})`);
    assert.equal(flowKgPerSec(bad), null, `flowKgPerSec(${String(bad)})`);
  }
  assert.equal(overSeconds(null, HOUR), null);
  assert.equal(scaleMass(undefined), null);
});

test('tally computes each half independently', () => {
  const only = tally({ inertiaMwS: 320000 });
  assert.ok(only.storedKg > 0);
  assert.equal(only.flowKgPerSec, null, 'no load means no rate, not a zero rate');
  assert.equal(only.perYearKg, null);
  assert.equal(only.storedAsSecondsOfFlow, null, 'no ratio without both halves');

  const other = tally({ loadMw: 60000 });
  assert.equal(other.storedKg, null);
  assert.ok(other.flowKgPerSec > 0);

  const both = tally({ inertiaMwS: 320000, loadMw: 60000 });
  assert.ok(both.storedAsSecondsOfFlow > 0);
  assert.ok(close(both.storedAsSecondsOfFlow, both.storedKg / both.flowKgPerSec));
});

test('the figures land where the physics says they should', () => {
  const t = tally({ inertiaMwS: 320000, loadMw: 60000 });
  const mg = t.storedKg * 1e6;
  assert.ok(mg > 3 && mg < 4, `Texas stored ~3.56 mg, got ${mg.toFixed(3)} mg`);
  const perYear = t.perYearKg;
  assert.ok(perYear > 20 && perYear < 22, `ERCOT ~21 kg/yr, got ${perYear.toFixed(2)} kg`);
  // Lower 48 at ~480 GW is eight times ERCOT's load, so eight times the rate.
  const us = tally({ loadMw: 480000 });
  assert.ok(close(us.flowKgPerSec, t.flowKgPerSec * 8));
  assert.ok(us.perYearKg > 160 && us.perYearKg < 175, `Lower 48 ~169 kg/yr, got ${us.perYearKg.toFixed(1)}`);
});

test('less inertia means less stored mass — the renewable-transition direction', () => {
  const heavy = storedMassKg(400000), light = storedMassKg(250000);
  assert.ok(light < heavy);
  assert.ok(close(light / heavy, 250 / 400));
  // And the same loss then falls faster, which is what disturbance.js reads:
  // ROCOF = dP·f0 / (2H), so halving H doubles the rate.
  const rocof = (dPmw, Hmws) => (dPmw * 60) / (2 * Hmws);
  assert.ok(close(rocof(1000, 250000) / rocof(1000, 400000), 400 / 250));
});

test('scaleMass picks a readable unit across the whole range', () => {
  assert.deepEqual(scaleMass(3.5605e-6), { value: 3.5605, unit: 'mg' });
  assert.equal(scaleMass(5.34e-6).unit, 'mg');
  assert.equal(scaleMass(1.92e-2).unit, 'g');
  assert.equal(scaleMass(169).unit, 'kg');
  // All the world's stored data, by the Landauer floor, is ~51 pg.
  const data = scaleMass(5.1e-14);
  assert.equal(data.unit, 'pg');
  assert.ok(data.value > 50 && data.value < 52, `expected ~51 pg, got ${data.value}`);
  assert.equal(scaleMass(2500).unit, 't');
  assert.equal(scaleMass(0).unit, 'pg');
  // Every unit must read in its own range rather than as a fraction of the next.
  for (const kg of [5e-13, 5e-10, 5e-7, 5e-4, 0.5, 500, 5000]) {
    const s = scaleMass(kg);
    assert.ok(Math.abs(s.value) >= 1 && Math.abs(s.value) < 1000,
      `${kg} kg rendered as ${s.value} ${s.unit}, outside 1–1000`);
  }
});

// ---- what the panel says -----------------------------------------------
// The module keeps stored and flowing apart; the panel must too, in words a
// reader will actually see.

const { massEnergyHtml } = await import('../ui/panels.js');
const stOf = (inertia, ercotMw, usMw) => ({
  ercot: { data: { inertia, demand: ercotMw } },
  eia: usMw ? { data: { series: { D: [{ t: '2026-11-25T18', v: usMw }] } } } : null,
});

test('the panel never calls the flow a weight', () => {
  const html = massEnergyHtml(stOf(320000, 60000, 480000));
  assert.match(html, /a rate, not a weight/);
  assert.match(html, /does not weigh this much more/);
  assert.match(html, /nothing accumulates in the wires/);
});

test('the stored figure is the one marked as actually in the grid', () => {
  const html = massEnergyHtml(stOf(320000, 60000, 480000));
  assert.match(html, /3\.560<small>mg<\/small>/);
  assert.match(html, /only figure here that is actually <em>in<\/em> the grid/);
  assert.match(html, /ev-MODEL/);
});

test('no inertia means no stored figure and no substitute', () => {
  const html = massEnergyHtml(stOf(null, 60000, 480000));
  assert.match(html, /not publishing inertia/);
  assert.match(html, /does not substitute for it/);
  assert.doesNotMatch(html, /<div class="big">/);
});

test('the ride-through figure names the inertia constant and the renewable direction', () => {
  const html = massEnergyHtml(stOf(320000, 60000, 480000));
  assert.match(html, /5\.33 s/);
  assert.match(html, /inertia constant/);
  assert.match(html, /c² cancels/);
  assert.match(html, /add no synchronous inertia/);
});

test('the coverage limit is stated, not implied', () => {
  const html = massEnergyHtml(stOf(320000, 60000, null));
  assert.match(html, /rotating machines only/);
  assert.match(html, /published by nobody/);
  assert.match(html, /is a floor/);
});

test('nothing at all renders nothing', () => {
  assert.equal(massEnergyHtml({}), '');
  assert.equal(massEnergyHtml({ ercot: { data: {} } }), '');
});
