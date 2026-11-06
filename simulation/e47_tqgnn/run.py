"""Reconstruct the spectral engine, check it, and run the temporal graph net."""
import argparse
import json
import os
import shutil
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from model import check_gru_gradient, make_graph, train_and_score
from spectral import exact_certificate, numerical_carrier
import numpy as np

ROOT = Path(__file__).resolve().parents[2]


def assist(command, source):
    if not command:
        return {'status': 'skipped'}
    completed = subprocess.run(
        command + [str(source)], cwd=ROOT, capture_output=True, text=True,
    )
    if completed.returncode != 0:
        raise AssertionError((completed.stderr or completed.stdout)[-2000:])
    return {'status': 'pass', 'compiler': Path(command[0]).name}


def lean_command():
    chosen = os.environ.get('LEAN')
    if chosen:
        return [chosen]
    bundled = ROOT / 'formal/toolchain/lean/lean-4.35.0-linux/bin/lean'
    if bundled.exists():
        return [str(bundled)]
    found = shutil.which('lean')
    return [found] if found else None


def coq_command():
    """Use coqc when it is on PATH. A micromamba env is optional and local only."""
    chosen = os.environ.get('COQC')
    if chosen:
        return [chosen]
    found = shutil.which('coqc')
    if found:
        return [found]
    micromamba = shutil.which('micromamba') or os.environ.get('MICROMAMBA')
    prefix = os.environ.get('COQ_PREFIX')
    if micromamba and prefix and Path(prefix, 'bin/coqc').exists():
        return [micromamba, 'run', '-p', prefix, 'coqc']
    return None


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--seeds', type=int, nargs='+', default=[47],
                        help='paired graph/initialization seeds; default preserves the original run')
    parser.add_argument('--output', type=Path,
                        default=Path(__file__).with_name('results.json'))
    args = parser.parse_args()
    if len(set(args.seeds)) != len(args.seeds) or any(s < 0 for s in args.seeds):
        parser.error('seeds must be distinct nonnegative integers')
    exact = exact_certificate()
    numerical = numerical_carrier()
    if numerical['eigenspace_counts'] != [1, 9, 25, 28, 27, 22, 13]:
        raise AssertionError('fidelity')
    if sum(exact['eigenspace_dimensions']) != 125 or exact['kernel_rank'] != 47:
        raise AssertionError('fidelity')
    if exact['multiplicities'] != [1, 3, 5, 4, 3, 2, 1]:
        raise AssertionError('fidelity')
    check_gru_gradient()
    runs = []
    for seed in args.seeds:
        edges = make_graph(16, 8, np.random.default_rng(seed))
        baseline = train_and_score(edges, use_clock=False, seed=seed)
        clocked = train_and_score(edges, use_clock=True, seed=seed)
        runs.append({'nodes': 16, 'steps': 8, 'epochs': 8, 'seed': seed,
                     'baseline': baseline, 'e47_clock': clocked,
                     'delta': clocked - baseline})
    deltas = np.array([r['delta'] for r in runs])
    lean = lean_command()
    coq = coq_command()
    proofs = {
        'lean': assist(lean, ROOT / 'formal/e47/E47Spectral.lean'),
        'coq': assist(coq, ROOT / 'formal/e47/E47Spectral.v'),
    }
    report = {
        'statement': (
            'Scalar certificate: three spin-2 angular momenta give multiplicities '
            '[1,3,5,4,3,2,1], carrier dimension 125, and rank of ker (C-6I)(C-30I) '
            'equal to 47. The 125-by-125 matrices are checked numerically in Python, '
            'not inside Lean or Coq. Paired synthetic link-prediction runs are recorded; '
            'it is not a claim that the clock improves AUC.'
        ),
        'exact': exact,
        'numerical': {
            'eigenspace_counts': numerical['eigenspace_counts'],
            'residuals': numerical['residuals'],
            'contraction': numerical['norms'],
            'code_shape': numerical['code_shape'],
        },
        'gru_gradient': True,
        'auc': runs[0],  # Original consumer contract; all paired runs are below.
        'paired_runs': runs,
        'auc_summary': {
            'metric': 'Mann–Whitney ROC AUC with average ranks for ties',
            'pairs': len(runs),
            'mean_baseline': float(np.mean([r['baseline'] for r in runs])),
            'mean_e47_clock': float(np.mean([r['e47_clock'] for r in runs])),
            'mean_delta': float(deltas.mean()),
            'sample_std_delta': float(deltas.std(ddof=1)) if len(runs) > 1 else None,
            'clock_wins': int(np.sum(deltas > 0)),
            'scope': 'Independent random temporal graphs; implementation/null benchmark, not evidence of prediction gains.',
        },
        'proofs': proofs,
    }
    destination = args.output
    destination.parent.mkdir(parents=True, exist_ok=True)
    destination.write_text(json.dumps(report, indent=2) + '\n')
    print(json.dumps({'auc': report['auc'], 'auc_summary': report['auc_summary'],
                      'proofs': proofs, 'rank': exact['kernel_rank']}, indent=2))
    print('E47_TQGNN_PASS')


if __name__ == '__main__':
    main()
