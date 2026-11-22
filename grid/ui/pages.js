// Auditor, Formalism and Sources pages.
import { CLASSES, CLASS_INFO, PIPES, PIPE_LABEL } from '../engine/monitor.js';
import { SOURCES, EVIDENCE } from '../live/sources.js';
import { replicaChart, networkChart, curveChart, spectrumChart } from './charts.js';
import { esc, ev, ago } from './panels.js';

const REPLICAS = [
  ['R1', 'Jacobi eigensolver', 'shared window-selection helper'],
  ['R2', 'Householder + implicit QL', 'shared window-selection helper'],
  ['R3', 'Matrix sign function (Newton)', 'no eigensolver'],
  ['R4', 'Resolvent subspace iteration', 'no eigensolver'],
  ['R5', 'Lanczos, full reorthogonalisation', 'shared window-selection helper'],
];

// --------------------------------------------------------------- auditor
export function buildAuditor(root, h) {
  root.innerHTML = `<div class="wrap">
  <div class="page-head"><div><div class="kicker">◇ Certified spectral monitor · EMS</div>
    <h2>Five replicas. One <em>pinned</em> reference.</h2>
    <p>The state vector goes to five replicas in parallel. Voting is compared with a validated residual, an independent reference and an anomaly detector. The auditor alone reads the SHA-256-pinned certificate instead of the runtime topology file, so it is the one check that does not share the fault source.</p></div>
    <div class="seg" role="group" aria-label="Test system"><button aria-pressed="true" data-sys="ieee14">IEEE 14-bus</button><button aria-pressed="false" data-sys="ieee118">IEEE 118-bus</button></div></div>
  <div class="banner" id="au-banner" data-d="deliver"><div class="verdict" id="au-verdict">STARTING</div><div id="au-reason" class="mono" style="color:var(--muted);font-size:12px"></div><div class="mono" id="au-clock" style="color:var(--faint);font-size:11px"></div></div>
  <div class="cards">
    <div class="card w8"><h3>Replica deviations</h3><div class="sub"><span>dev(y, x) = ‖y − P_d x‖ / ‖x‖ against τ = s(ε₀) + ρ</span>${ev('CERT')}</div>
      <canvas class="chart" id="au-replicas"></canvas>
      <table class="t" id="au-pipes"></table></div>
    <div class="card w4"><h3>Inject a fault</h3><div class="sub"><span>Common-mode classes</span>${ev('SIM')}</div>
      <div class="faults" id="au-faults"></div>
      <label class="toggle"><input type="checkbox" id="au-untouched"><span>One replica (R4) kept its pre-alteration copy</span></label>
      <p class="note" id="au-fault-detail"></p>
      <div class="rail-actions"><button class="btn accent" id="au-reprocess">↻ Reprocess topology from primary breaker status</button><button class="btn danger small" id="au-tamper">Tamper test: flip one byte of the certificate</button></div>
      <div class="kv" id="au-hashes" style="margin-top:10px"></div></div>
    <div class="card w8"><h3>The certified component across the network</h3><div class="sub"><span>Nodes placed by the window eigenvectors; colour = delivered P_d x</span><span id="au-net-note"></span></div><canvas class="chart" id="au-net"></canvas></div>
    <div class="card w4"><h3>Replicas</h3><div class="sub"><span>Deliberate diversity, shared substrate</span></div>
      <ul class="list">${REPLICAS.map(([r, a, b]) => `<li><span class="sw2" style="background:${b.startsWith('no') ? 'var(--cyan)' : 'var(--bronze)'}"></span><span><b>${r}</b> ${a}<br><small style="color:var(--faint)">${b}</small></span><span class="v" id="au-r-${r}"></span></li>`).join('')}</ul>
      <p class="note">All five share one substrate: a shared perturbation up to 0.8 ε₀ and per-replica jitter up to 0.1 ε₀. Input: <span id="au-input"></span></p></div>
    <div class="card w12"><h3>Console ledger</h3><div class="sub"><span>Hash-chained: each entry commits to the previous one · last certified state is kept on refusal</span><button class="btn small" id="au-export">Export NDJSON</button></div><div class="ledger" id="au-ledger"></div></div>
    <div class="card w12"><h3>Grid acceptance tests</h3><div class="sub"><span>Same harness on IEEE 14-bus and IEEE 118-bus, run in this browser · protocol KKP-GRID-ACCEPTANCE-1.0</span>${ev('SIM', 'seeded')}</div>
      <div class="rail-actions" style="grid-template-columns:repeat(4,auto);justify-content:start">
        <label class="toggle">IEEE 14 trials/class <input id="acc-n14" type="number" min="10" max="5000" step="10" value="240" style="width:80px"></label>
        <label class="toggle">IEEE 118 trials/class <input id="acc-n118" type="number" min="5" max="1000" step="5" value="40" style="width:80px"></label>
        <label class="toggle">Seed <input id="acc-seed" type="number" value="47" style="width:70px"></label>
        <button class="btn accent" id="acc-run">▶ Run acceptance tests</button></div>
      <div class="progress"><i id="acc-prog"></i></div><div class="mono" id="acc-status" style="color:var(--muted);font-size:12px"></div>
      <div id="acc-tables"></div></div>
  </div></div>`;
  root.querySelectorAll('[data-sys]').forEach((b) => b.addEventListener('click', () => h.setSystem(b.dataset.sys)));
  const faults = root.querySelector('#au-faults');
  faults.innerHTML = CLASSES.map((c) => `<button class="btn small" data-fault="${c}" aria-pressed="${c === 'L0'}">${c === 'L0' ? 'None (legitimate)' : c + ' · ' + CLASS_INFO[c].name}</button>`).join('');
  faults.querySelectorAll('[data-fault]').forEach((b) => b.addEventListener('click', () => h.setFault(b.dataset.fault)));
  root.querySelector('#au-untouched').addEventListener('change', (e) => h.setUntouched(e.target.checked));
  root.querySelector('#au-reprocess').addEventListener('click', () => h.reprocess());
  root.querySelector('#au-tamper').addEventListener('click', () => h.tamperTest());
  root.querySelector('#au-export').addEventListener('click', () => h.exportLedger());
  root.querySelector('#acc-run').addEventListener('click', () => h.runAcceptance({ n14: +root.querySelector('#acc-n14').value, n118: +root.querySelector('#acc-n118').value, seed: +root.querySelector('#acc-seed').value }));
}

