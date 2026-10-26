-- Sample file verifying mathlib is available onsite.
-- Run after `lake exe cache get`.

import Mathlib.Data.Nat.Basic
import Mathlib.LinearAlgebra.Matrix.Rank
import Mathlib.GroupTheory.GroupAction.Basic

-- Minimal check that the library resolves.
#check Nat.add
#check Matrix.rank

def exampleRankStatement : Prop :=
  ∀ (A : Matrix (Fin 125) (Fin 125) ℚ), True
