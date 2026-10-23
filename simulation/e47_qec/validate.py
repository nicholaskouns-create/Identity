import json, hashlib
from pathlib import Path
from fractions import Fraction
import numpy as np
from scipy.linalg import norm
from e47_qec import carrier,recovery,noise,E47WeightAdapter
rng=np.random.default_rng(47); checks=[]
def check(name,value,tol=1e-9):
    ok=bool(value) if isinstance(value,(bool,np.bool_)) else float(value)<tol
    checks.append(dict(name=name,pass_=ok,value=bool(value) if isinstance(value,(bool,np.bool_)) else float(value),tolerance=tol))
    print(('PASS ' if ok else 'FAIL ')+name+' '+str(value),flush=True)
b=carrier(); I=np.eye(125); Q,S,T,P,Ps,Pt,V,U,K,G=[b[k] for k in ['Q','S','T','P','Ps','Pt','V','U','K','Gamma']]
Jx,Jy,Jz=b['J']
for name,a,c,d in [('xy',Jx,Jy,Jz),('yz',Jy,Jz,Jx),('zx',Jz,Jx,Jy)]:
    check('Lie commutator '+name,norm(a@c-c@a-1j*d))
for i,J in enumerate(b['J']):check('Casimir central '+str(i),norm(b['C']@J-J@b['C']))
for i,J in enumerate(b['J']):check('E47 invariant '+str(i),norm(P@J-J@P))
check('rank47',Q.shape==(125,47));check('projector',norm(P@P-P));check('kernel',norm(K@Q))
w={0:1}
for _ in range(3):
    out={}
    for a,v in w.items():
        for d in range(-2,3):out[a+d]=out.get(a+d,0)+v
    w=out
mult=[w.get(j,0)-w.get(j+1,0) for j in range(7)]
check('exact spin multiplicities',mult==[1,3,5,4,3,2,1])
ks=sorted((j*(j+1)-6)**2*(j*(j+1)-30)**2 for j in range(7) if j not in (2,5))
check('exact optimal epsilon',Fraction(2,min(ks)+max(ks))==Fraction(1,99144))
check('exact rho',max(abs(1-Fraction(v,99144)) for v in ks)==Fraction(15,17))
for n in [1,10,50,100]: check('contraction norm n='+str(n),abs(norm(np.linalg.matrix_power(G,n)-P,2)-(15/17)**n))
check('syndrome orthogonality',norm(Q.T@S));check('swap unitary',norm(U.T@U-I))
# Knill-Laflamme for error basis I,U; diagonal alpha=1, off-diagonal=0.
for a,E in enumerate([I,U]):
    for c,F in enumerate([I,U]): check('KL '+str(a)+str(c),norm(Q.T@E.T@F@Q-(np.eye(47) if a==c else 0)))
# Recovery Kraus completeness: R0=P, R1=V^dagger, Rt=|q0><t|.
check('recovery trace preserving',norm(P@P+V@V.T+Pt-I))
worst=0.; before=[]; after=[]; trace_err=0.; min_eig=1.
for trial in range(12):
    z=rng.normal(size=47)+1j*rng.normal(size=47);z/=norm(z)
    psi=Q@z;rho=np.outer(psi,psi.conj())
    for p in [0.,.1,.5,1.]:
        noisy=noise(rho,b,p);rec=recovery(noisy,b)
        worst=max(worst,norm(rec-rho));before.append(float(np.real(psi.conj()@noisy@psi)));after.append(float(np.real(psi.conj()@rec@psi)))
        trace_err=max(trace_err,abs(np.trace(rec)-1));min_eig=min(min_eig,float(np.linalg.eigvalsh(rec).min()))
check('48 quantum state/channel recoveries',worst);check('recovered trace',trace_err);check('recovered positivity',min_eig>=-1e-10)
# Universal channel/entanglement fidelity follows from effective Kraus matrices.
for p in [0.1,0.5,1.]:
    errors=[np.sqrt(1-p)*I,np.sqrt(p)*U]
    rs=[P,V.T]+[np.outer(Q[:,0],t) for t in T.T]
    fe=sum(abs(np.trace(Q.T@r@e@Q))**2 for r in rs for e in errors)/47**2
    check('entanglement fidelity p='+str(p),abs(fe-1))
# A coherent unitary exp(-i theta U) is also in the correctable error span.
theta=.73;E=np.cos(theta)*I-1j*np.sin(theta)*U
check('coherent error recovery',norm(recovery(E@rho@E.conj().T,b)-rho))
# Seven qubits represent 128 levels: append 3 unused levels and reset Kraus.
U128=np.eye(128);U128[:125,:125]=U
psi128=np.pad(psi,(0,3));err128=U128@psi128
check('7-qubit embedded swap decode',norm(Q.T@V.T@err128[:125]-z))
# Classical LLM adapter with batch and token axes; exact encoded-block swap model.
D=64;blocks=2;A=rng.normal(size=(blocks,47,D))/np.sqrt(D);B=rng.normal(size=(D,blocks,47))*.01
adapter=E47WeightAdapter(A,B,b);h=rng.normal(size=(3,8,D));baseline=h@adapter.effective_weight().T
mask=rng.random((3,8,blocks))<.5
out=adapter.forward(h,mask)
check('LLM adapter 24 tokens 48 protected blocks',norm(out-baseline))
# Reference no-recovery readout, same faults.
zbatch=np.einsum('...d,brd->...br',h,A);x=np.einsum('...br,ir->...bi',zbatch,Q);x=np.where(mask[...,None],x@U.T,x)
bad=h+np.einsum('...br,dbr->...d',x@Q,B)
# FP32 execution is measured, not assumed exact.
b32={k:v.astype(np.float32) for k,v in b.items() if k in ['Q','S','U']}
a32=E47WeightAdapter(A.astype(np.float32),B.astype(np.float32),b32)
err32=norm(a32.forward(h.astype(np.float32),mask)-baseline)/norm(baseline)
check('FP32 relative adapter error',err32,2e-6)
# Analytical backward pass dL/dh = W_eff^T grad, for the corrected fault model.
grad=rng.normal(size=out.shape);direction=rng.normal(size=h.shape);step=1e-5
fd=np.sum((adapter.forward(h+step*direction,mask)-adapter.forward(h-step*direction,mask))*grad)/(2*step)
analytic=np.sum((grad@adapter.effective_weight())*direction)
check('LLM input gradient finite difference',abs(fd-analytic),1e-7)
summary=dict(checks=checks,passed=sum(x['pass_'] for x in checks),total=len(checks),max_quantum_recovery_frobenius_error=worst,min_recovered_fidelity=min(after),min_uncorrected_fidelity=min(before),adapter_uncorrected_error=float(norm(bad-baseline)),adapter_corrected_error=float(norm(out-baseline)),adapter_fp32_relative_error=float(err32),seed=47,scope='synthetic hidden states; no pretrained LLM or physical quantum hardware')
Path(__file__).with_name('results.json').write_text(json.dumps(summary,indent=2))
np.savez(Path(__file__).with_name('e47_basis.npz'),Q=Q,S=S,T=T)
assert all(x['pass_'] for x in checks)
