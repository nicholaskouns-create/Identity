"""Independent stdlib integer audit of canonical 125-state weight-4 block.

The 125-dimensional generator entries are reconstructed independently of
Lean/Coq. Roots are not used to build C or its characteristic polynomial.
"""
from itertools import permutations

N = 125

def abc(n):
    return n // 25, (n // 5) % 5, n % 5

def z(n):
    return 6 - sum(abc(n))

def up(i, j):
    a, b, c = abc(i)
    x, y, t = abc(j)
    return ((x * (5 - x) if a + 1 == x and b == y and c == t else 0)
            + (y * (5 - y) if a == x and b + 1 == y and c == t else 0)
            + (t * (5 - t) if a == x and b == y and c + 1 == t else 0))

def down(i, j):
    a, b, c = abc(i)
    x, y, t = abc(j)
    return (int(a == x + 1 and b == y and c == t)
            + int(a == x and b == y + 1 and c == t)
            + int(a == x and b == y and c == t + 1))

def casimir(i, j):
    return sum(down(i, k) * up(k, j) for k in range(N)) + (
        z(i) * (z(i) + 1) if i == j else 0)

def mul(A, B):
    n = len(A)
    return [[sum(A[i][k] * B[k][j] for k in range(n))
             for j in range(n)] for i in range(n)]

def poly_add(a, b):
    p = [0] * max(len(a), len(b))
    for i, v in enumerate(a): p[i] += v
    for i, v in enumerate(b): p[i] += v
    return p

def poly_mul(a, b):
    p = [0] * (len(a) + len(b) - 1)
    for i, x in enumerate(a):
        for j, y in enumerate(b): p[i+j] += x*y
    return p

def charpoly(A):
    n = len(A)
    p = [0] * (n + 1)
    for perm in permutations(range(n)):
        parity = sum(perm[i] > perm[j] for i in range(n) for j in range(i+1, n))
        term = [1]
        for i, j in enumerate(perm):
            term = poly_mul(term, [-A[i][j], 1] if i == j else [-A[i][j]])
        p = poly_add(p, [(-1)**parity * v for v in term])
    return p

def divide_linear(p, root):
    q = [0] * (len(p) - 1)
    q[-1] = p[-1]
    for i in range(len(q)-2, -1, -1):
        q[i] = p[i+1] + root*q[i+1]
    return q, p[0] + root*q[0]

def main():
    states = [i for i in range(N) if z(i) == 4]
    assert states == [2, 6, 10, 26, 30, 50]
    A = [[casimir(i, j) for j in states] for i in states]
    assert all(casimir(i, j) == 0 for i in states for j in range(N) if j not in states)
    assert all(casimir(j, i) == 0 for i in states for j in range(N) if j not in states)
    print('E47_WEIGHT4_BIDIRECTIONAL_INVARIANCE_PASS', states)
    assert A == [[26,4,0,4,0,0],[6,28,6,4,4,0],[0,4,26,0,4,0],
                 [6,4,0,28,4,6],[0,4,6,4,28,6],[0,0,0,4,4,26]]
    print('E47_WEIGHT4_CONCRETE_ENTRIES_PASS')
    p = charpoly(A)
    print('E47_WEIGHT4_CHARPOLY_COEFFICIENTS', p)
    roots = []
    q = p
    while len(q) > 1:
        for root in range(-100, 101):
            nxt, rem = divide_linear(q, root)
            if rem == 0:
                roots.append(root)
                q = nxt
                break
        else:
            raise AssertionError(('unfactored', q))
    assert q == [1] and sorted(roots) == [20,20,20,30,30,42]
    print('E47_WEIGHT4_CHARPOLY_EXACT_PASS', sorted(roots))
    S = [[2,4,2,-1,0,1],[-3,-3,0,0,-1,2],[2,0,0,1,-1,1],
         [0,-3,-3,-1,1,2],[0,3,0,1,0,2],[0,0,2,0,1,1]]
    B = [[45,-105,210,60,-105,45],[60,-30,-105,-30,135,-105],
         [45,60,45,-105,-105,210],[-330,-110,165,-110,220,165],
         [-165,-220,-165,110,110,330],[75,100,75,100,100,75]]
    D = [[(20 if i < 3 else 30 if i < 5 else 42) if i == j else 0
          for j in range(6)] for i in range(6)]
    I = [[int(i == j) for j in range(6)] for i in range(6)]
    assert mul(A, S) == mul(S, D)
    assert mul(S, B) == mul(B, S) == [[825 * x for x in row] for row in I]
    A2, A3 = mul(A, A), mul(mul(A, A), A)
    assert all(A3[i][j] - 92*A2[i][j] + 2700*A[i][j] - 25200*I[i][j] == 0
               for i in range(6) for j in range(6))
    print('E47_WEIGHT4_DIAGONALIZATION_PASS')
    mutant = [row[:] for row in A]
    mutant[1][1] += 1
    assert charpoly(mutant) != p
    print('E47_WEIGHT4_MUTANT_REJECTED')

if __name__ == '__main__':
    main()
