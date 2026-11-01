#!/usr/bin/env python3
"""Independent integer preflight for concrete 125-state [C,U] column six.
No eigenvalues, spectral multiplicities, or kernel dimensions are assumed.
"""
N = 125
def xyz(n):
    return (n // 25, (n // 5) % 5, n % 5)
def up(i, j):
    x, y = xyz(i), xyz(j)
    return sum(y[t] * (5-y[t]) for t in range(3)
               if y[t] == x[t]+1 and all(y[s] == x[s] for s in range(3) if s != t))
def down(i, j):
    x, y = xyz(i), xyz(j)
    return sum(1 for t in range(3)
               if x[t] == y[t]+1 and all(x[s] == y[s] for s in range(3) if s != t))
U = [[up(i, j) for j in range(N)] for i in range(N)]
D = [[down(i, j) for j in range(N)] for i in range(N)]
w = [6-sum(xyz(i)) for i in range(N)]
C = [[sum(D[i][k]*U[k][j] for k in range(N))
      + (w[i]*(w[i]+1) if i == j else 0)
      for j in range(N)] for i in range(N)]
j = 6
residual = [sum(C[i][k]*U[k][j]-U[i][k]*C[k][j] for k in range(N))
            for i in range(N)]
assert len(residual) == N
assert all(r == 0 for r in residual), residual
print("E47_CASIMIR_U_COLUMN6_EXACT_INTEGER_PASS rows=125 max_residual=0")
