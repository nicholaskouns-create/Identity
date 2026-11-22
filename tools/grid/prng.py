"""Shared deterministic random stream for the Grid acceptance protocol.

The browser engine (grid/engine/prng.js) implements the same generator bit for
bit, so a Python run and a browser run with the same seed draw the same
perturbations and faults. Mulberry32 for uniforms, Box-Muller for normals.
"""
import math

MASK = 0xFFFFFFFF


def _imul(a, b):
    return (a * b) & MASK


class Stream:
    def __init__(self, seed):
        self.state = seed & MASK
        self._spare = None

    def uniform(self):
        self.state = (self.state + 0x6D2B79F5) & MASK
        t = self.state
        t = _imul(t ^ (t >> 15), t | 1)
        t ^= (t + _imul(t ^ (t >> 7), t | 61)) & MASK
        t &= MASK
        return ((t ^ (t >> 14)) & MASK) / 4294967296.0

    def normal(self):
        if self._spare is not None:
            v, self._spare = self._spare, None
            return v
        u1 = self.uniform()
        u2 = self.uniform()
        if u1 < 1e-300:
            u1 = 1e-300
        r = math.sqrt(-2.0 * math.log(u1))
        self._spare = r * math.sin(2.0 * math.pi * u2)
        return r * math.cos(2.0 * math.pi * u2)

    def int_below(self, n):
        return min(n - 1, int(self.uniform() * n))
