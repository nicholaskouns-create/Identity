"""E47 independent cross-check: exact two-sided certificate for dim ker K = 47.

WHY THIS FILE EXISTS
--------------------
The repository already contains two checks of the E47 carrier:

  * ``simulation/validate_e47.py`` builds the Casimir with NumPy ``complex128``
    and counts the kernel by clustering floating-point eigenvalues with a
    ``1e-7`` tolerance.  The number 47 is therefore read off a numerical
    spectrum, not proved.
  * ``validation/e47_tensor_bracket_trace_exact.py`` checks the Lie brackets and
    two Casimir traces in exact ``int64`` arithmetic, in the *non-orthonormal
    integer weight basis*.  It never computes a rank or a kernel, so it does not
    establish 47 at all.

Re-running either script is reproduction, not validation: the same code on the
same input returns the same answer by construction.  This file is an
*independent* instrument.  It shares no code, no basis, no number field and no
library with either of the above:

  * stdlib only -- no NumPy, no SciPy, no SymPy, no repository imports;
  * the orthonormal (Condon--Shortley) basis, in which the Casimir is a
    *symmetric* matrix, rather than the integer weight basis in which it is not;
  * exact arithmetic in the ring Z[sqrt 6] and its fraction field Q(sqrt 6),
    rather than int64 or float64;
  * rank by fraction-free (Bareiss) elimination, which is a two-sided exact
    determination of the kernel dimension -- no tolerance, no eigenvalue
    clustering;
  * an entirely matrix-free second derivation of the same multiplicities from
    SU(2) character theory, so that 47 is produced twice by methods with no
    common step.

It also carries negative controls, so a reader can see the harness is capable of
reporting failure, and it states plainly which inputs are chosen rather than
derived.

Run:  python3 validation/e47_independent_crosscheck.py
Exit: 0 on full agreement, non-zero otherwise.
"""

from __future__ import annotations

import sys
from fractions import Fraction

# ---------------------------------------------------------------------------
# Inputs that are ASSERTED (everything else below is computed)
# ---------------------------------------------------------------------------
# 1. the coupling: three copies of the five-dimensional spin-2 representation
# 2. the annihilating polynomial p(x) = (x - 6)(x - 30), i.e. the choice of the
#    spin pair {2, 5}.  This choice is an input.  Section G quantifies it.
SPIN = 2
SITES = 3
ANNIHILATED_CASIMIR_VALUES = (6, 30)

FAILURES: list[str] = []


def check(ok: bool, label: str, detail: str = "") -> None:
    tag = "PASS" if ok else "FAIL"
    line = f"{tag} {label}"
    if detail:
        line += f"  --  {detail}"
    print(line)
    if not ok:
        FAILURES.append(label)


def section(title: str) -> None:
    print()
    print(title)
    print("-" * len(title))


# ===========================================================================
# Exact arithmetic in Q(sqrt 6).  An element is a + b*sqrt(6).
# 6 is not a square in Q, so this is a genuine quadratic field and the pair
# representation is faithful.  Entries of the orthonormal Casimir land here;
# entries of the repository's weight-basis Casimir land in Z.  The two matrices
# are different objects with, necessarily, the same rank.
# ===========================================================================
RADICAND = 6


