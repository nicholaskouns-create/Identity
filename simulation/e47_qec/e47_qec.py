"""E47 active recovery and classical LLM adapter. NumPy/SciPy; no model download.
Quantum guarantee: errors in span{I,U}, where U swaps code and syndrome.
Classical adapter guarantee: exact identity or whole-block swap faults.
"""
import numpy as np
from scipy.linalg import eigh

def carrier():
    m=np.arange(2,-3,-1,dtype=float)
    jp=np.zeros((5,5),complex)
    for i in range(1,5): jp[i-1,i]=np.sqrt(6-m[i]*(m[i]+1))
    local=[(jp+jp.T)/2,(jp-jp.T)/(2j),np.diag(m)]
    eye=np.eye(5)
    def total(a):
        return np.kron(np.kron(a,eye),eye)+np.kron(np.kron(eye,a),eye)+np.kron(np.kron(eye,eye),a)
    J=[total(a) for a in local]
    C=sum(a@a for a in J).real
    vals,basis=eigh(C)
    selected=np.isclose(vals,6)|np.isclose(vals,30)
    Q=basis[:,selected]; rest=basis[:,~selected]
    S=rest[:,:47]; T=rest[:,47:]
    P=Q@Q.T; Ps=S@S.T; Pt=T@T.T
    V=S@Q.T; U=V+V.T+Pt
    K=(C-6*np.eye(125))@(C-30*np.eye(125))
    return dict(J=J,C=C,Q=Q,S=S,T=T,P=P,Ps=Ps,Pt=Pt,V=V,U=U,K=K,
                Gamma=np.eye(125)-K@K/99144)

def recovery(rho,b):
    """CPTP recovery: code retained, syndrome returned, unused space reset."""
    Q,P,V,Pt=(b[k] for k in ('Q','P','V','Pt'))
    return P@rho@P+V.T@rho@V+np.trace(Pt@rho)*np.outer(Q[:,0],Q[:,0])

def noise(rho,b,p):
    return (1-p)*rho+p*b['U']@rho@b['U'].T

class E47WeightAdapter:
    """Residual bottleneck for hidden states, using 47->125 encoding per block.
    A: (blocks,47,D), B: (D,blocks,47). Fixed Q/S; trainable A/B.
    syndrome_decode returns a classical unnormalized vector. This preserves
    signs/norms for classical inference; it does not measure quantum amplitudes.
    """
    def __init__(self,A,B,basis):
        self.A=np.asarray(A); self.B=np.asarray(B)
        self.Q=basis['Q']; self.S=basis['S']; self.U=basis['U']
    def forward(self,h,fault_mask=None):
        z=np.einsum('...d,brd->...br',h,self.A)
        x=np.einsum('...br,ir->...bi',z,self.Q)
        if fault_mask is not None:
            swapped=x@self.U.T
            x=np.where(np.asarray(fault_mask)[...,None],swapped,x)
        clean=x@self.Q; syndrome=x@self.S
        choose=np.sum(syndrome**2,axis=-1)>np.sum(clean**2,axis=-1)
        decoded=np.where(choose[...,None],syndrome,clean)
        return h+np.einsum('...br,dbr->...d',decoded,self.B)
    def effective_weight(self):
        return np.eye(self.A.shape[-1])+np.einsum('dbr,bre->de',self.B,self.A)
