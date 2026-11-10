# E47 third-turn: exact generating function, asymptotic closure, and formal-assistant boundary

**2026-11-10.** Additive research branch. The proofs in this branch do not alter the existing 125×125 Casimir theorems, website, or deployed databases.

## Exact definitions

For the integer-spin SU(2) tensor powers V₂^{⊗n}, let mₙ(J) be the total-spin J multiplicity. Let d_r(n)=Σ_{J≡r(mod3)}(2J+1)mₙ(J), and Dₙ=d₂(n)−d₀(n). For n=0, D₀=−1.

Set W(z)=z⁻²+z⁻¹+1+z+z², aₙ(k)=[zᵏ]W(z)ⁿ and Aₖ(t)=[zᵏ](1−tW(z))⁻¹.

## Theorem 1: formal generating function (all n)

In Q[[t]]:

**D(t)=(5t−1)((1+t)A₀(t)−2tA₁(t))/(1+t)².**

Equivalently, with zero padding for negative indices,

Dₙ+2Dₙ₋₁+Dₙ₋₂ = −aₙ(0)+4aₙ₋₁(0)+5aₙ₋₂(0)+2aₙ₋₁(1)−10aₙ₋₂(1).

**Proof:** SU(2) weight counting gives mₙ(J)=aₙ(J)−aₙ(J+1). Summation by parts with w_J=−1,0,+1 for J mod 3=0,1,2 gives Dₙ=−aₙ(0)+Σ_{k≥1} bₖaₙ(k), where bₖ=−4k,2k−1,2k+1 according to k mod 3=0,1,2. Write F(t,u)=Σ_{n,k≥0}aₙ(k)tⁿuᵏ. Because each coefficient of tⁿ is a finite polynomial in u, evaluating and differentiating at a primitive cube root of unity requires no regularization. The half-line walk recurrence yields

F(t,u)=[1+t(A₁+A₂+A₁u−A₀/u−A₀/u²−A₁/u)]/[1−tW(u)],

where A₂=((1−t)A₀−1)/(2t)−A₁. Inserting u=ζ,ζ² and W(ζ)=−1 into the finite root-of-unity expression for bₖ simplifies to the boxed identity. The symbolic simplification is performed independently by verify.py.

## Theorem 2: exact middle sector

For every n≥1, d₁(n)=[5ⁿ+(−1)ⁿ(6n−1)]/3. Its generating function is

Σ_{n≥1}d₁(n)tⁿ = (1/3)(5t/(1−5t)−6t/(1+t)²−t/(1+t)).

## Theorem 3: asymptotic result

For θ near 0,

W(e^{iθ})=1+2cosθ+2cos2θ=5−5θ²+(17/12)θ⁴+O(θ⁶).

For k=0,1, Aₖ(t)=(1/2π)∫_{−π}^π e^{−ikθ}/[1−tW(e^{iθ})] dθ. Put δ=1−5t. A₀ and A₁ each have common dominant singular term (2√δ)⁻¹. The rational Laurent resolvent makes these generating functions algebraic, with Puiseux expansions near 1/5. The triangle inequality gives |W(e^{iθ})|<5 for θ≠0, so 1/5 is the unique singularity on its convergence circle, allowing classical singularity transfer.

D(t)=−(5/18)√(1−5t)+ analytic terms + O((1−5t)³ᐟ²).

Consequently:

**Dₙ = [5/(36√π)]·5ⁿ/n³ᐟ² + O(5ⁿ/n⁵ᐟ²).**

**d₂(n)=5ⁿ/3+[5/(72√π)]5ⁿ/n³ᐟ²+O(5ⁿ/n⁵ᐟ²)**, while d₀ has the negative leading correction. The parity term in d₁ is exponentially small relative to this scale.

## Reproduction and machine proof boundaries

- Run `python3 formal/e47/third-turn/verify.py` with SymPy. It compares 120 exact integer CG decompositions, 120 exact middle-sector identities, 121 GF coefficients, and SymPy's exact rational identity. The coefficient C = 5/(72√π).
- `E47ThirdTurnGF.lean` and `E47ThirdTurnGF.v` formalize **uniqueness of the coefficient solution assuming the GF coefficient recurrence**, and chi's 3-periodicity. They do **not** prove the CG-to-recurrence derivation or analytic singularity transfer.
- The paper proof of Theorem 3 invokes standard complex-analytic singularity transfer. Full kernel-checked analytic transfer in **both Lean and Coq** remains an open obligation until compiled evidence exists. The automated workflow compiles the narrower algebraic lemmas.

## Preserved failures and scope corrections

Earlier O(1) claims for unnormalized sector discrepancies are false. The absolute middle discrepancy is (6n−1)/3 and the ± deviations grow on the order of 5ⁿ/n³ᐟ². The third-turn character value −1 is a trace on each selected irreducible representation, not the scalar action U(ω)=−I on E₄₇. Selection is conserved by SU(2)-equivariant operators, not arbitrary operators.
