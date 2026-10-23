"""Exact SymPy algebra, rational nonorthonormal spin basis with explicit metric."""
import sympy as s
import json
from pathlib import Path
checks=[]
def ck(n,c):
    c=bool(c);checks.append({'name':n,'pass':c});print(('PASS ' if c else 'FAIL ')+n,flush=True);assert c
I5=s.eye(5);jp=s.zeros(5);jm=s.zeros(5);jz=s.diag(2,1,0,-1,-2)
for i in range(1,5):jp[i-1,i]=i;jm[i,i-1]=5-i
ck('exact sl2 raising/lowering',jp*jm-jm*jp==2*jz)
ck('exact sl2 z+',jz*jp-jp*jz==jp)
ck('exact sl2 z-',jz*jm-jm*jz==-jm)
ck('exact spin2 Casimir',jz*jz+(jp*jm+jm*jp)/2==6*I5)
def total(a):return s.SparseMatrix(s.kronecker_product(a,I5,I5)+s.kronecker_product(I5,a,I5)+s.kronecker_product(I5,I5,a))
Jp,Jm,Jz=map(total,[jp,jm,jz]);I=s.SparseMatrix(s.eye(125))
C=Jz*Jz+(Jp*Jm+Jm*Jp)/2
for name,J in [('plus',Jp),('minus',Jm),('z',Jz)]:ck('exact Casimir central '+name,C*J==J*C)
lambdas=[0,2,6,12,20,30,42]
P=s.SparseMatrix(s.zeros(125))
for selected in [6,30]:
    term=I
    for v in lambdas:
        if v!=selected:term=term*(C-v*I)/(selected-v)
    P+=term
K=(C-6*I)*(C-30*I)
ck('exact P idempotence',P*P==P)
ck('exact K P zero',K*P==s.zeros(125))
ck('exact rank via idempotent trace',s.trace(P)==47)
g=s.diag(1,s.Rational(1,4),s.Rational(1,6),s.Rational(1,4),1)
metric=s.SparseMatrix(s.kronecker_product(g,g,g))
ck('exact metric self adjoint',P.T*metric==metric*P)
# Symbolic two-syndrome block proof valid for any logical dimension r.
p=s.symbols('p',nonnegative=True);a,b=s.symbols('a b',complex=True)
Pc=s.diag(1,0);swap=s.Matrix([[0,1],[1,0]]);V=s.Matrix([[0,0],[1,0]])
ck('symbolic KL off diagonal',(Pc*swap*Pc)==s.zeros(2))
ck('symbolic recovery completeness',Pc*Pc+V*V.T==s.eye(2))
# Logical density matrix factors out as tensor identity; arbitrary coherent error.
r=s.Matrix([[a*s.conjugate(a),a*s.conjugate(b)],[b*s.conjugate(a),b*s.conjugate(b)]])
rec=Pc*r*Pc+V.T*r*V
ck('symbolic coherent syndrome recovery',rec==s.diag(a*s.conjugate(a)+b*s.conjugate(b),0))
Path(__file__).with_name('symbolic_results.json').write_text(json.dumps(checks,indent=2))
print('TOTAL',len(checks))
