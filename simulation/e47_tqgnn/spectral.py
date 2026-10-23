"""Independent E47 carrier: angular-momentum addition, exact integers, and the 125-d matrix."""
import numpy as np


def couple(j1, j2):
    lo = abs(j1 - j2)
    return list(range(lo, j1 + j2 + 1))


def three_spin2():
    spins = []
    for intermediate in couple(2, 2):
        spins.extend(couple(intermediate, 2))
    return spins


def counts(spins):
    return [spins.count(j) for j in range(7)]


def casimir(j):
    return j * (j + 1)


def polynomial(c):
    return (c - 6) * (c - 30)


def gap(c):
    return abs(99144 - polynomial(c) ** 2)


def exact_certificate():
    multiplicities = counts(three_spin2())
    if multiplicities != [1, 3, 5, 4, 3, 2, 1]:
        raise AssertionError(multiplicities)
    dimension = sum(multiplicities[j] * (2 * j + 1) for j in range(7))
    if dimension != 125:
        raise AssertionError(dimension)
    nodes = [casimir(j) for j in range(7)]
    if nodes != [0, 2, 6, 12, 20, 30, 42]:
        raise AssertionError(nodes)
    rank = multiplicities[2] * 5 + multiplicities[5] * 11
    if rank != 47:
        raise AssertionError(rank)
    if polynomial(6) != 0 or polynomial(30) != 0:
        raise AssertionError('kernel polynomial')
    if gap(6) != 99144 or gap(30) != 99144:
        raise AssertionError('kernel gamma')
    if (42 - 6) * (42 - 30) * ((42 - 6) * (42 - 30)) * 17 != 99144 * 32:
        raise AssertionError('denominator')
    bound = 15 * 99144
    expected = {0: 'lt', 2: 'lt', 12: 'eq', 20: 'lt', 42: 'eq'}
    for value, kind in expected.items():
        got = gap(value) * 17
        if kind == 'lt' and not got < bound:
            raise AssertionError(value)
        if kind == 'eq' and got != bound:
            raise AssertionError(value)
    algebra = rational_spin2_algebra()
    return {
        'multiplicities': multiplicities,
        'eigenspace_dimensions': [multiplicities[j] * (2 * j + 1) for j in range(7)],
        'dimension': dimension,
        'casimir_nodes': nodes,
        'kernel_rank': rank,
        'gamma_12': '15/17',
        'gamma_42': '-15/17',
        'rational_sl2': algebra,
    }


def _matmul(a, b):
    n = len(a)
    return [[sum(a[i][k] * b[k][j] for k in range(n)) for j in range(n)] for i in range(n)]


def _sub(a, b):
    return [[a[i][j] - b[i][j] for j in range(len(a))] for i in range(len(a))]


def _scale(k, a):
    return [[k * a[i][j] for j in range(len(a))] for i in range(len(a))]


def _add(a, b):
    return [[a[i][j] + b[i][j] for j in range(len(a))] for i in range(len(a))]


def rational_spin2_algebra():
    """Integer raising and lowering operators in the non-orthonormal spin basis."""
    jp = [[0] * 5 for _ in range(5)]
    jm = [[0] * 5 for _ in range(5)]
    for i in range(1, 5):
        jp[i - 1][i] = i
        jm[i][i - 1] = 5 - i
    jz = [[0] * 5 for _ in range(5)]
    for i, m in enumerate((2, 1, 0, -1, -2)):
        jz[i][i] = m
    eye = [[1 if i == j else 0 for j in range(5)] for i in range(5)]
    if _sub(_matmul(jp, jm), _matmul(jm, jp)) != _scale(2, jz):
        raise AssertionError('[J+, J-]')
    if _sub(_matmul(jz, jp), _matmul(jp, jz)) != jp:
        raise AssertionError('[Jz, J+]')
    if _sub(_matmul(jz, jm), _matmul(jm, jz)) != _scale(-1, jm):
        raise AssertionError('[Jz, J-]')
    product = _add(_matmul(jp, jm), _matmul(jm, jp))
    if any(value % 2 for row in product for value in row):
        raise AssertionError('odd Casimir term')
    half = _add(_matmul(jz, jz), [[value // 2 for value in row] for row in product])
    if half != _scale(6, eye):
        raise AssertionError('single-factor Casimir')
    return True


def _total(generator):
    eye = np.eye(5, dtype=np.complex128)
    return (np.kron(np.kron(generator, eye), eye)
            + np.kron(np.kron(eye, generator), eye)
            + np.kron(np.kron(eye, eye), generator))


def numerical_carrier():
    j = 2.0
    magnetic = np.arange(j, -j - 1, -1)
    raising = np.zeros((5, 5), dtype=np.complex128)
    for i in range(1, 5):
        raising[i - 1, i] = np.sqrt(j * (j + 1) - magnetic[i] * (magnetic[i] + 1))
    jx = (raising + raising.conj().T) / 2
    jy = (raising - raising.conj().T) / (2j)
    jz = np.diag(magnetic).astype(np.complex128)
    Jx, Jy, Jz = (_total(jx), _total(jy), _total(jz))
    if np.linalg.norm(Jx @ Jy - Jy @ Jx - 1j * Jz) > 1e-8:
        raise AssertionError('su(2) relation')
    casimir_operator = Jx @ Jx + Jy @ Jy + Jz @ Jz
    eigenvalues, vectors = np.linalg.eigh(casimir_operator)
    nodes = [0, 2, 6, 12, 20, 30, 42]
    found = [int(np.sum(np.abs(eigenvalues - node) < 1e-7)) for node in nodes]
    expected = [1, 9, 25, 28, 27, 22, 13]
    if found != expected:
        raise AssertionError(found)
    selected = (np.abs(eigenvalues - 6) < 1e-7) | (np.abs(eigenvalues - 30) < 1e-7)
    if int(np.sum(selected)) != 47:
        raise AssertionError('numerical rank')
    code = vectors[:, selected]
    projector = code @ code.conj().T
    identity = np.eye(125, dtype=np.complex128)
    kernel_polynomial = (casimir_operator - 6 * identity) @ (casimir_operator - 30 * identity)
    gamma = identity - kernel_polynomial @ kernel_polynomial / 99144
    residuals = {
        'projector': float(np.linalg.norm(projector @ projector - projector)),
        'kernel': float(np.linalg.norm(kernel_polynomial @ projector)),
        'fixed': float(np.linalg.norm(gamma @ projector - projector)),
    }
    if max(residuals.values()) > 1e-8:
        raise AssertionError(residuals)
    norms = {}
    for power in (1, 2, 10):
        got = float(np.linalg.norm(np.linalg.matrix_power(gamma, power) - projector, 2))
        expect = (15 / 17) ** power
        if abs(got - expect) > 1e-8:
            raise AssertionError((power, got, expect))
        norms[str(power)] = {'got': got, 'expect': expect}
    shift = np.roll(np.eye(47, dtype=int), 1, axis=0)
    if not np.array_equal(np.roll(np.eye(47, dtype=int), 47, axis=0), np.eye(47, dtype=int)):
        raise AssertionError('clock order')
    if not np.array_equal(shift.T @ shift, np.eye(47, dtype=int)):
        raise AssertionError('clock orthogonal')
    return {'eigenspace_counts': found, 'residuals': residuals, 'norms': norms, 'code_shape': list(code.shape)}
