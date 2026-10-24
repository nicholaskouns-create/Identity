import sympy as s
R=s.diag(-1,1); I=s.eye(2)
Pp=(I+R)/2; Pm=(I-R)/2
G=I-(I-R)/4
assert R**2==I
assert Pp**2==Pp and Pm**2==Pm
assert Pp*Pm==s.zeros(2) and Pp+Pm==I
assert G**40-Pp==s.diag(s.Rational(1,2)**40,0)
T=s.diag(3,7)
assert T*R==R*T
print("PASS: exact reflection, projectors, contraction, commutator")
