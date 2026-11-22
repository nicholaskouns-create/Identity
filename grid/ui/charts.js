// High-resolution canvas charts (device-pixel-ratio aware) in the City palette.
export const C = { bg: '#090b0d', line: '#243138', soft: '#1a242a', fg: '#edf2ef', muted: '#98a6a8', faint: '#657478', cyan: '#6edfd4', mint: '#c1e8ce', bronze: '#bc9c6c', hot: '#d87e74', amber: '#d9b45f', gold: '#f1e3b8' };

export function prep(canvas, cssH) {
  const dpr = Math.min(3, window.devicePixelRatio || 1);
  const w = canvas.clientWidth || canvas.parentElement.clientWidth || 300;
  const h = cssH || canvas.clientHeight || 60;
  canvas.style.height = h + 'px';
  if (canvas.width !== Math.round(w * dpr) || canvas.height !== Math.round(h * dpr)) { canvas.width = Math.round(w * dpr); canvas.height = Math.round(h * dpr); }
  const ctx = canvas.getContext('2d'); ctx.setTransform(dpr, 0, 0, dpr, 0, 0); ctx.clearRect(0, 0, w, h);
  return { ctx, w, h };
}

export function sparkline(canvas, values, { h = 22, color = C.cyan, fill = true } = {}) {
  const { ctx, w } = prep(canvas, h);
  const v = values.filter(Number.isFinite); if (v.length < 2) return;
  const lo = Math.min(...v), hi = Math.max(...v), span = hi - lo || 1;
  const X = (i) => (i / (values.length - 1)) * (w - 2) + 1, Y = (x) => h - 2 - ((x - lo) / span) * (h - 5);
  ctx.beginPath(); values.forEach((x, i) => { if (Number.isFinite(x)) (i ? ctx.lineTo(X(i), Y(x)) : ctx.moveTo(X(i), Y(x))); });
  ctx.strokeStyle = color; ctx.lineWidth = 1.3; ctx.stroke();
  if (fill) { ctx.lineTo(X(values.length - 1), h); ctx.lineTo(X(0), h); ctx.closePath(); const g = ctx.createLinearGradient(0, 0, 0, h); g.addColorStop(0, color + '40'); g.addColorStop(1, color + '00'); ctx.fillStyle = g; ctx.fill(); }
  const lx = X(values.length - 1), ly = Y(values.at(-1)); ctx.fillStyle = color; ctx.beginPath(); ctx.arc(lx, ly, 2.2, 0, Math.PI * 2); ctx.fill();
}

/** Demand vs forecast over hours: series [{t,v}] (actual) and [{t,v}] (forecast). */
export function demandChart(canvas, actual, forecast, { h = 96 } = {}) {
  const { ctx, w } = prep(canvas, h);
  const all = [...actual, ...forecast].filter((p) => Number.isFinite(p.v));
  if (all.length < 2) return;
  const ts = all.map((p) => Date.parse(p.t + (p.t.length === 13 ? ':00:00Z' : ''))), t0 = Math.min(...ts), t1 = Math.max(...ts);
  const vs = all.map((p) => p.v), lo = Math.min(...vs) * 0.97, hi = Math.max(...vs) * 1.02;
  const X = (t) => 30 + ((Date.parse(t + (t.length === 13 ? ':00:00Z' : '')) - t0) / (t1 - t0 || 1)) * (w - 36);
  const Y = (v) => h - 14 - ((v - lo) / (hi - lo || 1)) * (h - 22);
  ctx.font = '9px "IBM Plex Mono", monospace'; ctx.fillStyle = C.faint; ctx.strokeStyle = C.soft; ctx.lineWidth = 1;
  for (let k = 0; k <= 2; k++) { const v = lo + (k / 2) * (hi - lo), y = Y(v); ctx.beginPath(); ctx.moveTo(30, y); ctx.lineTo(w - 4, y); ctx.stroke(); ctx.fillText(Math.round(v / 1000) + '', 2, y + 3); }
  const draw = (s, col, dash) => { ctx.setLineDash(dash); ctx.beginPath(); let first = true; for (const p of s) { if (!Number.isFinite(p.v)) continue; const x = X(p.t), y = Y(p.v); first ? ctx.moveTo(x, y) : ctx.lineTo(x, y); first = false; } ctx.strokeStyle = col; ctx.lineWidth = 1.6; ctx.stroke(); ctx.setLineDash([]); };
  draw(forecast, C.bronze, [4, 3]); draw(actual, C.mint, []);
  const last = actual.filter((p) => Number.isFinite(p.v)).at(-1);
  if (last) { ctx.fillStyle = C.mint; ctx.beginPath(); ctx.arc(X(last.t), Y(last.v), 3, 0, Math.PI * 2); ctx.fill(); }
  ctx.fillStyle = C.faint; ctx.fillText('GW', 2, 10);
}

