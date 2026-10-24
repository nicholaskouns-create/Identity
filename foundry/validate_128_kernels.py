#!/usr/bin/env python3
"""Exact verification of 128 Casimir spectral kernels, standard library only."""
from collections import Counter
from itertools import combinations,product
from fractions import Fraction
import json,hashlib
EIG=(0,2,6,12,20,30,42)
MULT=(1,3,5,4,3,2,1)
DIM=tuple((2*j+1)*m for j,m in enumerate(MULT))
def weights():
 w=Counter({0:1})
 for _ in range(3):
  q=Counter()
  for a,n in w.items():
   for b in range(-2,3):q[a+b]+=n
  w=q
 return tuple(w[j]-w[j+1] for j in range(7))
def poly(x,roots):
 y=1
 for a in roots:y*=x-a
 return y
def L(x,i):
 n=d=1
 for j,e in enumerate(EIG):
  if j!=i:n*=x-e;d*=EIG[i]-e
 return Fraction(n,d)
def concrete_casimir_annihilator():
 states=list(product(range(-2,3),repeat=3));pos={s:i for i,s in enumerate(states)}
 cols=[]
 for s in states:
  m=sum(s);c={pos[s]:m*m+m}
  for a in range(3):
   if s[a]==2:continue
   t=list(s);t[a]+=1
   for b in range(3):
    if t[b]==-2:continue
    u=t.copy();u[b]-=1;i=pos[tuple(u)]
    c[i]=c.get(i,0)+(2-s[a])*(2+t[b])
  cols.append({i:v for i,v in c.items() if v})
 def apply(v):
  y={}
  for j,q in v.items():
   for i,a in cols[j].items():y[i]=y.get(i,0)+a*q
  return {i:a for i,a in y.items() if a}
 for i in range(125):
  v={i:1}
  for lam in EIG:
   y=apply(v)
   v={k:q for k in y.keys()|v.keys() if (q:=y.get(k,0)-lam*v.get(k,0))}
  assert not v, i
def verify():
 assert weights()==MULT and sum(DIM)==125
 concrete_casimir_annihilator()
 assert all(L(x,i)==int(i==j) for i in range(7) for j,x in enumerate(EIG))
 rows=[]
 for degree in range(8):
  for ix in combinations(range(7),degree):
   roots=[EIG[i] for i in ix]
   selected=[i for i,x in enumerate(EIG) if (poly(x,roots)==0 if roots else False)]
   assert selected==list(ix)
   P=[sum((L(x,i) for i in ix),Fraction(0)) for x in EIG]
   assert all(p in (0,1) and p*p==p for p in P)
   assert all((poly(x,roots) if roots else 1)*P[j]==0 for j,x in enumerate(EIG))
   rank=sum(DIM[i] for i in ix)
   assert rank==sum(DIM[i]*P[i] for i in range(7))
   assert rank+sum(DIM[i] for i in range(7) if i not in ix)==125
   rows.append(dict(roots=roots,sector_spins=list(ix),rank=rank,codimension=125-rank,polynomial_degree=degree,status="PASS"))
 assert len(rows)==128
 assert len([a for a in rows if a["roots"]==[6,30] and a["rank"]==47])==1
 assert max(a["rank"] for a in rows if len(a["roots"])==2)==55
 assert Counter(len(a["roots"]) for a in rows)=={0:1,1:7,2:21,3:35,4:35,5:21,6:7,7:1}
 out=dict(title="Exact 128-kernel Casimir census",method="integer concrete Casimir annihilator; weight multiplicities; rational Lagrange functional calculus",basis_annihilator_checks=125,kernel_certificates_passed=128,sector_eigenvalues=EIG,multiplicities=MULT,sector_dimensions=DIM,entries=rows)
 out["sha256"]=hashlib.sha256(json.dumps(out,sort_keys=True,separators=(",",":")).encode()).hexdigest()
 return out
if __name__=="__main__":print(json.dumps(verify(),indent=2))
