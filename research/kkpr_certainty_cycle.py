#!/usr/bin/env python3
"""Concrete KKP-R E47 gate, gradient score and protected reset. NumPy/SciPy."""
import json
from pathlib import Path
import numpy as np
from scipy.linalg import eigh, expm
out=Path(__file__).resolve().parent
I=np.eye(5);m=np.arange(-2,3,dtype=float);jp=np.zeros((5,5),complex)
for i,v in enumerate(m[:-1]):jp[i+1,i]=np.sqrt(6-v*(v+1))
jm=jp.conj().T;jx=(jp+jm)/2;jy=(jp-jm)/(2j);jz=np.diag(m)
def k(a,b,c):return np.kron(np.kron(a,b),c)
Js=[k(j,I,I)+k(I,j,I)+k(I,I,j) for j in (jx,jy,jz)]
C=np.real(sum(j@j for j in Js));cv,V=eigh(C)
Q=V[:,np.isclose(cv,6,atol=1e-8)|np.isclose(cv,30,atol=1e-8)]
assert Q.shape==(125,47)
P=Q@Q.T; K=(C-6*np.eye(125))@(C-30*np.eye(125))
Gamma=np.eye(125)-K@K/99144
S=np.roll(I,1,axis=0);l=2*I-S-S.T;d=(S-S.T)/2
L=k(l,I,I)+k(I,l,I)+k(I,I,l)
D=k(d,I,I)+.7*k(I,d,I)-.4*k(I,I,d)
B=Q.T@L@Q;A=3*Q.T@D@Q
Psi=expm(.1*(A-.2*B))
Sigma=np.eye(125)-.01*L
threshold=.5
lam,U=eigh(B)
ybase=U[:,0]*np.sqrt(.1/lam[0])
def score(y):return float(y@B@y)
assert score(ybase)<threshold
def once(rho):
    y=Psi@(Q.T@(Gamma@(Sigma@rho)))
    e=score(y)
    passed=bool(e<=threshold)
    z=y if passed else ybase
    v=Q@z
    return v,{"accepted":passed,"candidate_energy":e,"output_energy":score(z),
              "leakage":float(np.linalg.norm((np.eye(125)-P)@v)),
              "reset_error":float(np.linalg.norm(z-ybase)) if not passed else 0.0}
rng=np.random.default_rng(47);experiments=[]
for trial in range(25):
    rho=rng.normal(size=125);rho/=np.linalg.norm(rho)
    rho*=.1 if trial%3==0 else (4. if trial%3==1 else 1.)
    rows=[]
    for t in range(20):
        rho,info=once(rho)
        assert info["leakage"]<1e-9
        assert info["output_energy"]<=threshold+1e-10
        assert info["reset_error"]<1e-12
        rows.append(info)
    experiments.extend(rows)
passes=sum(v["accepted"] for v in experiments)
low=U[:,0]*np.sqrt(.2/lam[0]);high=U[:,-1]*np.sqrt(1.5/lam[-1])
assert score(low)<threshold<score(high)
report={
  "description":"Numerical E47 six-stage certainty-gated cycle; not a matrix-level formal proof",
  "dimensions":[125,47],"threshold":threshold,"baseline_energy":score(ybase),
  "gate":"score(y)=y.T B y <= threshold, B=Q.T L Q",
  "stages":{"Sigma":"I-0.01 L","Gamma":"I-K^2/99144","Lambda":"Q.T",
            "Psi":"expm(0.1(A-0.2B))","Omega_e":"score(y)<=0.5",
            "alpha":"Q y if pass else Q ybase"},
  "trial_count":25,"cycles_per_trial":20,
  "accepted":passes,"reset":len(experiments)-passes,
  "max_leakage":max(v["leakage"] for v in experiments),
  "max_output_energy":max(v["output_energy"] for v in experiments),
  "max_reset_error":max(v["reset_error"] for v in experiments),
  "projector_idempotence_residual":float(np.linalg.norm(P@P-P)),
  "projector_embedding_residual":float(np.linalg.norm(P@Q-Q)),
  "kernel_annihilation_residual":float(np.linalg.norm(K@Q)),
  "forced_accept_energy":score(low),"forced_reject_energy":score(high)
}
(out/"kkpr_certainty_cycle_results.json").write_text(json.dumps(report,indent=2)+"\n")
print(json.dumps(report,indent=2))
