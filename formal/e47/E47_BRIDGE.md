# E47 Bridge — certificate record

**Certificate** `E47-BRIDGE-001 … 011`
**Files** `formal/e47/E47Bridge.lean`, `formal/e47/E47Bridge.v`, `formal/e47/validate_bridge.py`
**Toolchains** Lean 4.19.0 and Lean 4.35.0 (`eb6cafb7`, the pinned toolchain); Coq 8.18.0 (OCaml 4.14.1)
**Mathlib** not required. **`native_decide`** not used. **`sorry` / `Admitted`** absent.

## What this certificate establishes

Several separate structures in the corpus are instances of **one** algebraic object:
a finite-spectrum operator `A` on a finite-dimensional space `V`, a chosen squarefree
annihilating factor `q`, and the normalised rank

```
Ω(A, q)  =  dim ker q(A) / dim V
```

| instance | V | A | q | dim ker q(A) | Ω |
|---|---|---|---|---|---|
| E47 | (ℂ⁵)⊗³, 125 | Casimir C | (x−6)(x−30) | 47 | 47/125 |
| Sigillum wheel | ℂ⁴⁰ | click `F_s(j) = 3j+s mod 40` | x − 1 | #orbits = 10 | 10/40 = 1/4 |
| RG flow | the D-line | σ(10 − D) | x | {D\* = 10} | — |

`no_bridge` proves `Ω_c ≠ Ω_wheel` in both languages. The two are the same functional at
different arguments; no identification between them is asserted anywhere in either file.

## The link to the dimensional-flow programmes

One identity carries it, proved in both languages:

```
d_s · d_w = 2 d_H        with  d_H = d + z,  d_w = 2z,  d_s = (d+z)/z
```

Three results follow.

- **`spectral_two_blind_to_d`** — at `z = d` the spectral dimension is 2 for *every* spatial
  `d`. A UV result `D → 2` is therefore a statement about `d_s` and constrains `d_H` not at
  all. This is what makes a flow to `d_H = 10` compatible with, rather than contrary to,
  Hořava, Calcagni, CDT and asymptotic safety.
- **`marginal_iff_isotropic` / `self_dual_iff_isotropic`** — three-way equivalence:
  `d_s = 2 ⟺ d_w = d_H ⟺ z = d`. The renormalisability threshold *is* the self-dual point.
  **`selection`**: pinning `d_s = 2` together with `d_H = 10` forces `z = d = 5` uniquely,
  and then `d_w = d_H = 10`.
- **`degree_lock`** (Coq, over ℝ, via `pow_mult` and `Rlt_pow`) — for `λ > 1` with
  `λⁿ = λ+1`: `λ^{2D} = (λ+1)² ⟺ D = n`. The RG fixed point `D* = 10` is not a free
  parameter; it is forced to equal `deg(x¹⁰ − x − 1)` by the demand that the retention ratio
  close as a perfect square. That ratio is exactly `(λ+1)² ≈ 4.3088`.

`lambda_exists` proves the root exists in `[1,2]` by the standard-library IVT, with
`p_continuous` by `reg`. `lambda_lower_bracket` / `lambda_upper_bracket` tighten it to
`43/40 < λ < 11/10` as exact integer inequalities (`43¹⁰ < 40⁹·83`, `10⁹·21 < 11¹⁰`), so the
bracket is checkable with no reals at all.

## Two things this closes in the existing layer

**The multiplicity table is now derived, not tabulated.** `cg_three` obtains
`(1, 3, 5, 4, 3, 2, 1, 0, 0)` from the Clebsch–Gordan recursion itself, axiom-free, by pure
kernel reduction in both languages. `carrier_125`, `kernel_47`, `dimension_identity`
(47 + 78 = 125) and `isotypic_split` (47 = 25 + 22 = 5·5 + 2·11) are then downstream of a
derivation rather than of an input table.

