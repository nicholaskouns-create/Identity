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
cp formal/e47/E47OddsContraction.lean formal/e47/E47OddsContraction.v "$workdir/"
(
  cd "$workdir"
  lean E47Spectral.lean
  coqc -q E47Spectral.v
  coqc -q TowerIdentity.v
  lean E47WeightAlgebra.lean
  coqc -q E47WeightAlgebra.v
  lean E47TowerKernel.lean
  coqc -q E47TowerKernel.v
  lean E47OddsContraction.lean
  coqc -q E47OddsContraction.v
)
python3 simulation/validate_e47.py
# Matrix projector: Coq (about 1 minute) and the exact-integer Python cross-check.
# The Lean companion needs about 4-5 minutes and 7 GB, so it has its own workflow
# (.github/workflows/e47-matrix-projector.yml); to run it here: lean formal/e47/E47MatrixProjector.lean
# Odds link (about 1 more minute): the odds contraction for every integer vector of the 125x125 model;
# it imports E47MatrixProjector and E47OddsContraction, so all three are compiled in one directory.
mpdir="$(mktemp -d)"
cp formal/e47/E47MatrixProjector.v formal/e47/E47OddsContraction.v formal/e47/E47OddsLink.v "$mpdir/"
( cd "$mpdir" && coqc -q E47MatrixProjector.v && coqc -q E47OddsContraction.v && coqc -q E47OddsLink.v )
rm -rf "$mpdir"
python3 simulation/e47_tqgnn/matrix_projector_check.py
python3 simulation/e47_tqgnn/odds_link_check.py
echo "PASS: Lean spectral, Coq spectral, Coq tower, Lean weight algebra, Coq weight algebra, Lean tower-kernel link, Coq tower-kernel link, Lean odds contraction, Coq odds contraction, Python 125x125 validation, Coq matrix projector, Coq odds link, Python matrix projector check, Python odds link check"