export function updateAuditor(root, au) {
  if (!root.firstChild || !au) return;
  root.querySelectorAll('[data-sys]').forEach((b) => b.setAttribute('aria-pressed', String(b.dataset.sys === au.key)));
  root.querySelectorAll('[data-fault]').forEach((b) => b.setAttribute('aria-pressed', String(b.dataset.fault === au.fault)));
  root.querySelector('#au-fault-detail').textContent = CLASS_INFO[au.fault].detail;
  const o = au.outcome; if (!o) return;
  const d = o.auditor === 'deliver' ? 'deliver' : o.auditor === 'refuse' ? 'refuse' : 'select';
  const banner = root.querySelector('#au-banner'); banner.dataset.d = d;
  root.querySelector('#au-verdict').textContent = d === 'deliver' ? 'DELIVER CERTIFIED' : d === 'refuse' ? 'REFUSE' : `SELECT CERTIFIED · ${o.auditor.slice(7)}`;
  root.querySelector('#au-reason').textContent = d === 'deliver' ? `Voted output within τ (dev ${o.voteDev?.toExponential(2)}). Feeds contingency analysis, OPF and the console.`
    : d === 'select' ? `Voted output ${o.vote ? 'failed (dev ' + o.voteDev?.toExponential(2) + ')' : 'had no majority'}; ${o.auditor.slice(7)} passed and is delivered as certified.`
      : `No replica within τ. Last certified state held from ${au.lastCertified ? au.lastCertified.time.slice(11, 19) + 'Z' : '—'}. Topology reprocessing alarm raised.`;
  root.querySelector('#au-clock').textContent = `${au.label} · tick ${au.ticks}`;
  replicaChart(root.querySelector('#au-replicas'), o.dev, au.tol, ['R1', 'R2', 'R3', 'R4', 'R5'], { h: 150 });
  REPLICAS.forEach(([r], i) => { const e = root.querySelector('#au-r-' + r); if (e) { e.textContent = o.dev[i].toExponential(1); e.style.color = o.dev[i] > au.tol ? 'var(--hot)' : 'var(--mint)'; } });
  root.querySelector('#au-pipes').innerHTML = `<tr><th>Pipeline</th><th>Decision</th><th>Output vs truth</th></tr>` + PIPES.map((p) => {
    const [dec, harm] = o.pipelines[p];
    return `<tr><td>${PIPE_LABEL[p]}</td><td class="${dec === 'deliver' ? 'good' : 'warn'}">${dec === 'deliver' ? (p === 'certified_auditor' && o.auditor.startsWith('select') ? 'deliver · ' + o.auditor.slice(7) : 'deliver') : 'refuse'}</td><td class="${harm ? 'bad' : ''}">${dec === 'deliver' ? (harm ? 'harmful (known to the simulator)' : 'within τ of the true component') : '—'}</td></tr>`;
  }).join('');
  root.querySelector('#au-input').textContent = au.inputLabel;
  root.querySelector('#au-hashes').innerHTML = `<span>Certificate</span><b class="mono" title="${au.certHash}">${au.certHash.slice(0, 16)}…</b><span>Pinned topology</span><b class="mono" title="${au.pinnedTopoHash}">${au.pinnedTopoHash.slice(0, 16)}…</b><span>Runtime topology</span><b class="mono" style="color:${au.runtimeHash === au.pinnedTopoHash ? 'var(--mint)' : 'var(--hot)'}" title="${au.runtimeHash}">${au.runtimeHash.slice(0, 16)}…${au.runtimeHash === au.pinnedTopoHash ? '' : ' SUSPECT'}</b>${o.flippedBranch != null ? `<span>Altered entry</span><b>branch ${au.branchLabel}</b>` : ''}`;
  if (au.layout) {
    const vals = o.delivered || au.lastCertified?.y || o.pdx;
    const flag = o.flippedBranch != null ? au.branchPairs[o.flippedBranch] : null;
    networkChart(root.querySelector('#au-net'), au.layout, au.branchPairs, vals, { h: au.key === 'ieee118' ? 360 : 300, flagged: flag });
    root.querySelector('#au-net-note').innerHTML = o.delivered ? ev('CERT', 'delivered') : ev('CERT', 'last certified state');
  }
  root.querySelector('#au-ledger').innerHTML = au.ledger.slice(-60).reverse().map((e) => `<div><span>${e.time.slice(11, 19)}Z</span><span style="color:${e.decision === 'deliver' ? 'var(--mint)' : e.decision === 'refuse' ? 'var(--hot)' : 'var(--amber)'}">${esc(e.decision)}</span><span class="h">${esc(e.system)} · ${esc(e.fault)} · max dev ${e.maxDev.toExponential(2)} · prev ${e.prev.slice(0, 10)} → ${e.hash.slice(0, 10)}</span></div>`).join('');
}

