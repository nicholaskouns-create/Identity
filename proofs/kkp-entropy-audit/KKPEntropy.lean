import Init

namespace KKPEntropy

-- Exact cross-multiplication establishes 47/125 = 376/1000.
theorem ratio_exact : 47 * 1000 = 376 * 125 := by decide

-- The stable GL minimum for beta=1 and alpha=-2*x is x.
-- These two positive choices are different, hence no universal
-- numerical minimum follows from beta>0 alone.
theorem gl_case_a : 752 * 376 = 2 * 376 * 376 := by decide
theorem gl_case_b : 400 * 200 = 2 * 200 * 200 := by decide
theorem distinct_minima : 376 ≠ 200 := by decide

end KKPEntropy
