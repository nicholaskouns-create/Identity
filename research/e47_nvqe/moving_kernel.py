#!/usr/bin/env python3
"""Numerical E47 finite spectral and transported eigenspace witness."""
import numpy as np
from scipy.linalg import expm
m=np.arange(-2,3,dtype=float)
z=np.diag(m).astype(complex)
p=np.zeros((5,5),complex)
for i,a in enumerate(m[:-1]):
    p[i+1,i]=np.sqrt((2-a)*(3+a))
x=(p+p.conj().T)/2
y=(p-p.conj().T)/(2j)
eye5=np.eye(5)
eye=np.eye(125)
def lift(M,k):
    ops=[eye5,eye5,eye5]
    ops[k]=M
    return np.kron(np.kron(ops[0],ops[1]),ops[2])
tot=[sum((lift(M,k) for k in range(3)),np.zeros((125,125),complex)) for M in (x,y,z)]
casimir=sum(M@M for M in tot)
K=(casimir-6*eye)@(casimir-30*eye)
A=K.conj().T@K
w,V=np.linalg.eigh(A)
selected=w<1e-6
P=V[:,selected]@V[:,selected].conj().T
assert sum(selected)==47
assert np.linalg.matrix_rank(K,tol=1e-6)==78
gap=float(min(w[~selected]))
largest=float(max(w))
assert abs(gap-11664)<1e-6
assert abs(largest-186624)<1e-6
rate=(largest-gap)/(largest+gap)
step=2/(gap+largest)
assert abs(rate-15/17)<1e-12
assert abs(step-1/99144)<1e-14
assert np.linalg.norm(P@P-P)<1e-10
assert np.linalg.norm(K@P)<1e-8
rng=np.random.default_rng(47)
psi=rng.normal(size=125)+1j*rng.normal(size=125)
psi/=np.linalg.norm(psi)
for n in [0,20,100,220]:
    evolved=V@((1-step*w)**n*(V.conj().T@psi))
    residual=np.linalg.norm(evolved-P@psi)
    bound=rate**n*np.linalg.norm((eye-P)@psi)
    assert residual<=bound+1e-10
    print("discrete",n,residual,bound)
H=np.zeros((128,128),complex)
H[:125,:125]=A
H[125:,125:]=largest*np.eye(3)
e,Q=np.linalg.eigh(H)
initial=np.zeros(128,complex)
initial[:125]=psi
for t in [0,1,2,4,8]:
    state=Q@(np.exp(-t*e/gap)*(Q.conj().T@initial))
    state/=np.linalg.norm(state)
    print("statevector",t, np.vdot(state,H@state).real,np.linalg.norm(P@state[:125])**2)
rng=np.random.default_rng(12)
v=rng.normal(size=125)+1j*rng.normal(size=125)
v/=np.linalg.norm(v)
a=V[:,selected][:,0]
b=V[:,~selected][:,0]
B=.12*(np.outer(b,a.conj())-np.outer(a,b.conj()))
d0=np.linalg.norm((eye-P)@v)
for t in [0,3,6,9,12,15]:
    Ut=expm(t*B)
    Pt=Ut@P@Ut.conj().T
    state=Ut@(V@(np.exp(-t*w/99144)*(V.conj().T@v)))
    residual=np.linalg.norm((eye-Pt)@state)
    bound=d0*np.exp(-gap*t/99144)
    assert residual<=bound+1e-10
    print("moving",t,residual,bound)
print("PASS")
