// Frequency disturbance detector · Texas Interconnection
//
// A generation or transmission loss writes itself into system frequency. This
// module reads the ERCOT frequency trace Grid already polls and says when a
// disturbance happened, which way it went, and how far it went — from live
// inputs and the formulas stated below, which is what △ Model means here.
//
// WHAT THIS IS NOT. It is not a breaker status and it cannot name a line.
// Live breaker position is utility-internal SCADA under NERC CIP and is not
// published anywhere. A detection here says the interconnection lost or gained
// something; it does not say what, and it never says which line.
//
// The sampling governs everything. Grid polls ERCOT every ~10 s, while a real
// excursion reaches its nadir in seconds and governors begin arresting it
// within one. So the trace shows the aftermath, not the swing. Every quantity
// below is therefore reported as a bound in the direction the sampling biases
// it, never as a point estimate.
//
// Constants, each from a published source:
//   f0 = 60 Hz.
//   Governor deadbands ±0.017 Hz, and ±0.034 Hz for steam and hydro turbines
//     with mechanical governors — NERC BAL-001-TRE-2 R6.1. Below the deadband
//     no governor is obliged to respond, so sub-deadband motion is not a
//     disturbance signature and is the natural noise floor.
//   Operating bands ±30 mHz normal, ±90 mHz ACE limit — as Grid already uses.
//   ERCOT UFLS: 59.3 Hz sheds at least 5% of Transmission Operator load,
//     58.9 Hz at least 15% cumulative, 58.5 Hz at least 25% cumulative
//     — ERCOT LFL-31, Transmission Operator UFLS obligations.
//   Swing equation  ΔP = 2·H·(df/dt)/f0,  H the system inertia in MW·s, which
//     ERCOT publishes live in the same feed Grid already reads.

export const F0 = 60;

export const DEADBAND_HZ = Object.freeze({ standard: 0.017, mechanical: 0.034 });
export const BAND_HZ = Object.freeze({ normal: 0.030, ace: 0.090 });

export const UFLS_STAGES = Object.freeze([
  Object.freeze({ hz: 59.3, shedPct: 5, note: 'first stage: at least 5% of Transmission Operator load' }),
  Object.freeze({ hz: 58.9, shedPct: 15, note: 'second stage: at least 15% cumulative' }),
  Object.freeze({ hz: 58.5, shedPct: 25, note: 'third stage: at least 25% cumulative' }),
]);

// A sample pair is usable only if it is really a pair: ordered, finite, and
// close enough in time that one interval of the publisher's cadence separates
// them. A gap is never evidence. ODIN taught this rule and it holds here: a
// reading we cannot trust reads as unknown, never as an event.
export const SAMPLING = Object.freeze({ nominalMs: 10000, maxGapMs: 35000, minGapMs: 1000 });

// Defaults chosen from the physics above, overridable for tests.
export const DEFAULTS = Object.freeze({
  // A step must clear the mechanical-governor deadband to count. This is the
  // conservative choice of the two published deadbands: it costs sensitivity
  // and buys freedom from calling ordinary regulation a disturbance.
  stepHz: DEADBAND_HZ.mechanical,
  // The run-up must be quiet, or a ramp would read as a step.
  quietSamples: 3,
  quietSpreadHz: DEADBAND_HZ.standard,
  // After an event, stay silent until the trace settles, so one disturbance is
  // one event and not a burst of them.
  refractoryMs: 120000,
});

const isNum = (x) => typeof x === 'number' && Number.isFinite(x);

/** Usable consecutive pairs, with gaps and malformed samples dropped. */
export function pairs(hist, s = SAMPLING) {
  const out = [];
  if (!Array.isArray(hist)) return out;
  for (let i = 1; i < hist.length; i += 1) {
    const a = hist[i - 1], b = hist[i];
    if (!a || !b || !isNum(a.t) || !isNum(b.t) || !isNum(a.f) || !isNum(b.f)) continue;
    const dt = b.t - a.t;
    if (dt < s.minGapMs || dt > s.maxGapMs) continue;   // gap, duplicate or reorder
    out.push({ a, b, dtMs: dt, dHz: b.f - a.f, rocof: (b.f - a.f) / (dt / 1000) });
  }
  return out;
}

/**
 * Lower bound on the power imbalance behind an observed rate of change.
 *
 *   ΔP = 2·H·(df/dt)/f0
 *
 * Sampled every ~10 s this is a floor and not an estimate, for two reasons
 * that both push the same way: the measured slope is the mean over the whole
 * interval rather than the initial slope, and governor response is already
 * arresting the fall inside that interval. The true imbalance is larger —
 * typically by a large factor — so the number is only ever reported as "at
 * least". Returns null when inertia is not published, because without H there
 * is no bound to state and a guess would be worse than silence.
 */
