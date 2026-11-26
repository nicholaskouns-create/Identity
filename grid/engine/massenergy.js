// Mass-energy of the grid · E = mc² read backwards
//
// Two quantities live here and they must never be added together. Conflating
// them is the whole trap in this subject, so the module keeps them in separate
// functions with separate units and the panel keeps them on separate lines.
//
//   STORED   Energy actually present in the system at this instant, divided by
//            c². ERCOT publishes system inertia in MW·s, which is the kinetic
//            energy turning in the synchronous machines right now. That is a
//            real instantaneous energy content and its mass-equivalent is a
//            mass: kilograms, not kilograms per second.
//
//   FLOWING  Demand is power, joules per second. Divided by c² it is a mass
//            RATE: kilograms per second. It is not a weight and it is not
//            sitting anywhere. Integrated over an interval it gives the
//            mass-equivalent of the energy delivered in that interval.
//
// What the grid does NOT do is get heavier. Electricity flows through and
// leaves as heat; nothing accumulates in the wires. The rest mass that is
// genuinely converted gets converted at the generator — burning fuel leaves
// the fuel lighter, exactly as E = mc² says — and that happens upstream of
// everything Grid can see.
//
// Coverage, stated rather than implied: inertia covers the rotating machines
// only. Magnetic and electric field energy in lines, transformers and reactors
// is also stored energy, is also real, and is not published by anyone, so it
// is not in this number. The stored figure is therefore a floor on the grid's
// true instantaneous energy content.
//
// The reason this is not a curiosity: inverter-based wind and solar carry no
// synchronous inertia. As their share rises the STORED figure falls while the
// FLOWING figure rises, and the same megawatt loss then produces a steeper
// rate of change of frequency — which is precisely the quantity
// `grid/engine/disturbance.js` reads. The two panels are looking at one
// physical fact from opposite ends.

/** Speed of light, m/s, exact by SI definition since 1983. */
export const C = 299792458;
/** c², m²/s². */
export const C2 = C * C;

const isNum = (x) => typeof x === 'number' && Number.isFinite(x);

/**
 * Mass-equivalent of the energy stored in the grid's spinning machines.
 *
 * `inertiaMwS` is ERCOT's published system inertia in MW·s; one MW·s is 10⁶ J.
 * Returns kilograms, or null when inertia is not published — in which case
 * there is no figure to give and inventing one would be worse than silence.
 */
export function storedMassKg(inertiaMwS) {
  if (!isNum(inertiaMwS) || inertiaMwS <= 0) return null;
  return (inertiaMwS * 1e6) / C2;
}

/**
 * Mass RATE of the energy flowing through the grid, in kilograms per second.
 *
 * `loadMw` is instantaneous demand. The unit is kg/s and the name says so,
 * because this number read as a weight is the error the whole module exists
 * to prevent.
 */
export function flowKgPerSec(loadMw) {
  if (!isNum(loadMw) || loadMw <= 0) return null;
  return (loadMw * 1e6) / C2;
}

/** Mass-equivalent of energy delivered over an interval, in kilograms. */
export function overSeconds(kgPerSec, seconds) {
  if (!isNum(kgPerSec) || !isNum(seconds)) return null;
  return kgPerSec * seconds;
}

export const HOUR = 3600;
export const DAY = 86400;
/** Julian year, the duration a "per year" figure here means. */
export const YEAR = 31557600;

/**
 * Pick a human unit for a mass in kilograms.
 *
 * Returns `{ value, unit }` with the unit chosen so the value reads between
 * 1 and 1000 where possible. Grid masses here span picograms to hundreds of
 * kilograms, so a fixed unit would make most of them unreadable.
 */
export function scaleMass(kg) {
  if (!isNum(kg)) return null;
  const a = Math.abs(kg);
  // Each row is [upper bound in kg, unit, multiplier]. The bound is the top of
  // that unit's range, so a mass is reported in the first unit it fits under.
  const steps = [
    [1e-12, 'pg', 1e15], [1e-9, 'ng', 1e12], [1e-6, 'µg', 1e9],
    [1e-3, 'mg', 1e6], [1, 'g', 1e3], [1e3, 'kg', 1], [Infinity, 't', 1e-3],
  ];
  for (const [limit, unit, mul] of steps) {
    if (a < limit) return { value: kg * mul, unit };
  }
  return { value: kg, unit: 'kg' };
}

/**
 * Everything the panel needs, from whatever inputs are present.
 *
 * `inertiaMwS` — ERCOT, for the stored figure (Texas Interconnection only).
 * `loadMw`     — any demand figure, for the flow rate.
 * Either may be absent; each half is computed independently and a missing
 * input yields null rather than a substitute.
 */
export function tally({ inertiaMwS, loadMw } = {}) {
  const stored = storedMassKg(inertiaMwS);
  const rate = flowKgPerSec(loadMw);
  return {
    storedKg: stored,
    flowKgPerSec: rate,
    perHourKg: overSeconds(rate, HOUR),
    perDayKg: overSeconds(rate, DAY),
    perYearKg: overSeconds(rate, YEAR),
    // How long the flow would have to run to equal what is stored. A ratio of
    // two things in different units, which is exactly why it is a time.
    storedAsSecondsOfFlow: isNum(stored) && isNum(rate) && rate > 0 ? stored / rate : null,
  };
}