export function renderAcceptance(root, runs, reference) {
  const el = root.querySelector('#acc-tables'); if (!el) return;
  el.innerHTML = Object.entries(runs).map(([key, r]) => {
    const ref = reference?.systems?.[key];
    const sameProto = ref && ref.trials_per_class === r.trials && ref.seed === r.seed;
    const agree = r.decisionsSha256 && sameProto ? (r.decisionsSha256 === ref.decisions_sha256 ? `<span class="ev ev-CERT">✦ identical to the Python reference, trial by trial (SHA-256 ${r.decisionsSha256.slice(0, 12)}…)</span>` : `<span class="ev ev-FAULT">✕ differs from the Python reference</span>`) : r.decisionsSha256 ? `<span class="ev ev-SIM">decision log SHA-256 ${r.decisionsSha256.slice(0, 12)}… (reference uses ${ref ? ref.trials_per_class + ' trials, seed ' + ref.seed : 'other settings'})</span>` : '';
    const t = r.table;
    const L0 = t.L0;
    return `<h3 style="margin-top:16px">${key === 'ieee14' ? 'IEEE 14-bus' : 'IEEE 118-bus'} <span class="mono" style="font-size:12px;color:var(--faint)">τ = ${r.tol?.toFixed(5) ?? ''} · ${r.trials} trials per class · seed ${r.seed}</span></h3>${agree}
    <table class="t"><tr><th>Class</th><th>Voted harmful</th>${PIPES.map((p) => `<th>${PIPE_LABEL[p]}<br>harmful passed</th>`).join('')}<th>Auditor selected</th><th>Auditor refused</th></tr>
    ${CLASSES.map((c) => { const row = t[c]; if (!row || !row.trials) return ''; return `<tr class="cls"><td>${c} · ${CLASS_INFO[c].name} <small style="color:var(--faint)">(${row.trials})</small></td><td>${row.voted_output_harmful}</td>${PIPES.map((p) => { const v = row.pipelines[p].harmful_passed; return `<td class="${v ? 'bad' : p === 'certified_auditor' ? 'good' : ''}">${v}</td>`; }).join('')}<td>${row.auditor_selected}</td><td>${row.auditor_refused}</td></tr>`; }).join('')}
    <tr><td colspan="${PIPES.length + 4}" style="text-align:left;color:var(--muted)">False alarms on legitimate trials: <b style="color:${L0.auditor_false_alarms ? 'var(--hot)' : 'var(--mint)'}">${L0.auditor_false_alarms}</b> of ${L0.trials} · largest legitimate deviation <b>${L0.largest_legitimate_dev.toExponential(3)}</b> against τ ${r.tol?.toFixed(5)} (factor ${(r.tol / (L0.largest_legitimate_dev || 1e-12)).toFixed(1)} to spare) · certified outputs delivered by auditor selection: <b>${CLASSES.reduce((a, c) => a + (t[c]?.auditor_selected || 0), 0)}</b></td></tr></table>`;
  }).join('') + `<p class="note">CM6 is the stated limit: the auditor certifies the spectral component of the input it receives, not the input itself. Input integrity and certificate pin integrity remain separate controls.</p>`;
}