export function kpBars(canvas, rows, { h = 54 } = {}) {
  const { ctx, w } = prep(canvas, h);
  const r = rows.slice(-24); if (!r.length) return;
  const bw = (w - 4) / r.length;
  r.forEach((p, i) => {
    const kp = p.kp, bh = (kp / 9) * (h - 12);
    ctx.fillStyle = kp >= 7 ? C.hot : kp >= 5 ? C.amber : kp >= 4 ? C.gold : C.cyan;
    ctx.globalAlpha = 0.85; ctx.fillRect(2 + i * bw + 1, h - 10 - bh, bw - 2, bh); ctx.globalAlpha = 1;
  });
  ctx.strokeStyle = 'rgba(217,180,95,.5)'; ctx.setLineDash([3, 3]); const y5 = h - 10 - (5 / 9) * (h - 12); ctx.beginPath(); ctx.moveTo(0, y5); ctx.lineTo(w, y5); ctx.stroke(); ctx.setLineDash([]);
  ctx.fillStyle = C.faint; ctx.font = '8.5px "IBM Plex Mono", monospace'; ctx.fillText('G1', w - 16, y5 - 2); ctx.fillText('3-h Kp · 72 h', 2, h - 1);
}

/** Log-scale deviation bars per replica against τ. */
export function replicaChart(canvas, dev, tol, labels, { h = 150, colors } = {}) {
  const { ctx, w } = prep(canvas, h);
  const lo = 1e-6, hi = Math.max(1, ...dev.filter(Number.isFinite));
  const X = (v) => 46 + (Math.log10(Math.max(lo, v)) - Math.log10(lo)) / (Math.log10(hi) - Math.log10(lo)) * (w - 56);
  const rowH = (h - 20) / dev.length;
  ctx.font = '10px "IBM Plex Mono", monospace';
  for (let e = -6; e <= Math.log10(hi); e++) { const x = X(10 ** e); ctx.strokeStyle = C.soft; ctx.beginPath(); ctx.moveTo(x, 4); ctx.lineTo(x, h - 16); ctx.stroke(); ctx.fillStyle = C.faint; ctx.fillText(`1e${e}`, x - 10, h - 4); }
  dev.forEach((d, i) => {
    const y = 6 + i * rowH, bad = d > tol;
    ctx.fillStyle = C.muted; ctx.fillText(labels[i], 4, y + rowH / 2 + 3);
    ctx.fillStyle = (colors && colors[i]) || (bad ? C.hot : C.mint); ctx.globalAlpha = 0.9;
    ctx.fillRect(46, y + rowH * 0.2, Math.max(1, X(d) - 46), rowH * 0.56); ctx.globalAlpha = 1;
  });
  const xt = X(tol); ctx.strokeStyle = C.gold; ctx.lineWidth = 1.5; ctx.shadowColor = C.gold; ctx.shadowBlur = 6; ctx.beginPath(); ctx.moveTo(xt, 2); ctx.lineTo(xt, h - 16); ctx.stroke(); ctx.shadowBlur = 0;
  ctx.fillStyle = C.gold; ctx.fillText('τ', xt + 4, 12);
}

/** Network one-line view: nodes coloured by a vector component (the certified window component). */
export function networkChart(canvas, layout, branches, values, { h = 300, flagged = null, title = '' } = {}) {
  const { ctx, w } = prep(canvas, h);
  const xs = layout.map((p) => p[0]), ys = layout.map((p) => p[1]);
  const x0 = Math.min(...xs), x1 = Math.max(...xs), y0 = Math.min(...ys), y1 = Math.max(...ys);
  const pad = 18, sx = (w - 2 * pad) / (x1 - x0 || 1), sy = (h - 2 * pad) / (y1 - y0 || 1), s = Math.min(sx, sy);
  const ox = (w - s * (x1 - x0)) / 2, oy = (h - s * (y1 - y0)) / 2;
  const P = (i) => [ox + (layout[i][0] - x0) * s, oy + (layout[i][1] - y0) * s];
  const vmax = Math.max(1e-12, ...values.map(Math.abs));
  for (const br of branches) {
    const [a, b] = [P(br.i), P(br.j)];
    const isFlag = flagged && flagged.i === br.i && flagged.j === br.j;
    ctx.strokeStyle = isFlag ? C.hot : br.on ? 'rgba(110,223,212,.32)' : 'rgba(216,126,116,.35)';
    ctx.lineWidth = isFlag ? 2.4 : br.on ? 1 : 1; if (!br.on || isFlag) ctx.setLineDash([4, 3]);
    ctx.beginPath(); ctx.moveTo(a[0], a[1]); ctx.lineTo(b[0], b[1]); ctx.stroke(); ctx.setLineDash([]);
  }
  values.forEach((v, i) => {
    const [x, y] = P(i), t = v / vmax, r = 2.6 + 3.2 * Math.abs(t);
    const col = t >= 0 ? `rgba(193,232,206,${0.35 + 0.65 * Math.abs(t)})` : `rgba(217,180,95,${0.35 + 0.65 * Math.abs(t)})`;
    const g = ctx.createRadialGradient(x, y, 0, x, y, r * 3.2); g.addColorStop(0, col); g.addColorStop(1, 'rgba(0,0,0,0)');
    ctx.fillStyle = g; ctx.beginPath(); ctx.arc(x, y, r * 3.2, 0, Math.PI * 2); ctx.fill();
    ctx.fillStyle = col; ctx.beginPath(); ctx.arc(x, y, r, 0, Math.PI * 2); ctx.fill();
  });
  if (title) { ctx.fillStyle = C.faint; ctx.font = '10px "IBM Plex Mono", monospace'; ctx.fillText(title, 6, 12); }
}

