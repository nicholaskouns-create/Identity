"""Exact concrete 125-dimensional spin-2 Casimir and five-stage projector."""
from fractions import Fraction
from itertools import product
S=list(product(range(-2,3),repeat=3)); index={s:i for i,s in enumerate(S)}
ROOTS=(186624,19600,11664,32400,12544)
def matrix():
    cols=[]
    for s in S:
        z=sum(s); out={index[s]:z*z+z}
        for a in range(3):
            if s[a]==2:continue
            t=list(s);t[a]+=1
            for b in range(3):
                if t[b]==-2:continue
                u=t.copy();u[b]-=1; k=index[tuple(u)]
                out[k]=out.get(k,0)+(2-s[a])*(2+t[b])
        cols.append({k:v for k,v in out.items() if v})
    return cols
def apply(A,v):
    out={}
    for j,c in v.items():
        for i,a in A[j].items():out[i]=out.get(i,0)+a*c
    return {i:x for i,x in out.items() if x}
def polynomial(A,v,roots):
    for r in roots:
        av=apply(A,v)
        v={i:x for i in set(v)|set(av) if (x:=av.get(i,0)-r*v.get(i,0))}
    return v
def verify():
    A=matrix()
    for i in range(125):
        assert polynomial(A,{i:1},(0,2,6,12,20,30,42))=={}
    tr=Fraction(0)
    for i in range(125):
        v={i:Fraction(1)}
        for root in ROOTS:
            kv=polynomial(A,v,(6,30))
            k2v=polynomial(A,kv,(6,30))
            v={j:x for j in set(v)|set(k2v) if (x:=v.get(j,0)-Fraction(k2v.get(j,0),root))}
        tr+=v.get(i,0)
    assert tr==47
    return {"annihilator_basis_vectors":125,"projector_trace":str(tr),"stage_count":5}
if __name__=="__main__":print(verify())
