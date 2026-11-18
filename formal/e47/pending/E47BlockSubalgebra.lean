/-
  E47BlockSubalgebra.lean

  STATUS: PLACEHOLDER, NOT PROVED. `toBlock_mul` does not compile; under
  Lean 4.19.0 and 4.35.0 it reports an unsolved goal and an unknown tactic,
  and `#print axioms toBlock_mul` returns [propext, sorryAx, Quot.sound].
  This file is not compiled by any CI workflow and is not part of any E47
  certificate. The verified combinatorics live in formal/e47/E47BlockCasimir.lean.

  WHAT IS MISSING. One index-translation lemma, and only that:

      l.foldl (fun acc t => acc + g t) init
        = (List.finRange l.length).foldl (fun acc i => acc + g (l.get i)) init

  i.e. that folding a sum over a list agrees with folding it over the
  positions of that list. Everything else in the argument is in place --
  the vanishing of A t1 t2 off the weight fiber follows from
  IsWeightPreserving, and `foldl_allTriples_eq_fiber` already compiles.

  Closing that lemma closes the theorem, and the theorem is what licenses
  replacing a 125 x 125 polynomial identity by thirteen block identities.
-/
-- (body omitted pending the index lemma above; see the session transcript)
