"""Independent stdlib exact-integer top-weight Casimir census.

Constructs the actual 125-state spin-2 tensor generators, restricts the
Casimir to *all* weights >=5, computes the characteristic polynomial by a
Leibniz determinant, factors it only after computation, and tests a mutant.
No candidate eigenvalues are inputs to the computation.
"""
from itertools import permutations

N = 125

def abc(n): return n // 25, (n // 5) % 5, n % 5

def z(n): return 6 - sum(abc(n))

def up(i, j):
    a,b,c = abc(i); x,y,t = abc(j)
    return ((x*(5-x) if a+1==x and b==y and c==t else 0)
            +(y*(5-y) if a==x and b+1==y and c==t else 0)
            +(t*(5-t) if a==x and b==y and c+1==t else 0))

def down(i, j):
    a,b,c = abc(i); x,y,t = abc(j)
    return (int(a==x+1 and b==y and c==t)
            +int(a==x and b==y+1 and c==t)
            +int(a==x and b==y and c==t+1))

def C(i, j):
    return sum(down(i,k)*up(k,j) for k in range(N)) + (z(i)*(z(i)+1) if i==j else 0)

def mul(A, B):
    n = len(A)
    return [[sum(A[i][k]*B[k][j] for k in range(n)) for j in range(n)] for i in range(n)]

def add(A, B): return [[a+b for a,b in zip(ra,rb)] for ra,rb in zip(A,B)]

def scale(A, k): return [[k*x for x in row] for row in A]

def poly_add(a, b):
    out = [0]*max(len(a),len(b))
    for i,x in enumerate(a): out[i] += x
    for i,x in enumerate(b): out[i] += x
    return out

def poly_mul(a, b):
    out = [0]*(len(a)+len(b)-1)
    for i,x in enumerate(a):
        for j,y in enumerate(b): out[i+j] += x*y
    return out

def scale_poly(p,k): return [k*x for x in p]

def charpoly(A):
    n = len(A); p = [0]*(n+1)
    for perm in permutations(range(n)):
        inversions = sum(perm[i]>perm[j] for i in range(n) for j in range(i+1,n))
        q = [1]
        for i,j in enumerate(perm):
            q = poly_mul(q,[-A[i][j],1] if i==j else [-A[i][j]])
        p = poly_add(p,scale_poly(q,(-1)**inversions))
    return p

def divide_linear(p,root):
    q = [0]*(len(p)-1)
    q[-1] = p[-1]
    for i in range(len(q)-2,-1,-1): q[i] = p[i+1]+root*q[i+1]
    return q,p[0]+root*q[0]

def main():
    states = [i for i in range(N) if z(i)>=5]
    assert states == [0,1,5,25], states
    A = [[C(i,j) for j in states] for i in states]
    assert all(C(i,j)==0 for i in states for j in range(N) if j not in states), 'not invariant'
    print('E47_TOP_WEIGHT_STATES_EXACT_PASS',states)
    print('Concrete block',A)
    assert A == [[42,0,0,0],[0,34,4,4],[0,4,34,4],[0,4,4,34]]
    print('E47_TOP_WEIGHT_CONCRETE_BLOCK_PASS')
    p = charpoly(A)
    print('Concrete characteristic polynomial ascending',p)
    roots = []; q = p
    while len(q)>1:
        for root in range(-100,101):
            nxt,rem = divide_linear(q,root)
            if rem==0:
                roots.append(root); q=nxt; break
        else: raise AssertionError(('unfactored',q))
    assert q==[1] and sorted(roots)==[30,30,42,42],roots
    print('E47_TOP_WEIGHT_CHARPOLY_EXACT_PASS',roots)
    S = [[1,0,0,0],[0,1,1,1],[0,1,-1,0],[0,1,0,-1]]
    B = [[3,0,0,0],[0,1,1,1],[0,1,-2,1],[0,1,1,-2]]
    D = [[42,0,0,0],[0,42,0,0],[0,0,30,0],[0,0,0,30]]
    I = [[int(i==j) for j in range(4)] for i in range(4)]
    assert mul(A,S)==mul(S,D)
    assert mul(S,B)==scale(I,3)==mul(B,S)
    assert add(add(mul(A,A),scale(A,-72)),scale(I,1260))==scale(I,0)
    print('E47_TOP_WEIGHT_DIAGONALIZATION_PASS')
    mutant = [row[:] for row in A]; mutant[1][1]+=1
    assert charpoly(mutant)!=p
    assert add(add(mul(mutant,mutant),scale(mutant,-72)),scale(I,1260))!=scale(I,0)
    print('E47_TOP_WEIGHT_MUTANT_REJECTED')

if __name__=='__main__': main()