// --------------------------------------------------------------- formalism
export function buildFormalism(root, h) {
  root.innerHTML = `<div class="wrap">
  <div class="page-head"><div><div class="kicker">◇ Formalism · Theorem G</div><h2>One pattern, <em>two</em> instantiations.</h2>
  <p>The E47 carrier is the closed reference: the pattern closes in Coq. The grid instantiation closes its own certificate by the same checker before it is pinned, and this page re-checks it in exact arithmetic.</p></div></div>
  <div class="cards">
    <div class="card w6"><h3>E47 reference instantiation</h3><div class="sub"><span>H = V₂ ⊗ V₂ ⊗ V₂ · computed here, now</span>${ev('MODEL', 'float64')}</div><div id="fx-e47" class="kv"></div>
      <div class="formula" style="margin-top:10px">K = (C − 6I)(C − 30I) <span class="c">  selector μ ∓ σ = 18 ∓ 12</span><br>Γ = I − K² / 99144 <span class="c">  ε* = 1/99144</span><br>‖Γⁿ − P‖ ≤ (15/17)ⁿ <span class="c">  equality at x* = P v + P₄₂ v</span></div></div>
    <div class="card w6"><h3>Contraction to ker K</h3><div class="sub"><span>‖Γⁿx − Px‖ / ‖x − Px‖</span><span><span style="color:var(--gold)">— (15/17)ⁿ</span> · <span style="color:var(--mint)">x*</span> · <span style="color:var(--cyan)">random x</span></span></div><canvas class="chart" id="fx-curve"></canvas></div>
    <div class="card w6"><h3>Grid certificate · IEEE 14-bus</h3><div class="sub"><span>General branch · exact inertia over ℚ</span>${ev('CERT')}</div><canvas class="chart" id="fx-spec-ieee14"></canvas><ul class="checks" id="fx-checks-ieee14"></ul></div>
    <div class="card w6"><h3>Grid certificate · IEEE 118-bus</h3><div class="sub"><span>General branch · exact inertia over ℚ</span>${ev('CERT')}</div><canvas class="chart" id="fx-spec-ieee118"></canvas><ul class="checks" id="fx-checks-ieee118"></ul>
      <button class="btn small" id="fx-verify-all">Verify all 122 inertia counts exactly (BigInt, ~10–40 s)</button></div>
    <div class="card w12"><h3>Transfer</h3><div class="sub"><span>Why τ is what it is</span></div>
      <div class="formula">For Â with ε = ‖Â − A‖ &lt; g/2, exactly r eigenvalues of Â lie within g/2 of Λ <span class="c">(Weyl)</span>, and the window projector moves by at most<br>   s(ε) = ε / (g − ε) <span class="c">(Davis–Kahan sin Θ with the Weyl-shifted gap)</span>. Radius g/2 is sharp.<br>Declared envelope ε₀ = g/40 ⇒ s(ε₀) = 1/39; ρ = 1/200 for float32 rounding and flow precision ⇒ τ = 1/39 + 1/200 = 239/7800 ≈ 0.030641.</div>
      <p>Legitimate replicas carry ‖Â − A‖ ≤ 0.9 ε₀, so their deviation is bounded by s(0.9 ε₀) ≈ 0.0230 before rounding. A topology alteration changes A itself; nothing bounds it, and the auditor’s pinned P_d sees it.</p></div>
    <div class="card w12"><h3>Evidence boundary</h3><div class="sub"><span>What each glyph promises</span></div>
      <table class="t">${Object.entries(EVIDENCE).map(([k, v]) => `<tr><td><span class="ev ev-${k}">${v.glyph} ${v.label}</span></td><td style="text-align:left;white-space:normal">${esc(v.note)}</td></tr>`).join('')}</table>
      <p class="note">The IEEE systems are standard test networks, not the live U.S. grid; their load level follows the live national demand ratio when a feed is available. The auditor certifies the spectral component of the input it receives, not the input itself.</p></div>
  </div></div>`;
  root.querySelector('#fx-verify-all').addEventListener('click', () => h.verifyAll('ieee118'));
}