export function lossFloorMw({ rocofHzPerS, inertiaMwS }) {
  if (!isNum(rocofHzPerS) || !isNum(inertiaMwS) || inertiaMwS <= 0) return null;
  return Math.abs(2 * inertiaMwS * rocofHzPerS / F0);
}

/** How far into ERCOT's own operating bands a frequency sits. */
export function severity(hz) {
  if (!isNum(hz)) return { level: 'unknown', text: 'no reading' };
  const dev = Math.abs(hz - F0);
  // The stages are cumulative, so report the deepest one reached, not the
  // first one crossed: below 58.5 Hz all three have fired and the honest
  // figure is 25% of load, not the 5% of the stage nearest 60 Hz.
  let deepest = null;
  for (const s of UFLS_STAGES) if (hz <= s.hz) deepest = s;
  if (deepest) return { level: 'ufls', stage: deepest, text: `at or below the ${deepest.hz} Hz load-shed stage` };
  if (dev > BAND_HZ.ace) return { level: 'beyond-ace', text: 'beyond the ±90 mHz ACE limit' };
  if (dev > BAND_HZ.normal) return { level: 'outside-normal', text: 'outside the ±30 mHz normal band' };
  return { level: 'normal', text: 'inside the ±30 mHz normal band' };
}

/**
 * Disturbances in a frequency trace.
 *
 * hist: [{ t: epoch ms, f: Hz }], oldest first — Grid's st.ercot.hist.
 * opts.inertiaMwS: system inertia from the same feed, for the floor.
 *
 * Each event carries what was measured and what was derived, kept apart:
 *   atMs, direction ('loss' | 'gain'), stepHz, rocofHzPerS, dtMs   measured
 *   nadirHz / peakHz, settledHz, deviationHz                       measured
 *   mwFloor                                                        derived
 */
export function detect(hist, opts = {}) {
  const o = { ...DEFAULTS, ...opts };
  const ps = pairs(hist, o.sampling || SAMPLING);
  const events = [];
  let silentUntil = -Infinity;

  for (let i = 0; i < ps.length; i += 1) {
    const p = ps[i];
    if (p.b.t < silentUntil) continue;
    if (Math.abs(p.dHz) < o.stepHz) continue;

    // The run-up has to be quiet, or a ramp reads as a step.
    const before = [];
    for (let k = i - 1; k >= 0 && before.length < o.quietSamples; k -= 1) {
      if (ps[k].b.t !== ps[k + 1].a.t) break;            // not contiguous: stop
      before.unshift(ps[k]);
    }
    if (before.length < o.quietSamples) continue;         // too little history to judge
    const run = before.map((q) => q.a.f).concat(p.a.f);
    if (Math.max(...run) - Math.min(...run) > o.quietSpreadHz) continue;

    // Follow the excursion to its extreme and to where it settles.
    const dir = p.dHz < 0 ? 'loss' : 'gain';
    let ext = p.b.f, settled = p.b.f, j = i + 1;
    for (; j < ps.length; j += 1) {
      if (ps[j].a.t !== ps[j - 1].b.t) break;             // a gap ends the window
      if (ps[j].b.t - p.b.t > o.refractoryMs) break;
      ext = dir === 'loss' ? Math.min(ext, ps[j].b.f) : Math.max(ext, ps[j].b.f);
      settled = ps[j].b.f;
    }

    const pre = p.a.f;
    events.push({
      atMs: p.b.t,
      direction: dir,
      preHz: pre,
      stepHz: p.dHz,
      dtMs: p.dtMs,
      rocofHzPerS: p.rocof,
      [dir === 'loss' ? 'nadirHz' : 'peakHz']: ext,
      extremeHz: ext,
      settledHz: settled,
      deviationHz: ext - F0,
      severity: severity(ext),
      mwFloor: lossFloorMw({ rocofHzPerS: p.rocof, inertiaMwS: opts.inertiaMwS }),
      // Said plainly, and carried with the event wherever it goes.
      basis: 'inferred from the ERCOT frequency trace; not a reported line trip',
    });
    silentUntil = p.b.t + o.refractoryMs;
  }
  return events;
}

/** The most recent event, or null. Convenience for the panel. */
export function latest(hist, opts = {}) {
  const e = detect(hist, opts);
  return e.length ? e[e.length - 1] : null;
}
