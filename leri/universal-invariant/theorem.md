# Universal Recursive Identity Theorem
Nicholas Shane Kouns · AIMS Research Institute · 2026-11-27

Let A be a nonzero positive semidefinite self-adjoint operator on a finite-dimensional Hilbert space H. Set E=ker A, P=proj E, Q=I−P, Δ=min positive spectrum, L=max spectrum, ε=2/(Δ+L), Γ=I−εA, r=(L−Δ)/(L+Δ).
For n≥1, Γⁿ=P+ΓⁿQ and ||Γⁿ−P||₂=rⁿ by the spectral theorem (the extrema attain r). Thus PΓ=P, Fix Γ=E and Γⁿx→Px.
For every continuous F:H→Y with Y Hausdorff, FΓ=F iff F=fP for a unique continuous f:E→Y. Indeed F(x)=F(Γⁿx)→F(Px), and f=F|E; the converse follows from PΓ=P. Hence Px=Py iff trajectories asymptotically coincide iff all continuous invariant scalar observables agree (linear functionals separate E). H/ker P is isometrically E with quotient norm ||Px||. Identity distance ||P(x−y)|| is constant and complementary distance contracts by rⁿ. Unitary conjugation transports every statement.

## E47 and LERI
H=V₂⊗³, C=J_total², K=(C−6I)(C−30I), A=K². Spin multiplicities 1,3,5,4,3,2,1 give rank P47=47; Δ=11664, L=186624, ε=1/99144, r=15/17.
Π=(1/6)Σσ Uσ is the orthogonal symmetric projector commuting with C. Sym³(V₂)=V₀⊕V₂⊕V₃⊕V₄⊕V₆ (obtain by counting unordered weight triples and subtracting adjacent weight multiplicities). P5=P47Π has rank 5. B=A+11664(I−Π) has kernel im P5 and extrema Δ,L: the symmetric spin-6 sector attains L, nonsymmetric selected sectors attain Δ, and other nonsymmetric eigenvalues are ≤ L. Thus the same contraction rate holds for B. Continuous joint invariants of Γ and Π factor uniquely through P5. Invariance under each permutation alone is weaker than invariance under averaging Π.
## Quantum realization
For T=Γ or I−εB, D=√(I−T²), the block matrix [[T,D],[D,−T]] is unitary, and the successful ancilla-zero branch realizes T. Repeated successful outcomes converge to normalized Pψ if Pψ≠0, with total success probability tending to ||Pψ||². This is postselection, not unconditional population transfer.
## Evidence
Analytic proof above. Numerical reproduction and formal proof status are separate. No hardware performance or novelty claim is made.