export function updateFormalism(root, fx) {
  if (!root.firstChild) return;
  const e = fx.e47;
  if (e) {
    const lock = fx.lock?.canonical || {};
    const cmp = (a, b) => (JSON.stringify(a) === JSON.stringify(b) ? '<span style="color:var(--mint)">✓ lock</span>' : '<span style="color:var(--hot)">✕ lock</span>');
    root.querySelector('#fx-e47').innerHTML = `
      <span>Casimir spectrum</span><b>${e.spectrum.join(', ')} ${cmp(e.spectrum, lock.casimir_spectrum)}</b>
      <span>Sector dimensions</span><b>${e.multiplicities.join(', ')} ${cmp(e.multiplicities, lock.sector_dimensions)}</b>
      <span>tr P = dim ker K</span><b>${e.traceP.toFixed(10)} ${cmp(Math.round(e.traceP), lock.kernel_dimension)}</b>
      <span>Ω_c = 47/125</span><b>${e.omega.toFixed(12)}</b>
      <span>‖P² − P‖, ‖K P‖</span><b>${e.idempotencyDefect.toExponential(1)}, ${e.kernelDefect.toExponential(1)}</b>
      <span>K² gap, max</span><b>${e.qGap}, ${e.qMax} ${cmp([e.qGap, e.qMax], [lock.q_gap, lock.q_max])}</b>
      <span>Rate on the complement</span><b>${e.rate.toFixed(12)} = 15/17 ${cmp('15/17', lock.rho_star)}</b>
      <span>Contract source</span><b>${esc(fx.lockSource || '')}</b>
      <span>Computed in</span><b>${e.ms.toFixed(0)} ms</b>`;
    curveChart(root.querySelector('#fx-curve'), [
      { values: e.curves.bound, color: '#f1e3b8', width: 2.2 },
      { values: e.curves.extremal, color: '#c1e8ce', dash: [5, 4], width: 1.6 },
      { values: e.curves.random, color: '#6edfd4', width: 1.4 },
    ], { h: 230 });
  }
  for (const key of ['ieee14', 'ieee118']) {
    const rep = fx.reports?.[key], sys = fx.systems?.[key];
    if (sys) spectrumChart(root.querySelector('#fx-spec-' + key), sys, { h: 120 });
    const ul = root.querySelector('#fx-checks-' + key);
    if (rep && ul) ul.innerHTML = rep.checks.map((c) => `<li><span class="${c.ok ? 'ok' : 'no'}">${c.ok ? '✦' : '✕'}</span><span>${esc(c.label)}<small>${esc(c.detail)}</small></span></li>`).join('') + `<li><span></span><span><small>${rep.exactCounts}/${rep.totalCounts} inertia counts recomputed exactly (${rep.scope}) in ${rep.ms.toFixed(0)} ms</small></span></li>`;
  }
}

