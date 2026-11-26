#!/usr/bin/env python3
"""Does the flowed coframe satisfy Einstein's equations? No — this shows why.

Companion to crf_coframe_derivation.py. Everything here tests the construction
built in THAT file. Nothing here tests or bears on the E47 formalism; Omega_c =
47/125 and the spectral facts are untouched and are reconfirmed there.

G_mn + Lam g_mn = 8pi T_mn cannot be derived from a metric: for any g, define
T := (G + Lam g)/8pi and it holds identically. The decidable question is whether
the geometry satisfies the field equations with an ADMISSIBLE source. It does
not:

  not an Einstein manifold   ||Ric - Lam g||/||Ric|| = 1.59
  anisotropic pressures      (0.4016, 0.5400, 0.7095), 23% spread
  shear present              1.31e-1
  equation of state          w = +3.32  (sound speed above c)
  dominant energy condition  FAILS

The reason is structural. The coframe is a pullback along a group orbit, and a
pullback carries no dynamics. Einstein's equations are Euler-Lagrange equations
of an action; nothing in exp(-x0 eps A) exp(i xk Jk) says how geometry responds
to matter. That is bridge 3 of lorentzian_curved_witness_2026-11-22.md, and it
is not reachable from here.

Run:  python3 research/e47_gr/crf_einstein_test.py
"""

import numpy as np
from scipy.linalg import expm
# Operators rebuilt here rather than imported: importing the companion would
# run its whole report as an import side effect.
def _spin(j):
    d = int(round(2*j+1)); m = np.array([j-k for k in range(d)])
    Jp = np.zeros((d, d), complex)
    for k in range(1, d):
        Jp[k-1, k] = np.sqrt(j*(j+1) - m[k]*(m[k]+1))
    Jm = Jp.conj().T
    return (Jp+Jm)/2, (Jp-Jm)/complex(0, 2), np.diag(m).astype(complex)

_I5 = np.eye(5); _jx, _jy, _jz = _spin(2)
def _lift(a, w):
    o = [_I5, _I5, _I5]; o[w] = a
    return np.kron(np.kron(o[0], o[1]), o[2])
J = [sum(_lift(a, w) for w in range(3)) for a in (_jx, _jy, _jz)]
_C = sum(Jk @ Jk for Jk in J); _C = (_C + _C.conj().T)/2
_K = (_C - 6*np.eye(125)) @ (_C - 30*np.eye(125)); _K = (_K + _K.conj().T)/2
A = _K @ _K
_w, _V = np.linalg.eigh(A)
P47 = _V[:, np.abs(_w) < 1e-6] @ _V[:, np.abs(_w) < 1e-6].conj().T
eta = 2*P47 - np.eye(125)
assert np.linalg.norm(eta @ eta - np.eye(125)) < 1e-12, "eta must be an involution"
assert int(round(np.trace(P47).real)) == 47, "rank P47 must be 47"
EPS=1/99144; rng=np.random.default_rng(47)
KER=_V[:,np.abs(_w)<1e-6]; COMP=_V[:,np.abs(_w)>1e-6]
u=KER@(rng.normal(size=47)+1j*rng.normal(size=47)); u/=np.linalg.norm(u)
v=COMP@(rng.normal(size=78)+1j*rng.normal(size=78)); v/=np.linalg.norm(v)
W=0.85; PSI0=np.sqrt(W)*u+np.sqrt(1-W)*v; PSI0/=np.linalg.norm(PSI0)
def psi(x):
    g=expm(complex(0,1)*(x[1]*J[0]+x[2]*J[1]+x[3]*J[2]))
    p=expm(-x[0]*EPS*A)@(g@PSI0); return p/np.linalg.norm(p)
hm=1e-4
def gmet(x):
    x=np.asarray(x,float); d=[]
    for m in range(4):
        e=np.zeros(4); e[m]=hm; d.append((psi(x+e)-psi(x-e))/(2*hm))
    return np.array([[float(np.real(np.vdot(d[a],eta@d[b]))) for b in range(4)] for a in range(4)])

H=2e-3
def dg(x,l):
    e=np.zeros(4); e[l]=H; return (gmet(x+e)-gmet(x-e))/(2*H)
def chris(x):
    g=gmet(x); gi=np.linalg.inv(g); d=[dg(x,l) for l in range(4)]
    G=np.zeros((4,4,4))
    for a in range(4):
        for b in range(4):
            for c in range(4):
                G[a,b,c]=0.5*sum(gi[a,e]*(d[b][e,c]+d[c][e,b]-d[e][b,c]) for e in range(4))
    return G
