"""FOURIER-47-125-001: exact integer/rational and NumPy validation.
Run: python validate.py. Writes results.json beside this source.
No Lean/Coq compiler or quantum hardware execution is claimed.
"""
import hashlib
import json
import platform
from fractions import Fraction
from pathlib import Path
import numpy as np

N = 125
S = list(range(24)) + list(range(102, 125))
checks = []
def exact(name, ok, detail):
    checks.append(dict(name=name, kind='exact', passed=bool(ok), detail=detail))
def numeric(name, residual, tolerance=1e-12):
    checks.append(dict(name=name, kind='numerical', passed=bool(residual < tolerance), residual=float(residual), tolerance=tolerance))

# Phi_125(z) = z^100 + z^75 + z^50 + z^25 + 1.
# Integer polynomial reduction certifies all 125 Fourier differences.
remainders=[]
for d in range(N):
    a=[0]*N
    for t in range(N): a[(d*t)%N]+=1
    for j in range(124,99,-1):
        c=a[j]
        for offset in (0,25,50,75,100): a[j-100+offset]-=c
    expected=[125 if d==0 else 0]+[0]*99
    remainders.append(a[:100]==expected)
exact('125 cyclotomic orthogonality identities',all(remainders),{'passed':sum(remainders),'total':125})
exact('47 distinct selected frequencies',len(S)==len(set(S))==47,'1 + 2*23 = 47')
exact('conjugate-closed selection',set((-k)%N for k in S)==set(S),'S = -S modulo 125')
exact('dimension split',47+78==125,'47 + 78 = 125')
exact('impulse fraction',Fraction(47,125)==Fraction(376,1000),'47/125 = 0.376 = 37.6%')
exact('mixed-signal fraction',1/(1+Fraction(1,2)**2)==Fraction(4,5),'1/(1+1/4) = 4/5 = 80%')

t=np.arange(N); F=np.fft.fft(np.eye(N),norm='ortho'); Q=F[:,S]; P=Q@Q.conj().T; I=np.eye(N)
B=np.column_stack([np.ones(N)/np.sqrt(N)]+[v for k in range(1,24) for v in (np.sqrt(2/N)*np.cos(2*np.pi*k*t/N),np.sqrt(2/N)*np.sin(2*np.pi*k*t/N))])
op=lambda A: np.linalg.norm(A,2)
numeric('Fourier orthonormality',op(Q.conj().T@Q-np.eye(47)))
numeric('idempotence',op(P@P-P))
numeric('self-adjointness',op(P.conj().T-P))
numeric('reality',op(P.imag))
numeric('real-basis orthonormality',op(B.T@B-np.eye(47)))
numeric('real-basis reconstruction',op(P-B@B.T))
ev=np.linalg.eigvalsh(P)
numeric('78 zero eigenvalues',max(abs(ev[:78])))
numeric('47 unit eigenvalues',max(abs(ev[78:]-1)))
numeric('trace 47',abs(np.trace(P)-47))
numeric('all 125 impulse fractions',max(abs(np.sum(abs(P)**2,axis=0)-47/125)))
numeric('complement orthogonality',op(P@(I-P)))
numeric('all 125 Fourier basis actions',op(P@F-F@np.diag([int(k in S) for k in range(N)])))

rng=np.random.default_rng(47); X=rng.standard_normal((125,1000)); X/=np.linalg.norm(X,axis=0)
PX=P@X; RX=X-PX
numeric('1000 energy decompositions',max(abs(np.sum(abs(PX)**2,axis=0)+np.sum(abs(RX)**2,axis=0)-1)))
numeric('1000 coordinate reconstructions',max(np.linalg.norm(PX-B@(B.T@X),axis=0)))
Z=rng.standard_normal((125,1000)); Z/=np.linalg.norm(Z,axis=0)
numeric('1000 discarded perturbations',max(np.linalg.norm(P@(X+(I-P)@Z)-PX,axis=0)))

signals={'dc':np.ones(N),'freq_3':np.sin(2*np.pi*3*t/N),'freq_20':np.sin(2*np.pi*20*t/N),'freq_40':np.sin(2*np.pi*40*t/N),'mixed':np.sin(2*np.pi*3*t/N)+.5*np.sin(2*np.pi*40*t/N),'ramp':np.linspace(0,1,N),'impulse':np.eye(N)[62]}
retention={name:float(np.vdot(P@x,P@x).real/np.vdot(x,x).real) for name,x in signals.items()}
for name,value in {'dc':1,'freq_3':1,'freq_20':1,'freq_40':0,'mixed':.8,'impulse':.376}.items(): numeric('retention '+name,abs(retention[name]-value))
x=signals['freq_3']; y=x+2*signals['freq_40']
equivalence={'input_distance':float(np.linalg.norm(x-y)),'projected_distance':float(np.linalg.norm(P@x-P@y))}
numeric('original equivalence example',equivalence['projected_distance'])
result=dict(record_id='FOURIER-47-125-001',construction='Cyclic DFT on R^125; selected frequencies -23 through 23',python=platform.python_version(),numpy=np.__version__,dtype=str(P.dtype),seed=47,matrix_norm='operator 2-norm',rank=int(np.linalg.matrix_rank(P,tol=1e-10)),checks=checks,energy_retention=retention,equivalence=equivalence,passed=sum(c['passed'] for c in checks),total=len(checks),source_sha256=hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),scope='Exact integer/rational checks and mathematical proof plus floating-point implementation validation. Identification with a Casimir-selected projector requires an explicit map; none is asserted here.')
Path(__file__).with_name('results.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps(result,indent=2))
if not all(c['passed'] for c in checks): raise SystemExit(1)