// --------------------------------------------------------------- sources
export function buildSources(root, h) {
  root.innerHTML = `<div class="wrap">
  <div class="page-head"><div><div class="kicker">◇ Sources · settings</div><h2>Every number has an <em>address</em>.</h2>
  <p>Grid reads public publishers directly from your browser where they allow it. Operators that block browser access are read by the relay, a scheduled GitHub Actions job in this repository that publishes a snapshot branch. Nothing is filled in when a source is down.</p></div></div>
  <div class="cards">
    <div class="card w12"><table class="t src-table" id="src-table"></table></div>
    <div class="card w6"><h3>EIA-930 key</h3><div class="sub"><span>Free, instant · stored only in this browser</span></div>
      <p>Register at <a href="https://www.eia.gov/opendata/register.php" target="_blank" rel="noopener">eia.gov/opendata</a>, then paste the key here. For the relay, add the same key as a repository secret named <code>EIA_API_KEY</code>.</p>
      <label class="field"><span class="eyebrow">API key</span><input id="set-eia" autocomplete="off" spellcheck="false" placeholder="40-character key"></label>
      <div class="rail-actions" style="grid-template-columns:auto auto;justify-content:start"><button class="btn accent" id="set-save">Save and fetch</button><button class="btn" id="set-clear">Forget key</button></div>
      <label class="field"><span class="eyebrow">Relay snapshot URL</span><input id="set-relay" spellcheck="false"></label></div>
    <div class="card w6"><h3>Instrument controls</h3><div class="sub"><span>Browser capabilities, all opt-in</span></div>
      <div class="rail-actions">
        <button class="btn accent" id="set-alerts">⚑ Background alerts for your counties: outages, power back, severe weather. Works with Grid closed</button>
        <button class="btn" id="set-notify">🔔 While Grid is open: notify me on auditor refusal, Kp ≥ 6, or a new extreme warning at my position</button>
        <button class="btn" id="set-wall">▣ Wall mode: full screen, keep the screen awake</button>
        <button class="btn" id="set-install" hidden>⤓ Install Grid as an app (works offline)</button></div>
      <p class="note" id="set-status"></p>
      <p class="note">Privacy: your GPS position stays on this device. The only place it leaves is the bounding box of an OpenStreetMap Overpass query when you ask for the local grid. The EIA key is sent only to api.eia.gov. Background alerts keep this device’s push address, the counties you chose and your alert choices on Grid’s server, nothing else; turning them off deletes them. The medical-equipment setting never leaves this device.</p></div>
    <div class="card w12" id="src-doors"><h3>Doorways</h3><div class="sub"><span>Where Grid is linked from · survey of every published page</span></div><p class="note">Reading the survey…</p></div>
  </div></div>`;
  fetch('data/surfaces.json').then((r) => (r.ok ? r.json() : null)).then((d) => renderDoors(root.querySelector('#src-doors'), d)).catch((e) => { console.error('doorway survey', e); renderDoors(root.querySelector('#src-doors'), null); });
  root.querySelector('#set-save').addEventListener('click', () => h.saveKey(root.querySelector('#set-eia').value.trim(), root.querySelector('#set-relay').value.trim()));
  root.querySelector('#set-clear').addEventListener('click', () => h.saveKey('', root.querySelector('#set-relay').value.trim()));
  root.querySelector('#set-alerts').addEventListener('click', () => h.openAlerts());
  root.querySelector('#set-notify').addEventListener('click', () => h.enableNotify());
  root.querySelector('#set-wall').addEventListener('click', () => h.wallMode());
  root.querySelector('#set-install').addEventListener('click', () => h.install());
}