def riem(x):
    G0=chris(x); dG=[]
    for l in range(4):
        e=np.zeros(4); e[l]=H; dG.append((chris(x+e)-chris(x-e))/(2*H))
    R=np.zeros((4,4,4,4))
    for a in range(4):
        for b in range(4):
            for c in range(4):
                for d_ in range(4):
                    t=dG[c][a,d_,b]-dG[d_][a,c,b]
                    for e_ in range(4): t+=G0[a,c,e_]*G0[e_,d_,b]-G0[a,d_,e_]*G0[e_,c,b]
                    R[a,b,c,d_]=t
    return R
x0=np.zeros(4); g=gmet(x0); gi=np.linalg.inv(g)
R4=riem(x0); Ric=np.einsum('abad->bd',R4); Rs=float(np.einsum('ab,ab->',gi,Ric))
G=Ric-0.5*g*Rs

print("="*74); print("EINSTEIN TENSOR OF THE FLOWED METRIC"); print("="*74)
print(f"  R = {Rs:.6f}")
print("  G_mu,nu ="); 
for r in G: print("     ", "  ".join(f"{q:11.5f}" for q in r))

print(); print("="*74); print("TEST 1 — is it an EINSTEIN MANIFOLD?   R_ab = Lam g_ab"); print("="*74)
Lam_fit=float(np.einsum('ab,ab->',gi,Ric))/4
resid=Ric-Lam_fit*g
rel=np.linalg.norm(resid)/max(np.linalg.norm(Ric),1e-300)
print(f"  best-fit Lambda   = {Lam_fit:.6f}   (= R/4)")
print(f"  ||Ric - Lam g||   = {np.linalg.norm(resid):.4e}")
print(f"  relative residual = {rel:.4f}")
print(f"  verdict: {'EINSTEIN MANIFOLD' if rel<1e-3 else 'NOT an Einstein manifold'}")

print(); print("="*74); print("TEST 2 — the implied source, in an orthonormal frame"); print("="*74)
w,P=np.linalg.eigh(g)                      # g = P diag(w) P^T
order=np.argsort(w); w=w[order]; P=P[:,order]
E=P@np.diag(1/np.sqrt(np.abs(w)))          # tetrad: E^T g E = diag(-1,1,1,1)
check=E.T@g@E
print(f"  tetrad check  E^T g E = diag{np.round(np.diag(check),6)}  offdiag {np.abs(check-np.diag(np.diag(check))).max():.1e}")
That=E.T@G@E/(8*np.pi)                     # T in the orthonormal frame, G=c=1
print("  T_(ab) = G_(ab)/8pi  in the orthonormal frame:")
for r in That: print("     ", "  ".join(f"{q:11.6f}" for q in r))
rho=That[0,0]; pr=np.array([That[i,i] for i in (1,2,3)])
print(f"\n  energy density rho = {rho:+.6f}")
print(f"  principal pressures = {np.round(pr,6)}")
print(f"  isotropic? spread/|mean| = {pr.std()/max(abs(pr.mean()),1e-30):.4f}")
print(f"  equation of state w = p/rho = {pr.mean()/rho:+.6f}" if abs(rho)>1e-12 else "  rho ~ 0")
print(f"  off-diagonal (heat flux / shear) max = {np.abs(That-np.diag(np.diag(That))).max():.3e}")

print(); print("="*74); print("TEST 3 — energy conditions on the implied source"); print("="*74)
print(f"  weak   (rho >= 0)             : {rho>=0}")
print(f"  null   (rho + p_i >= 0 all i) : {all(rho+p>=-1e-9 for p in pr)}")
print(f"  strong (rho + sum p_i >= 0)   : {rho+pr.sum()>=-1e-9}")
print(f"  dominant (rho >= |p_i| all i) : {all(rho>=abs(p)-1e-9 for p in pr)}")

print(); print("="*74); print("TEST 4 — Bianchi, as a check on the NUMERICS not the physics"); print("="*74)
def Gmix(x):
    gg=gmet(x); ggi=np.linalg.inv(gg); RR=riem(x); Rc=np.einsum('abad->bd',RR)
    Rsc=float(np.einsum('ab,ab->',ggi,Rc))
    return ggi@(Rc-0.5*gg*Rsc)
G0=Gmix(x0); C0=chris(x0); dGm=[]
for l in range(4):
    e=np.zeros(4); e[l]=H; dGm.append((Gmix(x0+e)-Gmix(x0-e))/(2*H))
div=np.zeros(4)
for b in range(4):
    s=0.0
    for a in range(4):
        s+=dGm[a][a,b]
        for c in range(4): s+=C0[a,a,c]*G0[c,b]-C0[c,a,b]*G0[a,c]
    div[b]=s
print(f"  div G^a_b = {np.round(div,6)}")
print(f"  ||div G|| / ||G|| = {np.linalg.norm(div)/np.linalg.norm(G0):.4e}")
print("  (Bianchi makes this identically zero in exact arithmetic; a small")
print("   value here measures finite-difference error, nothing physical.)")
