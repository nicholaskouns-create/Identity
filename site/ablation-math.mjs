/** Pure, dependency-free statistics for the archived E47 synthetic ablation. */
export const ARMS = Object.freeze([
  ['baseline64', 'Original 64D'],
  ['random24', 'Random rank-24'],
  ['E47derived24', 'E47-derived rank-24'],
  ['E47full125', 'Full E47 125D']
]);
const mean = values => values.reduce((sum, x) => sum + x, 0) / values.length;
export function summarize(raw) {
  if (!raw || !Number.isInteger(raw.seeds) || raw.seeds < 2 || raw.seeds > 10000 || !raw.auc_by_seed) {
    throw new Error('Invalid experiment metadata');
  }
  const arms = {};
  for (const [id, label] of ARMS) {
    const values = raw.auc_by_seed[id];
    if (!Array.isArray(values) || values.length !== raw.seeds ||
        !values.every(x => typeof x === 'number' && Number.isFinite(x) && x >= 0 && x <= 1)) {
      throw new Error(`Invalid AUC values for ${id}`);
    }
    const avg = mean(values);
    if (raw.means && (typeof raw.means[id] !== 'number' || Math.abs(raw.means[id] - avg) > 1e-9)) {
      throw new Error(`Archived mean disagrees with seed data for ${id}`);
    }
    arms[id] = {
      id, label, values: [...values], mean: avg,
      sd: Math.sqrt(values.reduce((sum, x) => sum + (x - avg) ** 2, 0) / (values.length - 1))
    };
  }
  const baseline = arms.baseline64.mean;
  for (const id of Object.keys(arms)) arms[id].deltaBaseline = arms[id].mean - baseline;
  return {seeds: raw.seeds, experiment: String(raw.experiment || ''), arms};
}
export function compare(summary, left, right) {
  if (!summary.arms[left] || !summary.arms[right]) throw new Error('Unknown comparison arm');
  const differences = summary.arms[left].values.map((x, i) => x - summary.arms[right].values[i]);
  return {
    left, right, differences,
    meanDifference: mean(differences),
    wins: differences.filter(x => x > 0).length,
    ties: differences.filter(x => x === 0).length,
    losses: differences.filter(x => x < 0).length
  };
}