class Q6:
    """a + b*sqrt(6) with exact rational (or integer) components."""

    __slots__ = ("a", "b")

    def __init__(self, a=0, b=0):
        self.a = a
        self.b = b

    def __add__(self, o):
        return Q6(self.a + o.a, self.b + o.b)

    def __sub__(self, o):
        return Q6(self.a - o.a, self.b - o.b)

    def __neg__(self):
        return Q6(-self.a, -self.b)

    def __mul__(self, o):
        return Q6(self.a * o.a + RADICAND * self.b * o.b, self.a * o.b + self.b * o.a)

    def __eq__(self, o):
        return self.a == o.a and self.b == o.b

    def __hash__(self):
        return hash((self.a, self.b))

    def is_zero(self) -> bool:
        return self.a == 0 and self.b == 0

    def exact_div(self, o: "Q6") -> "Q6":
        """Division that must come out exactly in the same component type."""
        norm = o.a * o.a - RADICAND * o.b * o.b
        if norm == 0:
            raise ZeroDivisionError("division by zero in Q(sqrt 6)")
        num_a = self.a * o.a - RADICAND * self.b * o.b
        num_b = self.b * o.a - self.a * o.b
        if isinstance(num_a, int) and isinstance(norm, int):
            if num_a % norm or num_b % norm:
                raise ArithmeticError("inexact division in Z[sqrt 6]")
            return Q6(num_a // norm, num_b // norm)
        return Q6(Fraction(num_a, norm), Fraction(num_b, norm))

    def __repr__(self):
        return f"({self.a}+{self.b}v6)"


ZERO = Q6(0, 0)


def zi(n: int) -> Q6:
    return Q6(n, 0)


# ===========================================================================
# Sparse matrices over Q(sqrt 6): list of dicts, one dict per row.
# ===========================================================================
Sparse = list


def sp_zero(n: int) -> Sparse:
    return [dict() for _ in range(n)]


def sp_set(M: Sparse, i: int, j: int, v: Q6) -> None:
    if v.is_zero():
        M[i].pop(j, None)
    else:
        M[i][j] = v


def sp_add(A: Sparse, B: Sparse) -> Sparse:
    out = [dict(r) for r in A]
    for i, row in enumerate(B):
        for j, v in row.items():
            s = out[i].get(j, ZERO) + v
            if s.is_zero():
                out[i].pop(j, None)
            else:
                out[i][j] = s
    return out


def sp_scale(A: Sparse, c: Q6) -> Sparse:
    return [{j: v * c for j, v in row.items() if not (v * c).is_zero()} for row in A]


def sp_mul(A: Sparse, B: Sparse) -> Sparse:
    out = [dict() for _ in A]
    for i, arow in enumerate(A):
        orow = out[i]
        for k, aik in arow.items():
            for j, bkj in B[k].items():
                p = aik * bkj
                cur = orow.get(j)
                orow[j] = p if cur is None else cur + p
        for j in [j for j, v in orow.items() if v.is_zero()]:
            del orow[j]
    return out


def sp_eye(n: int) -> Sparse:
    return [{i: zi(1)} for i in range(n)]


def sp_transpose(A: Sparse, n: int) -> Sparse:
    out = [dict() for _ in range(n)]
    for i, row in enumerate(A):
        for j, v in row.items():
            out[j][i] = v
    return out


def sp_trace(A: Sparse) -> Q6:
    t = ZERO
    for i, row in enumerate(A):
        t = t + row.get(i, ZERO)
    return t


def sp_equal(A: Sparse, B: Sparse) -> bool:
    for ra, rb in zip(A, B):
        if {j: v for j, v in ra.items() if not v.is_zero()} != {
            j: v for j, v in rb.items() if not v.is_zero()
        }:
            return False
    return True


def sp_commutator(A: Sparse, B: Sparse) -> Sparse:
    return sp_add(sp_mul(A, B), sp_scale(sp_mul(B, A), zi(-1)))


def sp_nnz(A: Sparse) -> int:
    return sum(len(r) for r in A)


# ===========================================================================
# A.  Matrix-free derivation of the multiplicities from SU(2) character theory
#     Laurent polynomials in x, where chi_j = x^{2j} + x^{2j-2} + ... + x^{-2j}.
#     Pure integer arithmetic.  No matrix of any size is built in this section.
# ===========================================================================
def character(two_j: int) -> dict[int, int]:
    return {two_j - 2 * k: 1 for k in range(two_j + 1)}


def poly_mul(p: dict[int, int], q: dict[int, int]) -> dict[int, int]:
    out: dict[int, int] = {}
    for e1, c1 in p.items():
        for e2, c2 in q.items():
            out[e1 + e2] = out.get(e1 + e2, 0) + c1 * c2
    return {e: c for e, c in out.items() if c}


def decompose_character(p: dict[int, int]) -> dict[int, int]:
    """Peel a character into irreducibles.  Exact, terminating, integer-only."""
    rem = dict(p)
    mult: dict[int, int] = {}
    while rem:
        top = max(rem)
        m = rem[top]
        if m < 0:
            raise ArithmeticError("not a genuine character")
        mult[top] = m
        chi = character(top)
        for e, c in chi.items():
            rem[e] = rem.get(e, 0) - m * c
            if rem[e] == 0:
                del rem[e]
    return mult


# ===========================================================================
# B.  Orthonormal spin-2 operators and the total Casimir, exactly.
#     |j, m> with m = SPIN - index.  J+|j,m> = sqrt(j(j+1) - m(m+1)) |j,m+1>.
#     For j = 2 the radicands are 4, 6, 6, 4 -- hence Z[sqrt 6].
# ===========================================================================
def isqrt_exact(n: int) -> Q6 | None:
    r = int(n**0.5)
    while r * r < n:
        r += 1
    while r * r > n:
        r -= 1
    if r * r == n:
        return zi(r)
    if n % RADICAND == 0:
        q = n // RADICAND
        s = int(q**0.5)
        while s * s < q:
            s += 1
        while s * s > q:
            s -= 1
        if s * s == q:
            return Q6(0, s)
    return None


def single_site_operators(j: int):
    d = 2 * j + 1
    ms = [j - i for i in range(d)]
    jz = sp_zero(d)
    for i, m in enumerate(ms):
        sp_set(jz, i, i, zi(m))
    jp = sp_zero(d)
    for i, m in enumerate(ms):
        if i == 0:
            continue
        val = isqrt_exact(j * (j + 1) - m * (m + 1))
        if val is None:
            raise ArithmeticError(f"radicand {j*(j+1)-m*(m+1)} not in Z[sqrt {RADICAND}]")
        sp_set(jp, i - 1, i, val)
    jm = sp_transpose(jp, d)
    return jz, jp, jm, d


def kron3(op: Sparse, slot: int, d: int) -> Sparse:
    """Embed a single-site operator into slot `slot` of a 3-fold tensor power."""
    n = d**3
    out = sp_zero(n)
    for i in range(n):
        idx = [i // (d * d), (i // d) % d, i % d]
        a = idx[slot]
        for b, v in op[a].items():
            jdx = list(idx)
            jdx[slot] = b
            jj = jdx[0] * d * d + jdx[1] * d + jdx[2]
            cur = out[i].get(jj, ZERO) + v
            sp_set(out, i, jj, cur)
    return out


def total(op: Sparse, d: int) -> Sparse:
    acc = kron3(op, 0, d)
    for s in (1, 2):
        acc = sp_add(acc, kron3(op, s, d))
    return acc


# ===========================================================================
# C.  Exact rank by fraction-free (Bareiss) elimination over Z[sqrt 6].
#     Two-sided: the rank returned is the rank, not an estimate.
# ===========================================================================
def dense_from_sparse(A: Sparse, n: int) -> list[list[Q6]]:
    return [[A[i].get(j, ZERO) for j in range(n)] for i in range(n)]


def bareiss_rank(M: list[list[Q6]]) -> int:
    M = [row[:] for row in M]
    nrows = len(M)
    ncols = len(M[0]) if nrows else 0
    prev = zi(1)
    r = 0
    for c in range(ncols):
        piv = None
        for p in range(r, nrows):
            if not M[p][c].is_zero():
                piv = p
                break
        if piv is None:
            continue
        if piv != r:
            M[r], M[piv] = M[piv], M[r]
        prc = M[r][c]
        for i in range(r + 1, nrows):
            mic = M[i][c]
            if mic.is_zero():
                row_i, row_r = M[i], M[r]
                for j in range(c + 1, ncols):
                    row_i[j] = (prc * row_i[j]).exact_div(prev)
            else:
                row_i, row_r = M[i], M[r]
                for j in range(c + 1, ncols):
                    row_i[j] = (prc * row_i[j] - mic * row_r[j]).exact_div(prev)
            row_i[c] = ZERO
        prev = prc
        r += 1
        if r == nrows:
            break
    return r


# ===========================================================================
# MAIN
# ===========================================================================
def main() -> int:
    print("E47 INDEPENDENT CROSS-CHECK")
    print("=" * 76)
    print(f"asserted inputs only: coupling = spin {SPIN} to the {SITES}rd tensor power,")
    print(f"                      annihilating polynomial roots = {ANNIHILATED_CASIMIR_VALUES}")
    print("everything printed below this line is computed, in exact arithmetic")
    print("=" * 76)

    # ---------------------------------------------------------------- A -----
    section("A. Multiplicities from SU(2) characters (matrix-free, integers only)")
    chi = character(2 * SPIN)
    cube = chi
    for _ in range(SITES - 1):
        cube = poly_mul(cube, chi)
    mult_by_twoj = decompose_character(cube)
    mult = {tj // 2: m for tj, m in sorted(mult_by_twoj.items())}
    mult_vec = [mult.get(j, 0) for j in range(0, max(mult) + 1)]
    dims = {j: m * (2 * j + 1) for j, m in mult.items()}
    carrier = sum(dims.values())

    print(f"   spin j        : {sorted(mult)}")
    print(f"   multiplicity  : {mult_vec}")
    print(f"   block dim     : {[dims[j] for j in sorted(dims)]}")
    check(mult_vec == [1, 3, 5, 4, 3, 2, 1], "character multiplicities = 1,3,5,4,3,2,1")
    check(carrier == (2 * SPIN + 1) ** SITES == 125, "carrier dimension = 125", f"{carrier}")

    casimir_of = {j: j * (j + 1) for j in mult}
    print(f"   Casimir j(j+1): {[casimir_of[j] for j in sorted(casimir_of)]}")
    check(
        sorted(casimir_of.values()) == [0, 2, 6, 12, 20, 30, 42],
        "Casimir eigenvalue set = {0,2,6,12,20,30,42}",
    )

    annihilated = [j for j in mult if casimir_of[j] in ANNIHILATED_CASIMIR_VALUES]
    predicted_nullity = sum(dims[j] for j in annihilated)
    predicted_rank = carrier - predicted_nullity
    print(
        f"   annihilated spins {sorted(annihilated)} -> "
        f"{' + '.join(str(dims[j]) for j in sorted(annihilated))} = {predicted_nullity}"
    )
    check(predicted_nullity == 47, "character route predicts dim ker K = 47")
    check(predicted_rank == 78, "character route predicts rank K = 78")

    # ---------------------------------------------------------------- B -----
    section("B. Orthonormal Casimir over Z[sqrt 6] (a different matrix, exactly)")
    jz1, jp1, jm1, d = single_site_operators(SPIN)
    Jz, Jp, Jm = total(jz1, d), total(jp1, d), total(jm1, d)
    N = d**SITES

    half = Q6(Fraction(1, 2), 0)
    C = sp_add(sp_mul(Jz, Jz), sp_scale(sp_add(sp_mul(Jp, Jm), sp_mul(Jm, Jp)), half))
    print(f"   N = {N}, nonzeros in C = {sp_nnz(C)} ({100*sp_nnz(C)/N/N:.1f}% dense)")

    check(sp_equal(C, sp_transpose(C, N)), "C is exactly symmetric in this basis")
    irrational = sum(1 for row in C for v in row.values() if v.b != 0)
    check(
        irrational > 0,
        "C genuinely leaves Z: entries carry sqrt 6",
        f"{irrational} entries of the form a+b*sqrt(6), b != 0",
    )
    for nm, op in (("Jz", Jz), ("J+", Jp), ("J-", Jm)):
        check(sp_nnz(sp_commutator(C, op)) == 0, f"[C,{nm}] = 0 exactly (every entry)")

    Jx = sp_scale(sp_add(Jp, Jm), half)
    check(sp_nnz(sp_commutator(C, Jx)) == 0, "[C,Jx] = 0 exactly (every entry)")
    check(
        sp_nnz(sp_commutator(Jz, Jp)) and sp_equal(sp_commutator(Jz, Jp), Jp),
        "[Jz,J+] = J+ exactly",
    )
    check(sp_equal(sp_commutator(Jz, Jm), sp_scale(Jm, zi(-1))), "[Jz,J-] = -J- exactly")
    check(sp_equal(sp_commutator(Jp, Jm), sp_scale(Jz, zi(2))), "[J+,J-] = 2Jz exactly")

    # ---------------------------------------------------------------- C -----
    section("C. Traces: matrix value vs character prediction (two routes, one number)")
    C2 = sp_mul(C, C)
    C3 = sp_mul(C2, C)
    C4 = sp_mul(C2, C2)
    for power, mat in ((1, C), (2, C2), (3, C3), (4, C4)):
        measured = sp_trace(mat)
        predicted = sum(dims[j] * casimir_of[j] ** power for j in mult)
        ok = measured.b == 0 and measured.a == predicted
        check(
            ok,
            f"tr(C^{power}) = {predicted}",
            f"matrix gives {measured.a}, characters give {predicted}",
        )
    print("   (tr C = 2250 and tr C^2 = 58500 are the two numbers the existing")
    print("    weight-basis certificate reports; both are reproduced here from a")
    print("    different matrix in a different ring, and independently from")
    print("    characters with no matrix at all.)")

    # ---------------------------------------------------------------- D -----
    section("D. Exact rank of K = (C-6)(C-30): two-sided, no tolerance")
    r1, r2 = ANNIHILATED_CASIMIR_VALUES
    I = sp_eye(N)
    K = sp_mul(sp_add(C, sp_scale(I, zi(-r1))), sp_add(C, sp_scale(I, zi(-r2))))
    print(f"   nonzeros in K = {sp_nnz(K)} ({100*sp_nnz(K)/N/N:.1f}% dense)")

    # clear the single factor of 1/2 so Bareiss runs in the integral domain Z[sqrt 6]
    K4 = sp_scale(K, zi(4))
    integral = all(
        isinstance(v.a, int) or v.a.denominator == 1 for row in K4 for v in row.values()
    )
    K4 = [
        {
            j: Q6(int(v.a), int(v.b))
            for j, v in row.items()
        }
        for row in K4
    ]
    check(integral, "4K has entries in Z[sqrt 6] (Bareiss domain is integral)")

    rank_K = bareiss_rank(dense_from_sparse(K4, N))
    nullity_K = N - rank_K
    print(f"   rank(4K) by fraction-free elimination = {rank_K}")
    print(f"   nullity = {N} - {rank_K} = {nullity_K}")
    check(rank_K == 78, "exact rank K = 78")
    check(nullity_K == 47, "exact dim ker K = 47")
    check(rank_K + nullity_K == N == 125, "rank + nullity = 125")
    check(
        nullity_K == predicted_nullity and rank_K == predicted_rank,
        "exact elimination agrees with the matrix-free character prediction",
    )

    # densified conjugate: rank is a similarity invariant, so a unimodular
    # change of basis must not move it, and it stops the elimination from
    # benefiting from any sparsity pattern of the original.
    section("E. Same rank after unimodular densification (sparsity is not the reason)")
    U = [[zi(1) if i == j else ZERO for j in range(N)] for i in range(N)]
    for i in range(N - 1):
        for j in range(i + 1, min(i + 4, N)):
            U[i][j] = zi(1 + ((i * 7 + j * 3) % 3))
    Uinv_applied = dense_from_sparse(K4, N)
    # form U * K4 * U^{-1} implicitly: conjugation by a unit upper-triangular
    # integer matrix, done as row ops then the inverse column ops.
    for i in range(N - 2, -1, -1):
        for j in range(i + 1, min(i + 4, N)):
            c = U[i][j]
            if c.is_zero():
                continue
            for k in range(N):  # row_i += c * row_j
                Uinv_applied[i][k] = Uinv_applied[i][k] + c * Uinv_applied[j][k]
    for i in range(N - 2, -1, -1):
        for j in range(i + 1, min(i + 4, N)):
            c = U[i][j]
            if c.is_zero():
                continue
            for k in range(N):  # col_j -= c * col_i
                Uinv_applied[k][j] = Uinv_applied[k][j] - c * Uinv_applied[k][i]
    density = sum(1 for row in Uinv_applied for v in row if not v.is_zero()) / (N * N)
    rank_conj = bareiss_rank(Uinv_applied)
    print(f"   conjugated matrix density = {100*density:.1f}% nonzero")
    print(f"   rank of conjugate = {rank_conj}")
    check(rank_conj == rank_K == 78, "rank invariant under unimodular conjugation")

    # ---------------------------------------------------------------- F -----
    section("F. Contraction constants derived, not checked against a float")
    spec = sorted(casimir_of.values())
    kept = [v for v in spec if v not in ANNIHILATED_CASIMIR_VALUES]
    ksq = sorted(((v - r1) * (v - r2)) ** 2 for v in kept)
    s_min, s_max = ksq[0], ksq[-1]
    eps_star = Fraction(2, s_min + s_max)
    rho = Fraction(s_max - s_min, s_max + s_min)
    print(f"   K^2 eigenvalues off the kernel : {ksq}")
    print(f"   Chebyshev optimum eps* = 2/(min+max) = {eps_star}")
    print(f"   contraction rho = (max-min)/(max+min) = {rho}")
    check(eps_star == Fraction(1, 99144), "eps* = 1/99144 derived exactly")
    check(rho == Fraction(15, 17), "rho = 15/17 derived exactly")
    worst = max(abs(1 - eps_star * s) for s in ksq)
    check(worst == rho, "max |1 - eps* K^2| over the retained spectrum equals rho")
    print("   (the existing NumPy script compares these to float64 matrix powers;")
    print("    here they are the exact solution of the minimax problem.)")

    # ---------------------------------------------------------------- G -----
    section("G. Negative controls: the harness can fail")
    bad = sp_mul(sp_add(C, sp_scale(I, zi(-6))), sp_add(C, sp_scale(I, zi(-29))))
    bad4 = [
        {j: Q6(int(v.a * 4), int(v.b * 4)) for j, v in row.items()}
        for row in sp_scale(bad, zi(1))
    ]
    rank_bad = bareiss_rank(dense_from_sparse(bad4, N))
    print(f"   (C-6)(C-29): 29 is not an eigenvalue -> nullity {N - rank_bad}")
    check(N - rank_bad == 25, "perturbing a root to 29 collapses the kernel to 25, not 47")

    corrupt = [dict(r) for r in C]
    corrupt[0][1] = corrupt[0].get(1, ZERO) + zi(1)
    check(
        not sp_equal(corrupt, sp_transpose(corrupt, N)),
        "a single corrupted entry is detected by the symmetry test",
    )
    check(
        sp_nnz(sp_commutator(corrupt, Jz)) != 0,
        "a single corrupted entry is detected by the commutator test",
    )
    known = decompose_character(poly_mul(character(2), character(2)))
    check(
        known == {4: 1, 2: 1, 0: 1},
        "character peeler reproduces the textbook 1 (x) 1 = 0 + 1 + 2",
    )
    try:
        decompose_character({4: 1, 0: -3})
        bogus_rejected = False
    except ArithmeticError:
        bogus_rejected = True
    check(bogus_rejected, "character peeler rejects a non-character")

    # ---------------------------------------------------------------- H -----
    section("H. Scope: what is derived and what is chosen")
    js = sorted(mult)
    pairs = []
    for a_i in range(len(js)):
        for b_i in range(a_i + 1, len(js)):
            ja, jb = js[a_i], js[b_i]
            pairs.append((ja, jb, dims[ja] + dims[jb]))
    kdims = sorted(p[2] for p in pairs)
    print(f"   all {len(pairs)} admissible spin pairs give kernel dimensions:")
    print(f"   {kdims}")
    hit = [f"({a},{b})" for a, b, k in pairs if k == 47]
    print(f"   47 is attained by: {', '.join(hit)}")
    check(len(pairs) == 21, "21 admissible pairs")
    check(min(kdims) == 10 and max(kdims) == 55, "kernel dimensions span 10..55")
    check(hit == ["(2,5)"], "47 is attained by exactly one pair, (2,5)")
    print()
    print("   DERIVED  : 125, the multiplicities 1,3,5,4,3,2,1, the spectrum,")
    print("              rank 78, dim ker 47, eps* = 1/99144, rho = 15/17.")
    print("   CHOSEN   : the spin pair {2,5}.  It is an input to p(x), not an")
    print("              output of it.  Given the choice, 47 follows exactly;")
    print("              the choice itself is not derived here or elsewhere in")
    print("              this repository.")

    # ---------------------------------------------------------------- end ---
    print()
    print("=" * 76)
    if FAILURES:
        print(f"RESULT: {len(FAILURES)} FAILED -> {FAILURES}")
        return 1
    print("RESULT: all checks passed.")
    print("dim ker K = 47 is established twice -- once with no matrix at all")
    print("(characters) and once by exact two-sided elimination over Z[sqrt 6]")
    print("in a basis where the Casimir is symmetric.  Neither route shares a")
    print("line of code, a library, a basis or a number field with the existing")
    print("NumPy and int64 certificates, and the two existing trace values are")
    print("reproduced as a by-product.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
