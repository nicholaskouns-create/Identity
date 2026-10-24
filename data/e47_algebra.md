# E47 projector: exact algebraic certificate

## Carrier and operator
Let `H = V₂ ⊗ V₂ ⊗ V₂`, `dim H = 125`; let `C` be the total spin Casimir,
and `K = (C - 6I)(C - 30I)`.

From Clebsch–Gordan algebra,
`V₂⊗³ ≅ V₀ ⊕ 3V₁ ⊕ 5V₂ ⊕ 4V₃ ⊕ 3V₄ ⊕ 2V₅ ⊕ V₆`.
The Casimir has nodes `0,2,6,12,20,30,42`. Define
`A(X) = X(X-2)(X-6)(X-12)(X-20)(X-30)(X-42)`;
thus `A(C)=0`.

## Exact selector polynomial
```
T(X) = X(X-2)(X-12)(X-20)(X-31)(X-42)
     = X^6 -107 X^5 +4088 X^4 -66940 X^3
         +430848 X^2 -624960 X.
D = 1814400.
P = T(C)/D.
```
At Casimir nodes, `T(6)=T(30)=D`, and `T(0)=T(2)=T(12)=T(20)=T(42)=0`.
The extra root `31` is a polynomial interpolation consequence, **not** an
eigenvalue of C.

In `ℚ[X]/(A)`, `T² = DT`, `KT = 0`. Therefore
`P²=P`, `KP=0` upon substitution at C.

## Bézout identity
```
Q(X) = -X^4 +71X^3 -1352X^2 +5488X +10080
T(X) + (X-6)(X-30) Q(X) = 1814400.
```
This polynomial identity holds over `ℤ[X]`, hence for every matrix substitution:
`T(C)+K Q(C)=DI`. If `Kv=0`, then `Pv=v`. Together with `KP=0`,
this yields `im P=ker K`.

Its dimension is `5·dim(V₂) + 2·dim(V₅) = 25+22=47`, yielding `rank P=47`.
The complement has dimension 78.

## Contraction
For `Γ=I-K²/99144` the complementary eigenvalues have absolute maximum `15/17`,
attained at Casimir 12 and 42, so for the self-adjoint Hilbert-space realization
`||Γⁿ-P||₂=(15/17)ⁿ`.

## Evidence boundary
- **PASS:** exact SymPy arithmetic for interpolation, Bézout, and polynomial divisibility.
- **DERIVED:** operator equalities via `A(C)=0` and representation decomposition.
- **PENDING:** successful Lean/Mathlib compilation of concrete 125×125 matrix
  identities and formal operator rank theorem (separate draft PR #7).

No claim of physical quantum hardware execution, universal error correction,
or empirical LLM quality improvement is implied.
