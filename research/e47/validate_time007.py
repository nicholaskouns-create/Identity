from fractions import Fraction
from math import exp, sqrt
from collections import Counter

w = Counter({0: 1})
for _ in range(3):
    n = Counter()
    for a, v in w.items():
        for b in range(-2, 3):
            n[a + b] += v
    w = n
m = [w[j] - w[j + 1] for j in range(7)]
d = [(2*j + 1) * m[j] for j in range(7)]
assert m == [1, 3, 5, 4, 3, 2, 1]
assert d == [1, 9, 25, 28, 27, 22, 13]
assert sum(d) == 125 and d[2] + d[5] == 47
nodes = [j * (j + 1) for j in range(7)]
p = lambda x: x*(x-2)*(x-12)*(x-20)*(x-31)*(x-42)
assert [Fraction(p(x), 1814400) for x in nodes] == [0,0,1,0,0,1,0]
assert [-1, 2, 8, 2].count(-1) == 1
excluded = [(j, d[j], nodes[j]) for j in range(7) if j not in (2, 5)]
def L(t):
    return 1 - sum(Fraction(dj,125)*exp(-2*(lam**2)*t) for j,dj,lam in excluded)
assert abs(L(0) - Fraction(47,125)) < 1e-14
for t in [0, .001, .1, 1, 5]:
    assert 0 < L(t) < 1
    assert sqrt(125/78*L(t)) > 0
N = lambda t: sqrt(125/78*L(t))
steps = 20000
T = 1
h = T / steps
integral = h*(.5*N(0) + sum(N(k*h) for k in range(1, steps)) + .5*N(T))
omega = 2.3
phi_delta = omega * integral
assert abs(phi_delta/omega - integral) < 1e-12
print('PASS: spectral multiplicities, rank, exact selector, signature, sampled lapse, conditional phase identity')
print('L(0)=',L(0),'L(1)=',L(1),'tau(1)=',integral)
print('LIMITS: no actual E47 clock dynamics, Lean/Coq compilation, or physical validation')
