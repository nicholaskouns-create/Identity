from fractions import Fraction as F
from math import log
assert F(47,125)==F(376,1000)
def gl(a,b,x): return a*x+b*x*x
for x in (F(376,1000),F(2,10)):
    a=-2*x
    assert gl(a,1,x)==-x*x
assert F(376,1000)!=F(2,10)
def entropy(p):
    return -sum(q*log(q) for q in (p,1-p) if q>0)
assert entropy(.5)>entropy(.376)
print("PASS: exact ratio, distinct GL minima, entropy comparison")
