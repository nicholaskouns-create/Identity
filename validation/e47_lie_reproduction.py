"""Independent numerical Lie algebra and Casimir reproduction; not a Lean/Coq certificate."""
import numpy as np
from collections import Counter
from fractions import Fraction
from itertools import combinations

m=np.arange(2,-3,-1)
z=np.diag(m.astype(float)); up=np.zeros((5,5))
for col in range(1,5):
    q=m[col]
    up[col-1,col]=np.sqrt((2-q)*(3+q))
down=up.T; I=np.eye(5)
def comm(a,b): return a@b-b@a
def residual(a,b): return float(np.max(np.abs(a-b)))
def check(label,a,b,tol=1e-10):
    e=residual(a,b)
    assert e<tol,(label,e)
    print('PASS',label,'max residual',f'{e:.3e}')
check('single [Jz,J+]',comm(z,up),up)
check('single [Jz,J-]',comm(z,down),-down)
check('single [J+,J-]',comm(up,down),2*z)
check('single Casimir',down@up+z@(z+I),6*I)
def total(A):
    return np.kron(np.kron(A,I),I)+np.kron(np.kron(I,A),I)+np.kron(np.kron(I,I),A)
Z,U,D=map(total,(z,up,down)); Q=np.eye(125)
check('tensor [Jz,J+]',comm(Z,U),U)
check('tensor [Jz,J-]',comm(Z,D),-D)
check('tensor [J+,J-]',comm(U,D),2*Z)
C=D@U+Z@(Z+Q)
check('Casimir symmetry',C,C.T)
for label,A in [('Jz',Z),('J+',U),('J-',D)]:
    check('Casimir commutes with '+label,comm(C,A),np.zeros_like(C))
eig,V=np.linalg.eigh(C)
rounded=np.rint(eig).astype(int)
assert np.max(np.abs(eig-rounded))<1e-10
spec=dict(sorted(Counter(rounded).items()))
expected={0:1,2:9,6:25,12:28,20:27,30:22,42:13}
assert spec==expected,(spec,expected)
print('PASS spectrum',spec)
mask=np.isin(rounded,[6,30])
assert int(mask.sum())==47
P=V[:,mask]@V[:,mask].T
K=(C-6*Q)@(C-30*Q)
check('P idempotence',P@P,P)
check('P symmetry',P,P.T)
check('K P annihilation',K@P,np.zeros_like(P),tol=1e-9)
assert abs(np.trace(P)-47)<1e-9
eps=Fraction(1,99144)
rho=max(abs(1-eps*(lam-6)**2*(lam-30)**2) for lam in spec if lam not in (6,30))
assert rho==Fraction(15,17)
subsets=[s for n in range(8) for s in combinations(spec,n)]
assert len(subsets)==128
assert max(sum(spec[x] for x in s) for s in combinations(spec,2))==55
print('PASS E47 rank=47, contraction rho=15/17, 128 subsets, quadratic maximum=55')
