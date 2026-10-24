# Socorro Glyph: Reflection, Contraction and Gaussian-Rotation Leakage

Research instrument. The glyph is an **idealized geometric reconstruction**, not evidence that the 1964 marking encoded an operator.

## Mathematical model

R = diag(-1,1); P+ = (I+R)/2; Gamma = diag(1/2,1).
Exact noiseless identity: Gamma^n - P+ = diag(2^(-n),0).

Let theta_n be independent N(0,sigma^2) and X_(n+1)=Gamma U(theta_n) X_n, with sigma=0.15 and X_0=(1/2,sqrt(3)/2). Write q=exp(-2 sigma^2) and m_n=(E[X_n,x^2], E[X_n,y^2]).

m_(n+1) = M m_n with M = [[(1+q)/8,(1-q)/8],[(1-q)/2,(1+q)/2]].

The dominant eigenvalue is approximately 0.9781636854 and second-moment leakage decays asymptotically as A rho^n. Pure random rotations satisfy E[X_(n,x)^2] = 1/2-(1/4)q^n, approaching 1/2. The protected process is non-unitary and loses norm; normalized leakage has a nonzero limiting fraction.

## Reproducibility

- `python research/socorro/verify.py` requires sympy
- `python research/socorro/validate_torch.py` requires torch
- `python research/socorro/validate.py` requires numpy; seeded 200,000-trajectory Monte Carlo and analytical recurrence
- These are independent simulations/tests, not compiled Lean/Coq or hardware validation.

[Read public results](https://nicholaskouns-create.github.io/Identity/site/socorro-stochastic.html) · [Mathematical City mirror](https://nicholaskouns-create.github.io/research/socorro.html)
