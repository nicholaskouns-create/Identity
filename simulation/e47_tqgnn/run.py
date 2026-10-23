"""Reconstruct the spectral engine, check it, and run the temporal graph net."""
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
    exact = exact_certificate()
    numerical = numerical_carrier()
    if numerical['eigenspace_counts'] != [1, 9, 25, 28, 27, 22, 13]:
        raise AssertionError('fidelity')
    if sum(exact['eigenspace_dimensions']) != 125 or exact['kernel_rank'] != 47:
        raise AssertionError('fidelity')
    if exact['multiplicities'] != [1, 3, 5, 4, 3, 2, 1]:
        raise AssertionError('fidelity')
    check_gru_gradient()
    edges = make_graph(16, 8, np.random.default_rng(47))
    baseline = train_and_score(edges, use_clock=False, seed=47)
    clocked = train_and_score(edges, use_clock=True, seed=47)
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
            'not inside Lean or Coq. One synthetic link-prediction run is recorded; '
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
        'auc': {
            'nodes': 16,
            'steps': 8,
            'epochs': 8,
            'seed': 47,
            'baseline': baseline,
            'e47_clock': clocked,
            'delta': clocked - baseline,
        },
        'proofs': proofs,
    }
    destination = Path(__file__).with_name('results.json')
    destination.write_text(json.dumps(report, indent=2) + '\n')
    print(json.dumps({'auc': report['auc'], 'proofs': proofs, 'rank': exact['kernel_rank']}, indent=2))
    print('E47_TQGNN_PASS')


if __name__ == '__main__':
    main()
