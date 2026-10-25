import { ARMS, summarize, compare } from './ablation-math.mjs';
import { sha256Hex } from './ablation-provenance.mjs';
const $ = id => document.getElementById(id);
const fmt = x => x.toFixed(5);
const sign = x => `${x >= 0 ? '+' : ''}${fmt(x)}`;
const sourceUrls = [
  '../experiments/e47_ablation_results.json',
  'https://raw.githubusercontent.com/nicholaskouns-create/Identity/main/experiments/e47_ablation_results.json'
];
const el = (tag, value) => {
  const node = document.createElement(tag);
  if (value !== undefined) node.textContent = String(value);
  return node;
};
function download(obj, name) {
  const url = URL.createObjectURL(new Blob([JSON.stringify(obj, null, 2)], {type: 'application/json'}));
  const anchor = el('a'); anchor.href = url; anchor.download = name;
  document.body.append(anchor); anchor.click(); anchor.remove();
  setTimeout(() => URL.revokeObjectURL(url), 1000);
}
async function load() {
  const errors = [];
  for (const url of sourceUrls) {
    // Bound each attempt, including a stalled response body, so fallback and
    // the manual retry control remain reachable during network interruptions.
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), 8000);
    try {
      const response = await fetch(url, {cache: 'no-store', signal: controller.signal});
      if (!response.ok) throw new Error(`HTTP ${response.status}`);
      const jsonText = await response.text();
      const raw = JSON.parse(jsonText);
      const summary = summarize(raw);
      // Fingerprint the exact fetched UTF-8 bytes, not a reserialized JSON object.
      // Missing WebCrypto must not make the archived statistics unavailable.
      const sha256 = globalThis.crypto?.subtle ? await sha256Hex(jsonText) : null;
      return {raw, summary, source: new URL(url, location.href).href, sha256};
    } catch (error) {
      const reason = error.name === 'AbortError' ? 'timed out after 8 seconds' : error.message;
      errors.push(`${url}: ${reason}`);
    } finally {
      clearTimeout(timeout);
    }
  }
  throw new Error('Results could not be loaded from GitHub Pages or the raw repository. ' + errors.join('; '));
}
function paint({raw, summary, source, sha256}) {
  $('load-status').textContent = `Loaded ${summary.seeds} archived synthetic seeds. Source: ${source}`;
  $('source-digest').textContent = sha256
    ? `Fetched JSON SHA-256: ${sha256}. This is a content fingerprint, not a signature or independent authenticity check.`
    : 'SHA-256 fingerprint unavailable in this browser; statistics remain viewable.';
  const armLabels = Object.fromEntries(ARMS);
  const root = $('results-body'); root.replaceChildren();
  const bars = $('bars'); bars.replaceChildren();
  for (const [id, label] of ARMS) {
    const arm = summary.arms[id];
    const row = el('tr');
    [label, fmt(arm.mean), fmt(arm.sd), sign(arm.deltaBaseline)].forEach((value, index) => {
      const cell = el(index === 0 ? 'th' : 'td', value);
      if (index === 0) cell.scope = 'row';
      row.append(cell);
    });
    root.append(row);
    const wrap = el('div'); wrap.className = 'bar-row';
    const caption = el('span', label); caption.className = 'bar-caption';
    const track = el('div'); track.className = 'bar-track';
    track.setAttribute('role', 'img');
    track.setAttribute('aria-label', `${label}: ${fmt(arm.mean)} mean ROC-AUC`);
    const fill = el('div'); fill.className = 'bar-fill'; fill.style.width = `${arm.mean * 100}%`;
    track.append(fill);
    const value = el('span', fmt(arm.mean)); value.className = 'bar-value';
    wrap.append(caption, track, value); bars.append(wrap);
  }
  const left = $('arm-left'); const right = $('arm-right');
  for (const select of [left, right]) {
    select.replaceChildren();
    for (const [id, label] of ARMS) {
      const option = el('option', label); option.value = id; select.append(option);
    }
  }
  left.value = 'E47derived24'; right.value = 'random24';
  function updateComparison() {
    const result = compare(summary, left.value, right.value);
    $('left-auc-header').textContent = `${armLabels[left.value]} AUC`;
    $('right-auc-header').textContent = `${armLabels[right.value]} AUC`;
    $('comparison').textContent = `Mean paired Δ AUC: ${sign(result.meanDifference)} · Wins / ties / losses: ${result.wins} / ${result.ties} / ${result.losses} (n=${summary.seeds})`;
    const body = $('seed-body'); body.replaceChildren();
    for (let i = 0; i < summary.seeds; i++) {
      const tr = el('tr');
      [i + 1, fmt(summary.arms[left.value].values[i]), fmt(summary.arms[right.value].values[i]), sign(result.differences[i])].forEach((value, index) => {
        const cell = el(index === 0 ? 'th' : 'td', value);
        if (index === 0) cell.scope = 'row';
        tr.append(cell);
      });
      body.append(tr);
    }
    $('export').onclick = () => download({source, source_sha256: sha256, source_sha256_scope: 'Exact fetched JSON bytes; content fingerprint, not an authenticity signature', exported_at: new Date().toISOString(), evidence_class: 'synthetic', archived_results: raw, summary, paired_comparison: result}, 'e47-ablation-view.json');
  }
  left.addEventListener('change', updateComparison);
  right.addEventListener('change', updateComparison);
  updateComparison();
  $('data-panel').hidden = false;
}
const retryButton = $('retry-load');
async function refresh() {
  retryButton.hidden = true;
  $('data-panel').hidden = true;
  $('load-status').classList.remove('error');
  $('load-status').textContent = 'Loading archived results…';
  $('source-digest').textContent = '';
  try {
    paint(await load());
  } catch (error) {
    $('load-status').textContent = error.message;
    $('load-status').classList.add('error');
    retryButton.hidden = false;
  }
}
retryButton.addEventListener('click', refresh);
refresh();
