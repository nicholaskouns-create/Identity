// AudioWorklet: mains-hum phasors for Grid's outlet frequency meter.
// Mixes the microphone signal with 60·k Hz references (k = 1…6) and integrates over 0.1 s blocks.
// A 0.1 s boxcar has nulls at every multiple of 10 Hz, so each harmonic's phasor is free of the others
// and of DC. The reference phase index runs modulo one 60 Hz period (sampleRate / 60 samples), so the
// table lookup stays exact for hours. Only these phasors leave the audio thread; no audio is kept.
class EnfHum extends AudioWorkletProcessor {
  constructor() {
    super();
    this.H = 6;
    this.N = Math.round(sampleRate / 10);
    this.P = sampleRate / 60;
    this.useTable = Number.isInteger(this.P);
    if (this.useTable) {
      this.cos = new Float64Array(this.P); this.sin = new Float64Array(this.P);
      for (let i = 0; i < this.P; i++) { const a = (2 * Math.PI * i) / this.P; this.cos[i] = Math.cos(a); this.sin[i] = Math.sin(a); }
    }
    this.re = new Float64Array(this.H); this.im = new Float64Array(this.H);
    this.t = 0; this.n = 0; this.e = 0; this.blocks = 0;
  }
  process(inputs) {
    const x = inputs[0] && inputs[0][0];
    if (!x) return true;
    const H = this.H, P = this.P;
    for (let i = 0; i < x.length; i++) {
      const v = x[i];
      this.e += v * v;
      if (this.useTable) {
        for (let k = 1; k <= H; k++) { const j = (k * this.t) % P; this.re[k - 1] += v * this.cos[j]; this.im[k - 1] -= v * this.sin[j]; }
        this.t = (this.t + 1) % P;
      } else {
        for (let k = 1; k <= H; k++) { const a = (2 * Math.PI * 60 * k * this.t) / sampleRate; this.re[k - 1] += v * Math.cos(a); this.im[k - 1] -= v * Math.sin(a); }
        this.t++;
      }
      if (++this.n === this.N) {
        const z = new Array(H);
        for (let k = 0; k < H; k++) { z[k] = [this.re[k] / this.N, this.im[k] / this.N]; this.re[k] = 0; this.im[k] = 0; }
        this.port.postMessage({ z, rms: Math.sqrt(this.e / this.N), dt: this.N / sampleRate, seq: this.blocks++ });
        this.n = 0; this.e = 0;
      }
    }
    return true;
  }
}
registerProcessor('enf-hum', EnfHum);
