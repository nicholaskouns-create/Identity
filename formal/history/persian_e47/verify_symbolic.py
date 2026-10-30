import sympy as s
x,a,c,w,r,e=s.symbols('x a c w r e', real=True)
f=lambda z:z**3-a*z**2+c
assert s.simplify(f(2*a/3)-(c-4*a**3/27))==0
assert s.simplify(f(x)-f(2*a/3)-(x-2*a/3)**2*(x+a/3))==0
step=lambda z:z+w*f(z)
err=(1-w*r*(2*a-3*r))*e+w*(3*r-a)*e**2+w*e**3
assert s.simplify((step(r+e)-r-err).subs(c,a*r**2-r**3))==0
assert s.simplify((step(r)-r).subs(c,a*r**2-r**3))==0
print('PASS 4/4 exact symbolic identities')