/** Contraction curves on a log axis. */
export function curveChart(canvas, series, { h = 220, n = 60 } = {}) {
  const { ctx, w } = prep(canvas, h);
  const lo = 1e-5, X = (k) => 40 + (k / n) * (w - 52), Y = (v) => 10 + (Math.log10(Math.max(lo, v)) / Math.log10(lo)) * (h - 34);
  ctx.font = '10px "IBM Plex Mono", monospace';
  for (let e = 0; e >= -5; e--) { const y = Y(10 ** e); ctx.strokeStyle = C.soft; ctx.beginPath(); ctx.moveTo(40, y); ctx.lineTo(w - 8, y); ctx.stroke(); ctx.fillStyle = C.faint; ctx.fillText(`1e${e}`, 4, y + 3); }
  for (let k = 0; k <= n; k += 10) { ctx.fillStyle = C.faint; ctx.fillText(String(k), X(k) - 6, h - 6); }
  for (const s of series) {
    ctx.setLineDash(s.dash || []); ctx.strokeStyle = s.color; ctx.lineWidth = s.width || 1.6; ctx.beginPath();
    s.values.forEach((v, k) => (k ? ctx.lineTo(X(k), Y(v)) : ctx.moveTo(X(k), Y(v)))); ctx.stroke(); ctx.setLineDash([]);
  }
  ctx.fillStyle = C.faint; ctx.fillText('n', w - 14, h - 6);
}

/** Spectrum strip: eigenvalues as ticks, Λ window, g/2 radius, perturbed estimates. */
export function spectrumChart(canvas, { lam, lo, hi, g, eps0, est }, { h = 120 } = {}) {
  const { ctx, w } = prep(canvas, h);
  const vmax = Math.max(...lam.slice(0, 8)) * 1.08, X = (v) => 14 + (v / vmax) * (w - 28);
  const y = h / 2;
  ctx.strokeStyle = C.line; ctx.beginPath(); ctx.moveTo(10, y); ctx.lineTo(w - 10, y); ctx.stroke();
  ctx.fillStyle = 'rgba(241,227,184,.08)'; ctx.fillRect(X(lo - g / 2), y - 30, X(hi + g / 2) - X(lo - g / 2), 60);
  ctx.strokeStyle = 'rgba(241,227,184,.55)'; ctx.setLineDash([3, 3]); ctx.strokeRect(X(lo - g / 2), y - 30, X(hi + g / 2) - X(lo - g / 2), 60); ctx.setLineDash([]);
  ctx.fillStyle = 'rgba(193,232,206,.14)'; ctx.fillRect(X(lo), y - 18, Math.max(2, X(hi) - X(lo)), 36);
  lam.slice(0, 8).forEach((v, i) => { const inW = v >= lo && v <= hi; ctx.strokeStyle = inW ? C.mint : C.muted; ctx.lineWidth = inW ? 2 : 1.2; ctx.beginPath(); ctx.moveTo(X(v), y - 14); ctx.lineTo(X(v), y + 14); ctx.stroke(); ctx.fillStyle = C.faint; ctx.font = '9.5px "IBM Plex Mono", monospace'; ctx.fillText(`λ${i + 1}`, X(v) - 7, y + 26); });
  if (est) est.forEach((v) => { ctx.fillStyle = C.cyan; ctx.beginPath(); ctx.arc(X(v), y - 22, 2, 0, Math.PI * 2); ctx.fill(); });
  ctx.fillStyle = C.gold; ctx.font = '10px "IBM Plex Mono", monospace'; ctx.fillText('window Λ ± g/2', X(lo - g / 2) + 3, y - 34);
  ctx.fillStyle = C.faint; ctx.fillText(`ε₀ = ${eps0.toPrecision(3)}  ·  g = ${g.toPrecision(4)}`, 12, h - 6);
}
