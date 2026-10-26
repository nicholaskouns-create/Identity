# Formal Validation Record — 26 October 2026

Both toolchains were installed from source releases and run against the files in
this directory. Nothing here is a summary of a previous run.

| | version | files | result |
|---|---|---|---|
| Coq | 8.18.0 (OCaml 4.14.1) | 11 | **11 compiled** under `coqc -q` |
| Lean | 4.35.0 (`eb6cafb7290e8bd5f2937522d8d804f58f02bafc`) | 11 | **10 compiled**, 1 deferred |

72 theorems and lemmas in Coq, 75 in Lean, plus the 17 added with
`E47Commutant` below.

## Completeness audit

- **Coq**: no `Axiom`, `Parameter`, `Hypothesis` or `Admitted` in any file. The
  only textual match for "Admitted" is a comment in `E47WeightAlgebra.v`
  asserting there are none, which is true.
- **Lean**: no file emitted a `declaration uses 'sorry'` warning. That warning is
  what a stubbed proof produces, so its absence across every file is the check.

## Axiom ledger

Every theorem carrying its own `#print axioms`:

| dependency | count | where |
|---|---|---|
| none at all | 41 | all of `E47Commutant`, all of `Tensor125`, most of `WeightAlgebra` |
| `[propext]` | 5 | the three `E47Spin2` commutators, `spin2_casimir_scalar`, `lam_zero_iff` |
| `[propext, Classical.choice, Quot.sound]` | 1 | `WeightAlgebra.pr_expanded` (closed by core `grind`) |

All three are Lean's own foundational axioms. **No custom axiom is declared
anywhere in this directory.**

`WeightAlgebra.gamma_contracts_off_kernel` depending on nothing is worth naming:
the contraction property is proved outright rather than postulated.

## Deferred here, but green in CI

`E47ConcreteMatrix.lean` — 1571 lines, `import Mathlib`. It was **not** built
during this run: no Mathlib compilation cache was reachable from the build
container, so the bare 4.35.0 toolchain was fetched directly and everything not
requiring Mathlib was compiled.

That is a fact about this container, not about the file. The workflow
`e47-concrete-matrix.yml` builds it routinely — `lake exe cache get` then
`lake env lean` — and run #10 on `main` (24 Oct 2026) succeeded.

What that run does **not** check is axioms. The file closes its five headline
theorems with `native_decide` across 15 sites, and `native_decide` mints a
fresh axiom per theorem asserting the compiled evaluation's result:

```
'by_native' depends on axioms: [propext, by_native._native.native_decide.ax_1_1]
'by_kernel' does not depend on any axioms
```

So `casimir_annihilator`, `scaled_projector_is_idempotent`,
`selected_subspace_is_kernel`, `scaled_projector_trace` and `kernel_bezout`
compile green while trusting the Lean compiler rather than the kernel. They
cannot join the axiom-free ledger as written. `e47-axiom-ledger.yml` now
reports that gap explicitly instead of letting it pass in silence.

**It is closable.** The file already compresses rows by conserved total Jz
weight, which makes the Casimir block-diagonal across sectors of size
1,3,6,10,15,18,19,18,15,10,6,3,1 — 27,761 multiply-adds per product instead of
1,953,125 dense, seventy times cheaper. Measured on that shape, kernel `decide`
settles a full 125-dimensional block-matrix equality in **8.5 seconds with no
axioms**. The ring algebra still needs Mathlib, which CI already has.

## Added in this record: `E47Commutant`

`E47Commutant.lean` and `E47Commutant.v` extend `kernel_dim_from_blocks` to the
commutant dimension, in the same weight-counting idiom and with the same
boundary discipline. 17 theorems, all proved by `decide` / `reflexivity`, all
depending on **no axioms**.

```
mult            = (1, 3, 5, 4, 3, 2, 1)        for j = 0..6
retained        = [2, 5]                        spins with j(j+1) in {6, 30}
kernelDim       = 5·5 + 2·11 = 25 + 22 = 47
commutantDim    = 5² + 2²    = 25 + 4  = 29
carrierCommutantDim = Σ mult j² = 65
stateGeometryDim    = 29 − 1    = 28 = 24 + 3 + 1
```

and the two discrepancies against plate RUB5-C17, stated as inequalities the
kernel checks:

```
commutant_exceeds_single_block      : commutantDim     ≠ 25
state_geometry_exceeds_single_block : stateGeometryDim ≠ 24
dropped_block_is_a_qubit            : mult 5 = 2
```

The representation theory behind those numbers — that the commutant of a
multiplicity decomposition is `⊕_j M_{m_j}(ℂ)` — is textbook input stated in the
file header, not an axiom, exactly as the sl2 facts are in `E47WeightAlgebra`.
The same commutant dimension was computed independently and numerically, as the
nullity of the adjoint-action Casimir superoperator on `End(E₄₇)`, in
`E47-Kartekeya/certificates/rub5_c17_descent_derivation.py` — result 29.

## Reproduce

```bash
# Coq
cd formal/e47 && for f in $(find . -name '*.v'); do coqc -q "$f"; done

# Lean, excluding the Mathlib-dependent file
cd formal/e47 && for f in $(find . -name '*.lean' ! -name 'E47ConcreteMatrix.lean'); do
    lean "$f"
done
```

## Boundary

Verified here: compilation, completeness and axiom provenance of the finite
algebraic layer. Not verified: that any 125×125 matrix satisfies these
statements (`E47ConcreteMatrix` is the deferred bridge), and not verified at all
is any physical interpretation of the layer.
