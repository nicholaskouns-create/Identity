import numpy as np
from itertools import permutations, combinations_with_replacement, product
from collections import Counter
from fractions import Fraction as F
from scipy.linalg import eigh
m=np.arange(2,-3,-1); z=np.diag(m); p=np.diag(np.sqrt(6-m[1:]*(m[1:]+1)),1); j=[(p+p.T)/2,(p-p.T)/2j,z]; I=np.eye(5); H=np.eye(125)
T=[np.kron(np.kron(a,I),I)+np.kron(np.kron(I,a),I)+np.kron(np.kron(I,I),a) for a in j]; C=sum(a@a for a in T).real
Pi=np.zeros((125,125))
for s in permutations(range(3)):
 for a in product(range(5),repeat=3): Pi[np.ravel_multi_index(tuple(a[i] for i in s),(5,)*3),np.ravel_multi_index(a,(5,)*3)]+=1/6
K=(C-6*H)@(C-30*H); A=K@K+11664*(H-Pi); w,V=eigh(A); W=V[:,abs(w)<1e-7]; P=W@W.T; G=H-A/99144
weights=Counter(sum(a) for a in product(range(-2,3),repeat=3)); sym=Counter(sum(a) for a in combinations_with_replacement(range(-2,3),3)); spec=Counter()
for s in range(7):
 d=2*s+1; a=((s*(s+1)-6)*(s*(s+1)-30))**2; b=sym[s]-sym[s+1]; c=weights[s]-weights[s+1];
 if b: spec[a]+=d*b
 if c>b: spec[a+11664]+=d*(c-b)
assert Counter(np.rint(w).astype(int))==spec and W.shape==(125,5)
assert max(abs(1-F(a,99144)) for a in spec if a)==F(15,17)
assert np.linalg.norm(G@P-P)<1e-12
J=[W.T@a@W for a in T]; L=[np.kron(a,I)-np.kron(I,a.T) for a in J]; adj=Counter(np.rint(np.linalg.eigvalsh(sum(a@a for a in L))).astype(int)); assert adj=={0:1,2:3,6:5,12:7,20:9}
# Eight-qubit unitary dilation, padding three states with zero success amplitude.
B=np.zeros((128,128)); B[:125,:125]=G; ev,Q=eigh(B); S=(Q*np.sqrt(np.maximum(0,1-ev**2)))@Q.T; U=np.block([[B,S],[S,-B]]); err=np.linalg.norm(U.T@U-np.eye(256),ord=2); assert err<1e-12
rng=np.random.default_rng(47); x=rng.normal(size=125)+1j*rng.normal(size=125); x/=np.linalg.norm(x); y=np.r_[x,np.zeros(3)]; state=U@np.r_[y,np.zeros(128)]; assert np.linalg.norm(state[:125]-G@x)<1e-12
for n in (1,10,50,220):
 g=np.linalg.matrix_power(G,n); assert np.linalg.norm(g-P,2)<=float(F(15,17)**n)+1e-12
print('A spectrum:',sorted(spec.items())); print('adjoint:',sorted(adj.items())); print('rank',W.shape[1],'contraction',np.linalg.norm(G-P,2),'unitary residual',err); print('PASS: explicit carrier, exact character counts, spectral contraction, adjoint, 8-qubit statevector dilation')