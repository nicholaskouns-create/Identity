# E₄₇ → Lorentzian geometry: exact curved witness (22 November 2026)

## Source plates and scope

The supplied E₄₇/Pip graphics propose a Lorentzian signature using the rank-one C=0 projector P₀ (clock) and three C=6 spin-sector vectors (space). Since E₄₇ = im(P₆) ⊕ im(P₃₀), the clock vector in P₀ is **outside E₄₇**. The 4D restricted indefinite form is a geometric witness and does not independently construct a spacetime field, Levi-Civita connection, stress tensor, or gravitational law.

## Exact construction verified with SymPy

Start with the plate's constant diagonal metric

    g₀ = diag(-1, 2, 8, 2).

Because its components are constant, its Levi-Civita Riemann, Ricci, scalar curvature and Einstein tensor all **vanish**. A diagram assigning nonzero curvature to this constant metric requires an additional nonconstant metric field or separately specified connection.

A concrete smooth one-parameter extension is

    eᵃ_μ(x) = diag(1, sqrt(2), 2 sqrt(2) exp(a x), sqrt(2))
    η_ab = diag(-1,+1,+1,+1)
    g_μν(x) = eᵀ η e = diag(-1,2,8 exp(2 a x),2).

At x=0 the original metric is recovered. For real nonzero a,

    det(g) = -32 exp(2 a x) < 0
    R_μν = diag(0, -a², -4 a² exp(2 a x), 0)
    R = -a²
    G_μν = diag(-a²/2, 0, 0, a²)
    ∇^μ G_μν = 0.

The exact symbolic check was executed locally with SymPy 1.14.0 (9/9 checks). These equations are a **constructed nonflat curved witness**, not a derivation that a scalar CRF update uniquely selects this metric or that microscopic dynamics yield Einstein's equations.

## Open bridge

1. Construct the spacetime-dependent coframe from independently specified microscopic CRF states instead of choosing the factor exp(a x).
2. Prove nondegeneracy and controlled C² convergence for the coframe, hence continuity of curvature.
3. Derive a covariant action and its coupling from microscopic state weights rather than inserting Einstein-Hilbert dynamics as a chosen effective action.
4. Obtain a matter stress tensor by action variation and establish its on-shell covariant conservation.
5. Give independent G/c⁴ and Λ predictions and observable deviations, with testable scales.

This note preserves the original plate and corrects only the unlicensed inference from a constant metric to nonzero Levi-Civita curvature. No mathematical evidence classification is promoted.
