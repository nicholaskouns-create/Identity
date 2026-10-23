#!/bin/sh
# Refresh or recreate the pinned Lean and Rocq snapshots.
# Committed trees have no .git directory; an existing snapshot is left in place.
# formal/toolchain (Lean binary, about 3 GB extracted) is not committed.
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
cd "$ROOT"
mkdir -p upstream toolchain apps

clone_sparse() {
  dest=$1
  url=$2
  shift 2
  if [ -d "$dest/.git" ]; then
    git -C "$dest" sparse-checkout set --skip-checks "$@"
    git -C "$dest" checkout
  elif [ ! -e "$dest" ]; then
    git clone --depth 1 --filter=blob:none --sparse "$url" "$dest"
    git -C "$dest" sparse-checkout set --skip-checks "$@"
    git -C "$dest" checkout
  else
    echo "keeping snapshot $dest"
  fi
}

clone_sparse upstream/mathlib4 https://github.com/leanprover-community/mathlib4.git \
  LICENSE README.md \
  Mathlib/LinearAlgebra/Matrix \
  Mathlib/LinearAlgebra/Eigenspace \
  Mathlib/LinearAlgebra/Dimension \
  Mathlib/LinearAlgebra/FiniteDimensional \
  Mathlib/LinearAlgebra/Trace \
  Mathlib/LinearAlgebra/Projection.lean \
  Mathlib/LinearAlgebra/PiTensorProduct.lean \
  Mathlib/LinearAlgebra/PiTensorProduct \
  Mathlib/LinearAlgebra/TensorProduct \
  Mathlib/LinearAlgebra/Contraction.lean \
  Mathlib/LinearAlgebra/Charpoly \
  Mathlib/LinearAlgebra/UnitaryGroup.lean \
  Mathlib/LinearAlgebra/Semisimple.lean \
  Mathlib/RepresentationTheory \
  Mathlib/Data/Matrix \
  Mathlib/LinearAlgebra/RootSystem

clone_sparse upstream/math-comp https://github.com/math-comp/math-comp.git \
  LICENCE README.md AUTHORS \
  algebra/matrix.v algebra/mxalgebra.v algebra/mxpoly.v \
  algebra/spectral.v algebra/tensor.v algebra/sesquilinear.v algebra/vector.v \
  group_representation

clone_sparse upstream/mathcomp-analysis https://github.com/math-comp/analysis.git \
  LICENCE theories/normedtype_theory/matrix_normedtype.v

if [ ! -e upstream/aesop ]; then
  git clone --depth 1 https://github.com/leanprover-community/aesop.git upstream/aesop
fi

# No license file upstream. Local only; do not commit.
if [ ! -d upstream/clebsch-gordan/.git ]; then
  git clone --depth 1 https://github.com/rmathar/Clebsch-Gordan.git upstream/clebsch-gordan
fi

if [ ! -f apps/rocq-9.3.0.tar.gz ]; then
  curl -fL --retry 3 -o apps/rocq-9.3.0.tar.gz \
    https://github.com/rocq-prover/rocq/releases/download/V9.3.0/rocq-9.3.0.tar.gz
fi

if [ ! -f toolchain/lean-4.35.0-linux.tar.zst ]; then
  curl -fL --retry 3 -o toolchain/lean-4.35.0-linux.tar.zst \
    https://github.com/leanprover/lean4/releases/download/v4.35.0/lean-4.35.0-linux.tar.zst
fi

echo "FETCH_DONE"
