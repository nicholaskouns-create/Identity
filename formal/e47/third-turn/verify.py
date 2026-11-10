#!/usr/bin/env python3
"""E47 third-turn modular-sector exact GF and asymptotic certificate.
Requires Python >=3.10 and SymPy. All sequence comparisons use integers.
"""
from math import sqrt, pi
import json
import sympy as s

N=120
t,u,a,b=s.symbols("t u a b",real=True)
S=u**2+u+1+u**-1+u**-2
a2=((1-t)*a-1)/(2*t)-b
numerator=1+t*(b+a2+b*u-a/u-a/u**2-b/u)
F=numerator/(1-t*S)
z=(-1+s.I*s.sqrt(3))/2
expression=-a-2*(z*s.diff(F,u).subs(u,z)+s.conjugate(z)*s.diff(F,u).subs(u,s.conjugate(z))) \
           +s.I/s.sqrt(3)*(F.subs(u,z)-F.subs(u,s.conjugate(z)))
gf=(5*t-1)*((1+t)*a-2*t*b)/(1+t)**2
assert s.simplify(s.expand_complex(expression-gf))==0
assert s.factor((1+t)**2*gf-(5*t-1)*((1+t)*a-2*t*b))==0
M=(1-1/u)*F+a/u
T=M+2*u*s.diff(M,u)
third_turn_middle=(z**-1*T.subs(u,z)+z**-2*T.subs(u,z**2))
assert s.factor(s.simplify(s.expand_complex(third_turn_middle))+(7*t+1)/(1+t)**2)==0
middle_gf=s.factor((1/(1-5*t)-(7*t+1)/(1+t)**2)/3)
assert s.factor(middle_gf-12*t**2/((1+t)**2*(1-5*t)))==0

multiplicities={0:1}
weights={0:1}
A0,A1,D=[1],[0],[-1]
rows=[]
for n in range(1,N+1):
    next_m={}
    for J,count in multiplicities.items():
        for L in range(abs(J-2),J+3):
            next_m[L]=next_m.get(L,0)+count
    multiplicities=next_m
    next_w={}
    for k,count in weights.items():
        for step in range(-2,3):
            next_w[k+step]=next_w.get(k+step,0)+count
    weights=next_w
    A0.append(weights.get(0,0))
    A1.append(weights.get(1,0))
    d=[sum((2*J+1)*v for J,v in multiplicities.items() if J%3==r) for r in range(3)]
    assert sum(d)==5**n
    assert 3*d[1]==5**n+(-1)**n*(6*n-1)
    D.append(d[2]-d[0])
    rows.append(dict(n=n,d_plus=d[0],d_zero=d[1],d_minus=d[2],D=D[-1]))

for n in range(N+1):
    lhs=D[n]+(2*D[n-1] if n>=1 else 0)+(D[n-2] if n>=2 else 0)
    rhs=-A0[n]+(4*A0[n-1] if n>=1 else 0)+(5*A0[n-2] if n>=2 else 0)
    rhs+=(2*A1[n-1] if n>=1 else 0)-(10*A1[n-2] if n>=2 else 0)
    assert lhs==rhs,(n,lhs,rhs)

C=5/(72*sqrt(pi))
ratios={str(n):(D[n]/5**n)*n**1.5/(2*C) for n in [10,20,40,80,120]}
result=dict(checks={"modular_dimensions":N,"d_zero_closed_form":N,
                    "generating_function_coefficients":N+1,
                    "sympy_rational_identity":True, "middle_gf_symbolic":True},
            gf="D(t)=(5t-1)*((1+t)*A0(t)-2*t*A1(t))/(1+t)^2",
            middle_gf="12*t^2/((1+t)^2*(1-5*t))",
            singular_coefficient="-5/18 * sqrt(1-5t)",
            D_asymptotic_coefficient="5/(36*sqrt(pi))",
            d_minus_excess_coefficient="5/(72*sqrt(pi))",
            C_decimal=C,ratios=ratios,selected_rows=[r for r in rows if r["n"] in (3,4,5,6,10,20,40,80,120)])
out=__import__("pathlib").Path(__file__).parent
(out/"results.json").write_text(json.dumps(result,indent=2)+"\n")
print("PASS: symbolic rational GF identity")
print(f"PASS: {N} exact modular partitions, {N} d0 identities, {N+1} GF coefficients")
print("C =",C)
for n,ratio in ratios.items():print("n =",n,"ratio =",format(ratio,".12f"))
