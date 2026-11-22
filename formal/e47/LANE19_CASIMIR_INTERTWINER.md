# Lane 19 — Concrete Casimir ↔ isotypic sector equivalence

Status: **OPEN proof obligation**, not a completed theorem. Additive research artifact; no modification to established E47Bridge, routes, or canonical evidence classes.

## Proven separately in the current repository

- `formal/e47/E47Bridge.lean`: the Clebsch–Gordan multiplicity recursion derives `m(J) = [1,3,5,4,3,2,1]` for J = 0…6. Its isotypic sector model yields 125 and selected dimension 47.
- `formal/e47/E47BlockCasimir.lean`: total-weight grading yields fiber sizes 1,3,6,10,15,18,19,18,15,10,6,3,1; it does **not** yet identify the concrete Casimir eigenspaces with the spin blocks.
- `monorail/OPERATIONS.md`: Z-commutation established by E47Centrality as reported in the operations guide; U/D commutation and lane-19 identification remain open. Locate and independently compile the relevant original module before changing this status.

## Exact target

Let H := (ℂ⁵)⊗³ and C := Jx²+Jy²+Jz² with total spin generators. Let
W := ⊕_{J=0}^6 (ℂ^{m_J}⊗ℂ^{2J+1}) with m = (1,3,5,4,3,2,1).
Construct an invertible linear intertwiner S : H ≃ₗ W satisfying

    S C = D S,
    D|_{ℂ^{m_J}⊗ℂ^{2J+1}} = J(J+1)·Id.

Equivalently, S C S⁻¹ = D. Prove invertibility and the equation against the
*concrete* 125-component spin-2 product operator.

Then K := (C − 6I)(C − 30I) is conjugate to
(D − 6I)(D − 30I), hence

    dim ker K = Σ_{J: J(J+1)∈{6,30}} m_J(2J+1)
              = 5·5 + 2·11 = 47.

## Minimal proof obligations, independent and separately reportable

1. Define the concrete 5×5 spin-2 Jx,Jy,Jz matrices over a representation supporting complex coefficients.
2. Lift each generator to H with tensor identities; define C as their quadratic sum, with precise normalization.
3. Construct the Clebsch–Gordan change-of-basis / coupling isometry S, rather than postulating its properties.
4. Establish S* S = I_H and S S* = I_W (dimension 125 on both sides).
5. Prove the intertwining identity S C = D S using the actual concrete matrices.
6. Transfer the polynomial selector through conjugation and prove the kernel equivalence.
7. Count the selected sector dimensions to obtain 47.
8. Attach independent numerical residuals only as E1 evidence; promote to E0 only for the actual compiled formal theorem.

The weaker route via total-weight blocks is useful but must prove that C preserves each block and that each block's characteristic polynomial / nullity is computed correctly. The absent `E47BlockSubalgebra.lean` mentioned by a nearby comment is not presently verified to exist at that named path.

## Concrete cross-checks

An independent Python script can compare `spec(C)`, projector idempotence,
`K P`, `trace(P)` and block nullity by total weight. These are useful
regression checks, **not substitutes for the formal intertwiner proof**.

## Monorail routing

Keep the target in a separate route/station with `PENDING` / `LIMITED SERVICE`
until compiler output and citizen reconciliation support a change.
Do not fabricate a receipt, key, CI run, theorem, or database insertion.
See [full operational guide](../../monorail/OPERATIONS.md) and
[public full publication](../../site/proof/monorail/operations/index.html).
