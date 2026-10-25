#!/usr/bin/env bash
# Fail closed: neither missing compiler nor failed proof may count as a pass.
set -euo pipefail
cd "$(dirname "$0")/.."
command -v lean >/dev/null || { echo "ERROR: Lean compiler not installed" >&2; exit 127; }
command -v coqc >/dev/null || { echo "ERROR: Coq/Rocq compiler not installed" >&2; exit 127; }
command -v python3 >/dev/null || { echo "ERROR: Python not installed" >&2; exit 127; }
python3 -c 'import numpy' || { echo "ERROR: install NumPy (python3 -m pip install numpy)" >&2; exit 127; }
echo "Lean: $(lean --version)"
echo "Coq: $(coqc --version | head -n 1)"
echo "Python: $(python3 --version)"
workdir="$(mktemp -d)"
trap 'rm -rf "$workdir"' EXIT
# Work outside the repository to avoid leaving .vo and .olean build products in tracked folders.
cp formal/e47/E47Spectral.lean formal/e47/E47Spectral.v formal/e47/TowerIdentity.v "$workdir/"
cp formal/e47/E47WeightAlgebra.lean formal/e47/E47WeightAlgebra.v "$workdir/"
cp formal/e47/E47TowerKernel.lean formal/e47/E47TowerKernel.v "$workdir/"
(
  cd "$workdir"
  lean E47Spectral.lean
  coqc -q E47Spectral.v
  coqc -q TowerIdentity.v
  lean E47WeightAlgebra.lean
  coqc -q E47WeightAlgebra.v
  lean E47TowerKernel.lean
  coqc -q E47TowerKernel.v
)
python3 simulation/validate_e47.py
echo "PASS: Lean spectral, Coq spectral, Coq tower, Lean weight algebra, Coq weight algebra, Lean tower-kernel link, Coq tower-kernel link, Python 125x125 validation"
