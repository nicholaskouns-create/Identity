"""E47 algebra certificate: NumPy-only reproducible numerical test."""
import numpy as np

j = 2
m = np.arange(j, -j-1, -1, dtype=float)
jp = np.zeros((5,5), dtype=complex)
for i in range(1,5):
    jp[i-1,i] = np.sqrt(j*(j+1)-m[i]*(m[i]+1))
jx=(jp+jp.conj().T)/2
jy=(jp-jp.conj().T)/(2j)
jz=np.diag(m).astype(complex)
eye=np.eye(5)
def total(a):
    return np.kron(np.kron(a,eye),eye)+np.kron(np.kron(eye,a),eye)+np.kron(np.kron(eye,eye),a)
c=sum((total(a)@total(a) for a in (jx,jy,jz)),np.zeros((125,125),complex))
eig,vec=np.linalg.eigh(c)
nodes=[0,2,6,12,20,30,42]
assert [int(np.sum(np.abs(eig-x)<1e-7)) for x in nodes]==[1,9,25,28,27,22,13]
sel=(np.abs(eig-6)<1e-7)|(np.abs(eig-30)<1e-7)
p=vec[:,sel]@vec[:,sel].conj().T
k=(c-6*np.eye(125))@(c-30*np.eye(125))
gamma=np.eye(125)-k@k/99144
assert np.sum(sel)==47
assert np.linalg.norm(p@p-p)<1e-10
assert np.linalg.norm(k@p)<1e-8
assert np.linalg.norm(gamma@p-p)<1e-8
assert abs(max(abs(1-((v-6)*(v-30))**2/99144) for v in nodes if v not in (6,30))-15/17)<1e-12
for n in (1,2,10,40):
    assert abs(np.linalg.norm(np.linalg.matrix_power(gamma,n)-p,2)-(15/17)**n)<1e-8
print("PASS E47 spectral multiplicities, rank, projector, kernel, contraction")
