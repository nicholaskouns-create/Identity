# Concrete spin-2 bedrock certificate

This module constructs the 125-dimensional Casimir from integer raising/lowering operators, not from a diagonal surrogate. It verifies the degree-seven annihilator on every basis vector and applies the five-stage exact rational projector to compute trace 47.

Source and reproducible Python tests: [Mathematical City Foundry](https://nicholaskouns-create.github.io/unified/).

The projector is the polynomial in K² with roots 11664,12544,19600,32400,186624. Five factors are minimal **among polynomials in K²** since the polynomial must vanish at all five distinct nonzero eigenvalues while equaling 1 at zero. This is not a claim of minimal quantum circuit depth.

See accompanying `bedrock.py` for executable checks.
