"""E47 core: exact-arithmetic constants for the spin-2 x spin-2 x spin-2 carrier.

Pure Python 3 standard library. Every constant is computed from the same
definitions (same names) as formal/e47/E47WeightAlgebra.{lean,v}; known facts
are asserted separately in verify(), never used to produce the value.
"""
from fractions import Fraction
from itertools import product
import hashlib
import json

SCHEMA = "e47-core-constants/1"

# ---- definitions mirrored from E47WeightAlgebra.{lean,v} -------------------
vals = [-2, -1, 0, 1, 2]
triples = [(a, b, c) for a, b, c in product(vals, repeat=3)]  # the 125 basis states


def w(m):
    """Number of basis triples with total Jz = m."""
    return sum(1 for t in triples if t[0] + t[1] + t[2] == m)


def mult(j):
    """Number of spin-j summands = w(j) - w(j+1)."""
    return w(j) - w(j + 1)


def casimir(j):
    return j * (j + 1)


def lam(c):
    """K = (C-6)(C-30) as a scalar on a block with Casimir value c."""
    return (c - 6) * (c - 30)


def pr(x):
    return x * (x - 2) * (x - 12) * (x - 20) * (x - 31) * (x - 42)


def pr_coefficients():
    """Exact coefficients of pr (highest power first), by integer polynomial product."""
    co = [1]
    for r in (0, 2, 12, 20, 31, 42):
        co = [a - r * b for a, b in zip(co + [0], [0] + co)]
    return co


# ---- derived constants -----------------------------------------------------
top_spin = max(m for m in range(0, 20) if w(m) != 0)
spins = list(range(top_spin + 1))
casimir_spectrum = [casimir(j) for j in spins]
multiplicities = [mult(j) for j in spins]
eigenspace_dims = [mult(j) * (2 * j + 1) for j in spins]
kernel_spins = [j for j in spins if lam(casimir(j)) == 0]
kernel_rank = sum(mult(j) * (2 * j + 1) for j in kernel_spins)
off_kernel_nodes = [casimir(j) for j in spins if j not in kernel_spins]
k_squared = sorted({lam(c) ** 2 for c in off_kernel_nodes})  # K^2 eigenvalues off the kernel
K2_MIN, K2_MAX = k_squared[0], k_squared[-1]
DENOMINATOR = Fraction(K2_MIN + K2_MAX, 2)      # optimal step 1/DENOMINATOR = 2/(rho_min+rho_max)
assert DENOMINATOR.denominator == 1
DENOMINATOR = int(DENOMINATOR)
epsilon = Fraction(1, DENOMINATOR)
rho = Fraction(K2_MAX - K2_MIN, K2_MAX + K2_MIN)


def gap(c):
    """|DENOMINATOR - lam(c)^2|, the numerator of Gamma = I - K^2/DENOMINATOR on a block."""
    return abs(DENOMINATOR - lam(c) ** 2)


def gamma(c):
    return 1 - epsilon * lam(c) ** 2


Omega_c = Fraction(kernel_rank, len(triples))
pr_normalizer = pr(6)


def fib_luc(n):
    f, l, fp, lp = 0, 2, 1, 1  # (F_k, L_k, F_{k+1}, L_{k+1}) at k=0
    for _ in range(n):
        f, l, fp, lp = fp, lp, f + fp, l + lp
    return f, l


F5, L5 = fib_luc(5)
F3, L3 = fib_luc(3)
tower = {"F5": F5, "L5": L5, "F3": F3, "j": (F5 - 1) // 2, "J": (L5 - 1) // 2,
         "D": F5 * F5 + F3 * L5}


def constants():
    """The canonical constants block (JSON-safe: ints, strings, lists)."""
    f = lambda q: "%d/%d" % (q.numerator, q.denominator)
    return {
        "schema": SCHEMA,
        "basis_size": len(triples),
        "weight_counts": [w(m) for m in range(top_spin + 1)],
        "multiplicities": multiplicities,
        "casimir_spectrum": casimir_spectrum,
        "casimir_eigenspace_dims": eigenspace_dims,
        "kernel_spins": kernel_spins,
        "kernel_rank": kernel_rank,
        "Omega_c": f(Omega_c),
        "Omega_c_decimal": "%.3f" % float(Omega_c),
        "lam_by_node": [lam(c) for c in casimir_spectrum],
        "k_squared_off_kernel": k_squared,
        "denominator": DENOMINATOR,
        "epsilon": f(epsilon),
        "rho": f(rho),
        "gamma_by_node": [f(gamma(c)) for c in casimir_spectrum],
        "pr_coefficients": pr_coefficients(),
        "pr_normalizer": pr_normalizer,
        "tower": tower,
    }


def canonical_bytes(block=None):
    """Canonical serialization: json.dumps(block, sort_keys=True, separators=(',', ':'),
    ensure_ascii=True) encoded as UTF-8."""
    block = constants() if block is None else block
    return json.dumps(block, sort_keys=True, separators=(",", ":"), ensure_ascii=True).encode("utf-8")