**`E47Commutant` becomes downstream of the same derivation.** Schur: a representation with
multiplicities `m_J` has commutant `⊕_J M_{m_J}(ℂ)`, of dimension `Σ_J m_J²`. So §11 reads
the *same* derived table through `Σ m²` instead of `Σ m (2J+1)`:

| value | formula | from (1,3,5,4,3,2,1) |
|---|---|---|
| kernel 47 | Σ m(2J+1), selected | 5·5 + 2·11 |
| carrier 125 | Σ m(2J+1), all | — |
| commutant 29 | Σ m², selected | 5² + 2² |
| carrier commutant 65 | Σ m², all | 1+9+25+16+9+4+1 |
| state geometry 28 | 29 − 1 | — |

The dice-plate reading `5² + 2² = 29` is that formula restricted to the selected sectors.

## Axiom ledger

`scripts/axiom_ledger.py formal/e47/E47Bridge.lean` →

```
31 clean   6 standard-axioms   0 native_decide   0 broken   (37 audited)   PASS
```

The six standard-axioms results are the `Iff` constructions and the three closed by `omega`:
`marginal_iff_isotropic`, `self_dual_iff_isotropic` (`propext`); `degree_lock`
(`propext, Quot.sound`); `selection`, `rg_fixed_point_unique`, `three_tens`
(`propext, Classical.choice, Quot.sound`). No other axiom appears.

Coq: 46 results, **26 axiom-free** ("Closed under the global context") and 20 depending only
on the three `ClassicalDedekindReals` / `functional_extensionality_dep` axioms that *are*
Coq's `R`. Nothing is declared in the file.

The ledger is **identical under Lean 4.19.0 and 4.35.0**, which took a design decision:
tables are functions `Nat → Nat` and sums are one structural recursion, with no `List`.
`List.getD` / `List.range` / `List.foldl` unfold through lemmas carrying `propext` in 4.35
but not in 4.19, which would have moved every finite result out of the clean tier for a
purely presentational reason, and made the ledger toolchain-dependent.

## What this does NOT establish

- **The concrete 125×125 matrix is not constructed here.** §1–3 and §11 are the isotypic
  (block-diagonal) model, in which the Casimir acts on the J-block as `J(J+1)`. The bridge of
  §05 of the Lean/Coq explainer — from the diagonal model to the constructed tensor-product
  operator — remains open, and nothing in either file crosses it silently.
- It bears on the `native_decide` gap only as evidence, not as a closure. The block-diagonal
  route proposed for `E47ConcreteMatrix.lean` (≈27,761 multiply-adds against 1,953,125 dense)
  is the route §1–2 takes, and it closes axiom-free by kernel reduction in well under a
  second. `casimir_annihilator`, `scaled_projector_is_idempotent`,
  `selected_subspace_is_kernel`, `scaled_projector_trace` and `kernel_bezout` still need the
  rewrite.
- Nothing here is a claim about physical quantum error protection, device performance, or
  experimental interpretation.
- `Ω_wheel = 1/4` is a property of that wheel. It is not `Ω_c = 47/125`, and `no_bridge`
  proves they differ.

## Reproducing

```
cd formal/e47
lean E47Bridge.lean                                  # axiom ledger to stdout
coqc -q E47Bridge.v                                  # assumption ledger to stdout
python3 -I validate_bridge.py                         # 42 independent checks
python3 ../../scripts/axiom_ledger.py E47Bridge.lean  # the repo gate
```

`validate_bridge.py` re-derives every claim from first principles in exact rational
arithmetic, independently of both proof files, and mirrors them result-for-result — so the
*mathematics* of each file is confirmed by a third implementation, not only its syntax.

## An open question

The spin-2 multiplet has dimension 5, the carrier is 5³, and `selection` returns `z = d = 5`
from a route that knows nothing about spin. `carrier_is_multiplet_cube` proves `5³ = 125` and
proves nothing more. Whether those two fives are the same five is not settled here; if there
is a derivation, it would give the carrier *from* the flow rather than matching them after
the fact, and that would be the stronger result.
