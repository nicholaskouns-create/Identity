// Your outlet's frequency from mains hum. Wiring, chargers, transformers and lamps put the grid's
// 60 Hz (and its harmonics) into almost every microphone signal. The worklet turns each harmonic into a
// slowly turning phasor; the frequency is 60 Hz plus the phasor's turning rate, read as the least-squares
// slope of its unwrapped phase over the last few seconds. Harmonics are combined by inverse variance.
//
// What it measures: the frequency of the interconnection you are plugged into, to a few millihertz.
// The device's audio clock sets the absolute accuracy (a 50 ppm crystal is 3 mHz at 60 Hz); changes,
// such as the dip after a large generator trips, are tracked more finely than that offset.

export function estimateEnf(blocks, { windowSec = 5, minSec = 2 } = {}) {
  if (!blocks.length) return { ready: false, progress: 0 };
  const dt = blocks[0].dt, W = Math.round(windowSec / dt), need = Math.round(minSec / dt);
  const b = blocks.slice(-W);
  if (b.length < need) return { ready: false, progress: b.length / need };
  const H = b[0].z.length, ests = [];
  const rms = b.reduce((a, c) => a + c.rms, 0) / b.length;
  for (let k = 0; k < H; k++) {
    const h = k + 1, n = b.length;
    let prev = null, off = 0, sx = 0, sy = 0, sxx = 0, sxy = 0, amp = 0, amp2 = 0;
    const ph = new Float64Array(n);
    for (let i = 0; i < n; i++) {
      const [re, im] = b[i].z[k];
      let p = Math.atan2(im, re) + off;
      if (prev !== null) {
        while (p - prev > Math.PI) { p -= 2 * Math.PI; off -= 2 * Math.PI; }
        while (p - prev < -Math.PI) { p += 2 * Math.PI; off += 2 * Math.PI; }
      }
      const a = Math.hypot(re, im);
      ph[i] = p; prev = p; amp += a; amp2 += a * a;
      const x = i * dt; sx += x; sy += p; sxx += x * x; sxy += x * p;
    }
    const den = n * sxx - sx * sx, slope = (n * sxy - sx * sy) / den, icpt = (sy - slope * sx) / n;
    let rss = 0;
    for (let i = 0; i < n; i++) { const r = ph[i] - (icpt + slope * i * dt); rss += r * r; }
    const resid = Math.sqrt(rss / Math.max(1, n - 2));
    const sdSlope = resid / Math.sqrt(sxx - (sx * sx) / n);
    const mean = amp / n, cv = Math.sqrt(Math.max(0, amp2 / n - mean * mean)) / (mean || 1e-12);
    ests.push({ h, hz: 60 * h, f: 60 + slope / (2 * Math.PI * h), sd: sdSlope / (2 * Math.PI * h), resid, cv, level: mean / (rms || 1e-12) });
  }
  // Mains hum is steady: its phase is coherent (residual under 0.5 rad), its level holds (variation under
  // 35 %), it is a visible share of the signal, and the grid it implies is within 0.25 Hz of 60.
  // Beeps, speech and music fail at least one of these.
  let good = ests.filter((e) => e.resid < 0.5 && e.cv < 0.35 && e.level > 0.004 && Math.abs(e.f - 60) <= 0.25 && Number.isFinite(e.sd) && e.sd > 0);
  // Harmonics of one hum agree; drop any that disagree with the weighted median.
  if (good.length > 1) {
    const sorted = good.slice().sort((a, b) => a.f - b.f), wt = sorted.map((e) => 1 / (e.sd * e.sd)), half = wt.reduce((a, c) => a + c, 0) / 2;
    let acc = 0, med = sorted[0].f;
    for (let i = 0; i < sorted.length; i++) { acc += wt[i]; if (acc >= half) { med = sorted[i].f; break; } }
    good = good.filter((e) => Math.abs(e.f - med) <= Math.max(0.005, 4 * e.sd));
  }
  if (!good.length) return { ready: true, ok: false, ests, rms };
  let w = 0, fw = 0;
  for (const e of good) { const wi = 1 / (e.sd * e.sd); w += wi; fw += wi * e.f; }
  return { ready: true, ok: true, f: fw / w, sd: Math.sqrt(1 / w), used: good.map((e) => e.hz), ests, rms };
}

export class EnfMeter {
  constructor(onUpdate) { this.onUpdate = onUpdate; this.blocks = []; this.running = false; }
  static supported() { return !!(navigator.mediaDevices && navigator.mediaDevices.getUserMedia && (window.AudioWorkletNode)); }
  async start() {
    this.stream = await navigator.mediaDevices.getUserMedia({ audio: { echoCancellation: false, noiseSuppression: false, autoGainControl: false, channelCount: 1 } });
    const AC = window.AudioContext || window.webkitAudioContext;
    this.ctx = new AC();
    await this.ctx.audioWorklet.addModule(new URL('./enf-worklet.js', import.meta.url));
    this.src = this.ctx.createMediaStreamSource(this.stream);
    this.node = new AudioWorkletNode(this.ctx, 'enf-hum', { numberOfInputs: 1, numberOfOutputs: 1, outputChannelCount: [1] });
    this.mute = this.ctx.createGain(); this.mute.gain.value = 0;
    this.src.connect(this.node); this.node.connect(this.mute); this.mute.connect(this.ctx.destination);
    this.node.port.onmessage = (e) => { this.blocks.push(e.data); if (this.blocks.length > 1200) this.blocks.splice(0, 200); this.onUpdate(estimateEnf(this.blocks), this); };
    if (this.ctx.state === 'suspended') await this.ctx.resume();
    this.running = true; this.started = Date.now();
  }
  stop() {
    this.running = false;
    try { this.src && this.src.disconnect(); } catch { /* already gone */ }
    try { this.node && this.node.disconnect(); this.node && this.node.port.close(); } catch { /* already gone */ }
    try { this.stream && this.stream.getTracks().forEach((t) => t.stop()); } catch { /* already gone */ }
    try { this.ctx && this.ctx.close(); } catch { /* already gone */ }
  }
}