def constants_sha256(block=None):
    return hashlib.sha256(canonical_bytes(block)).hexdigest()


def verify():
    """Assert the known facts against the derived values; returns {name: bool}."""
    c = constants()
    nodes = casimir_spectrum
    return {
        "basis_size_125": len(triples) == 125 and len(set(triples)) == 125,
        "weight_counts": c["weight_counts"] == [19, 18, 15, 10, 6, 3, 1],
        "weight_symmetric": all(w(-m) == w(m) for m in range(-8, 9)),
        "weight_total_125": sum(w(m) for m in range(-6, 7)) == 125,
        "weight_vanishes_outside": w(7) == 0 and w(-7) == 0,
        "multiplicities": multiplicities == [1, 3, 5, 4, 3, 2, 1],
        "dimension_identity": sum(eigenspace_dims) == 125,
        "multiplicities_reproduce_weights": all(
            w(m) == sum(mult(j) for j in spins if j >= abs(m)) for m in range(-6, 7)),
        "casimir_spectrum": casimir_spectrum == [0, 2, 6, 12, 20, 30, 42],
        "eigenspace_dims": eigenspace_dims == [1, 9, 25, 28, 27, 22, 13],
        "lam_zero_iff_spin_2_or_5": all((lam(casimir(j)) == 0) == (j in (2, 5)) for j in range(0, 500)),
        "kernel_spins": kernel_spins == [2, 5],
        "kernel_rank_47": kernel_rank == 47,
        "kernel_rank_from_weights": (w(2) - w(3)) * 5 + (w(5) - w(6)) * 11 == 47,
        "Omega_c": Omega_c == Fraction(47, 125) and c["Omega_c_decimal"] == "0.376",
        "k_squared_set": k_squared == [11664, 12544, 19600, 32400, 186624],
        "k_squared_by_node": {casimir(j): lam(casimir(j)) ** 2 for j in spins if j not in kernel_spins}
        == {0: 32400, 2: 12544, 12: 11664, 20: 19600, 42: 186624},
        "denominator_99144": DENOMINATOR == 99144,
        "denominator_from_top_spin": lam(casimir(top_spin)) ** 2 * 17 == 99144 * 32 and top_spin == 6,
        "epsilon": epsilon == Fraction(1, 99144) and epsilon == Fraction(2, K2_MIN + K2_MAX),
        "rho_15_17": rho == Fraction(15, 17),
        "gamma_is_one_on_kernel": all(gamma(casimir(j)) == 1 and gap(casimir(j)) == 99144
                                      for j in kernel_spins),
        "gamma_contracts_off_kernel": all(abs(gamma(x)) <= Fraction(15, 17) for x in off_kernel_nodes),
        "gamma_contraction_extremes": {x for x in off_kernel_nodes if abs(gamma(x)) == Fraction(15, 17)} == {12, 42},
        "gamma_gap_integer_bound": all(gap(x) * 17 <= 15 * 99144 for x in off_kernel_nodes),
        "pr_on_nodes": [pr(x) for x in nodes] == [0, 0, 1814400, 0, 0, 1814400, 0],
        "pr_normalizer_1814400": pr_normalizer == 1814400 == pr(30) == _fact(10) // 2,
        "pr_coefficients": pr_coefficients() == [1, -107, 4088, -66940, 430848, -624960, 0]
        and all(pr(x) == _horner(pr_coefficients(), x) for x in range(-60, 61)),
        "projector_trace_47": sum(d * Fraction(pr(casimir(j)), pr_normalizer)
                                  for j, d in zip(spins, eigenspace_dims)) == 47,
        "tower_values": tower == {"F5": 5, "L5": 11, "F3": 2, "j": 2, "J": 5, "D": 47},
        "tower_kernel_link": tower["D"] == kernel_rank and tower["j"] in kernel_spins
        and tower["J"] in kernel_spins,
        "tower_spin_identity": tower["J"] * (tower["J"] + 1) == 5 * tower["j"] * (tower["j"] + 1),
        "lucas_fibonacci_odd": all(
            fib_luc(n)[1] ** 2 - 5 * fib_luc(n)[0] ** 2 == -4 for n in range(1, 200, 2)),
        "constants_hash_stable": constants_sha256() == constants_sha256(json.loads(canonical_bytes())),
    }


def _fact(n):
    return 1 if n < 2 else n * _fact(n - 1)


def _horner(cs, x):
    acc = 0
    for k in cs:
        acc = acc * x + k
    return acc


if __name__ == "__main__":
    res = verify()
    for k, v in res.items():
        print(("PASS " if v else "FAIL ") + k)
    print("constants sha256:", constants_sha256())
    raise SystemExit(0 if all(res.values()) else 1)
