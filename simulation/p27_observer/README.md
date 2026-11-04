# P26 -> P27 observer extension (2026-11-03)
The normalized residual v=(I-P26)phi/||(I-P26)phi|| gives Pi=vv†, P27=P26+Pi and Q27=I-P27.
For a rank-26 orthogonal P26, nonzero residual yields rank(P27)=27, rank(Q27)=37.
The Halmos block [[P(theta),Q(theta)],[Q(theta),-P(theta)]] is unitary with
P(theta)=P26+sin(theta)Pi and Q(theta)=Q27+cos(theta)Pi.
The Hamiltonian H26+alpha phi phi† is Hermitian and supported on P27 if H26=P26 H26 P26.
The phase gate I+(exp(i theta)-1)phi phi† is unitary.
T^40=P27+2^-40(I-P27), so ||T^40-P27||_2=2^-40.

## Evidence levels
- Exact mathematical derivation: above, subject to the stated orthogonality and support hypotheses.
- Python: run `python simulation/p27_observer/validate.py`.
- Lean/Coq: formal sources supplied; **compiler acceptance not yet established**.
- A5 representation: **not constructed** by a random QR rank-26 projector.
- 2x2 effective Hamiltonian only when the parallel observer component is an H26 eigenvector.

This is an additive module; it does not replace existing E47 models.