function renderDoors(card, d) {
  if (!card) return;
  if (!d || !Array.isArray(d.surfaces)) { card.querySelector('.note').textContent = 'The survey file is not available in this copy.'; return; }
  const groups = new Map(), pages = d.surfaces.filter((x) => x.url);
  for (const x of pages) { if (!groups.has(x.repo)) groups.set(x.repo, []); groups.get(x.repo).push(x); }
  const site = (list) => { const u = list[0].url; const m = u.match(/^https:\/\/[^/]+\/([^/]+\/)?/); const root = m ? m[0] : u; return list.every((x) => x.url.startsWith(root)) ? root : u.replace(/[^/]*$/, ''); };
  const hubs = pages.filter((x) => x.lead).length;
  const tpl = (d.templates || []).length ? ` The generator template${d.templates.length > 1 ? 's' : ''} ${d.templates.map((t) => `<code>${esc(t)}</code>`).join(', ')} carr${d.templates.length > 1 ? 'y' : 'ies'} the doorway too, so regenerated pages keep it.` : '';
  const rows = [...groups.entries()].sort((a, b) => b[1].length - a[1].length).map(([repo, list]) => {
    const lead = list.filter((x) => x.lead).length;
    return `<tr><td style="text-align:left"><a href="${esc(site(list))}" target="_blank" rel="noopener">${esc(repo)}</a></td><td>${list.length}</td><td>${lead || '—'}</td></tr>`;
  }).join('');
  const all = [...groups.entries()].map(([repo, list]) => `<li><b>${esc(repo)}</b><ol>${list.map((x) => `<li><a href="${esc(x.url)}" target="_blank" rel="noopener">${esc(x.title || x.path)}</a>${x.lead ? ' <small class="lead-tag">lead card</small>' : ''}</li>`).join('')}</ol></li>`).join('');
  card.innerHTML = `<h3>Doorways</h3><div class="sub"><span>Where Grid is linked from · ${esc(d.schema || 'survey')}</span></div>
    <p>${pages.length} site pages across ${groups.size} repositories open Grid: a corner doorway on every page, and a lead card on ${hubs} hub pages. The doorway is plain HTML, so it works with scripts off; a small script moves it clear of each page's own controls and shows a live reading from the relay.${tpl}</p>
    <table class="t doors-table"><tr><th style="text-align:left">Repository</th><th>Pages</th><th>Lead cards</th></tr>${rows}</table>
    <details class="doors-all"><summary>All ${pages.length} pages</summary><ul>${all}</ul></details>`;
}

export function updateSources(root, st, settings) {
  const tb = root.querySelector('#src-table'); if (!tb) return;
  const relay = root.querySelector('#set-relay'); if (relay && !relay.value) relay.value = settings.relayUrl;
  const key = root.querySelector('#set-eia'); if (key && !key.value && settings.eiaKey) key.value = settings.eiaKey;
  tb.innerHTML = `<colgroup><col class="c1"><col class="c2"><col class="c3"><col class="c4"><col class="c5"></colgroup><tr><th>Source</th><th>Publisher</th><th>Evidence</th><th>Status</th><th>Updated</th></tr>` + SOURCES.map((s) => {
    const x = st.status[s.id] || {};
    const dot = x.state === 'ok' ? 'ok' : x.state === 'error' ? 'err' : x.state === 'loading' ? 'warn' : 'idle';
    return `<tr><td><a href="${esc(s.url)}" target="_blank" rel="noopener">${esc(s.label)}</a><br><small style="color:var(--faint)">${esc(s.why)}</small></td><td style="text-align:left">${esc(s.provider)}</td><td>${ev(s.evidence)}</td><td style="text-align:left"><span class="dot ${dot}"></span> ${esc(x.state || 'idle')}${x.detail ? `<br><small style="color:var(--faint)">${esc(x.detail)}</small>` : ''}</td><td>${x.at ? ago(x.at) : '—'}${s.cadence ? `<br><small style="color:var(--faint)">every ${s.cadence >= 60 ? s.cadence / 60 + ' min' : s.cadence + ' s'}</small>` : ''}</td></tr>`;
  }).join('');
}
