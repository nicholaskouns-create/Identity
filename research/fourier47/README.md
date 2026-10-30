# Rank-47 Fourier Projector on R^125

Record: **FOURIER-47-125-001**. Construction supplied by Nicholas Shane Kouns.

**28/28 validation checks passed: 6 exact checks and 22 floating-point checks.** The exact orthogonality check covers all 125 frequency differences using integer polynomial arithmetic. Numerical tolerance is 1e-12; matrix residuals use the operator 2-norm. Run `python validate.py` with NumPy installed. The recorded environment is Python 3.12.14 / NumPy 2.3.5, complex128, seed 47. Re-running overwrites results.json with the new environment's measured results.

## Exact theorem and proof

Let N=125, S={-23,...,23} modulo 125, and q_k(t)=exp(-2*pi*i*k*t/125)/sqrt(125), for t=0,...,124. Let Q contain the columns q_k for k in S, and P=QQ*.

### Orthogonality

The inner product <q_j,q_k> is (1/125) times the sum from t=0 to 124 of exp(2*pi*i*(j-k)*t/125). When j=k the sum is 125. Otherwise its ratio r is a nontrivial 125th root of unity and the geometric sum is (1-r^125)/(1-r)=0. Thus Q*Q=I_47.

The executable exact check reduces all 125 sums sum_t z^((d*t) mod 125) modulo Phi_125(z)=z^100+z^75+z^50+z^25+1, using only integers. For d=0 the remainder is 125; for every d=1,...,124 it is zero. This covers every entry of the full Fourier Gram matrix by its frequency difference.

### Projector, dimension and real structure

P^2=Q(Q*Q)Q*=QQ*=P and P*=P. Since PQ=Q and range(P) is contained in range(Q), range(P)=range(Q). Therefore rank(P)=47 and nullity(P)=125-47=78.

Conjugate frequency pairing gives

P[t,s] = (1/125) [1 + 2 sum_{k=1}^{23} cos(2*pi*k*(t-s)/125)].

Every entry is real and P is symmetric. Its spectrum is exactly 47 ones and 78 zeros. Its trace is 47.

Define b_0(t)=1/sqrt(125), b_{k,c}(t)=sqrt(2/125)*cos(2*pi*k*t/125), and b_{k,s}(t)=sqrt(2/125)*sin(2*pi*k*t/125) for k=1,...,23. The 47 columns of B are orthonormal by the same Fourier orthogonality. Thus B^T B=I_47 and BB^T=P. Encoding a=B^T x uses 47 real coordinates; decoding Ba recovers Px exactly. If Px=x, decoding recovers x exactly.

### Orthogonal decomposition and minimum error

P(I-P)=0. For every real x, x=Px+(I-P)x is an orthogonal decomposition, so ||x||^2=||Px||^2+||(I-P)x||^2. For any z in range(P),

||x-z||^2 = ||(I-P)x||^2 + ||Px-z||^2.

The unique minimum occurs at z=Px. P is nonexpansive: ||Px|| <= ||x||.

### Equivalence and invariance

Px=Py iff P(x-y)=0 iff x-y belongs to ker(P). This is also equivalent to Q*x=Q*y, since Q*P=Q*. The map [x] -> Px is a well-defined linear bijection from R^125/ker(P) to range(P), a 47-dimensional real space. Every d in ker(P) satisfies P(x+d)=Px. Repeated projection stabilizes in one step: P^m=P for every integer m>=1.

### Calculator arithmetic

- 1 + 2*23 = 47 retained real coordinates.
- 125 - 47 = 78 discarded real coordinates.
- 47 + 78 = 125.
- For every unit coordinate impulse e_t, ||Pe_t||^2=e_t^T P^T P e_t=P[t,t]=(1+2*23)/125=47/125=0.376=37.6%.
- Frequencies 3 and 40 have equal squared sine norm 125/2 and are orthogonal. For x=sin(2*pi*3*t/125)+(1/2)sin(2*pi*40*t/125), retained energy is (125/2)/[(125/2)(1+1/4)]=4/5=80%.
- For y=x_3+2*x_40, ||y-x_3||=2*sqrt(125/2)=sqrt(250), while ||Py-Px_3||=0 exactly.

## Executed validation

See `results.json` for every measured value and `plate.svg` for the publication plate. The original input gives retained fractions: DC 1.0000000000000002; frequency 3 1.0000000000000002; frequency 20 0.9999999999999999; frequency 40 2.719097381593801e-29; mixed 0.8000000000000006; ramp 0.9942347483704114; impulse 0.37600000000000006. The ramp percentage is measured, not assigned an exact rational value.

Original equivalence example: input distance 15.811388300841891; projected distance 8.228871535158106e-14. Tests also cover all 125 Fourier basis actions, all 125 impulse retentions, the complete eigenvalue spectrum and 1,000 seeded normalized random vectors for energy decomposition, coordinate reconstruction and discarded-perturbation invariance.

The mathematical proof applies to every input. Floating-point results validate this implementation within the recorded tolerance. These are an exact mathematical proof, exact integer/rational computations and numerical validation; no Lean/Coq compilation is claimed for this record. This is the cyclic DFT projector with an explicitly chosen frequency set. Identifying it with a Casimir-selected E47 projector requires a specified intertwining map.

## Files

- `validate.py`: executable checks, exits nonzero on failure.
- `results.json`: complete measured receipt, environment, tolerance and source SHA-256.
- `plate.svg`: scalable code-rendered arithmetic and numerical plate.
- `render.py`: plate/report generator; requires Matplotlib and writes PNG, SVG and a self-contained HTML report with full proof, source and JSON receipt.

This record is additive to the existing Mathematical City archives and preserves their independent identities.
