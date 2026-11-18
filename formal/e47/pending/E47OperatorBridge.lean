/-
  E47OperatorBridge.lean

  STATUS: PLACEHOLDER, NOT PROVED. Three `sorry` placeholders, each labelled
  below. This file is not compiled by any CI workflow and is not part of any
  E47 certificate. Its header as received claimed "Zero sorry · Zero custom
  axioms"; that claim is false and has been replaced by this notice.

  THE THREE OPEN OBLIGATIONS

  1. `factor_divides_prodRoots` -- that (C - rI) factors out of
     prod_{s in roots} (C - sI) when r is among the roots. True, and it
     follows from commutativity of Z[C]; it is simply not written.

  2. `minimal_poly_annihilates_raised` -- the highest-weight induction giving
     M(C) = prod_{j=0}^{6} (C - j(j+1)I) = 0 on V_2^{tensor 3}. This is the
     mathematical content of the whole module, and it is the one that is
     genuinely open.

  3. the non-degeneracy step in `op_image_eq_kernel` -- that D = 1814400 acts
     injectively on a Q-vector space, so D * (K(C) v) = 0 gives K(C) v = 0.

  WHAT IS ALREADY SOUND. The polynomial layer underneath these is exact and
  has been verified independently -- see validation/e47_polynomial_certificates.py:

      K * T          = (x - 31) * M                      exact
      T + K * Q      = 1814400                           exact
      T^2 - 1814400T = M * ((x - 31) * (-Q))             exact
      T(x) = 0 at x in {0, 2, 12, 20, 42},  T(6) = T(30) = 1814400

  so T / 1814400 is the spectral projector onto ker K, and 1814400 = 10!/2 is
  the same normalising constant that appears in the degree-six interpolation
  polynomial P_E(C) of the canonical construction.

  The three theorems that take `hM : evalOp C M_poly = 0` as a hypothesis are
  therefore conditional results resting on exact arithmetic. What is unproved
  is the hypothesis itself, not the algebra built on it.
-/
-- (body omitted pending obligations 1-3; see the session transcript)
