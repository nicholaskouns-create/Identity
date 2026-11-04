import Mathlib
/-! P27: abstract exact algebra in a noncommutative ring.
These theorems apply to complex square matrices once the hypotheses are supplied.
No 64x64 concrete rank witness is claimed here. -/
namespace ObserverP27
variable {R : Type*} [Ring R]
theorem projector_extension (p e : R)
    (hp : p*p=p) (he : e*e=e) (hpe : p*e=0) (hep : e*p=0) :
    (p+e)*(p+e)=p+e := by
  calc
    (p+e)*(p+e) = p*p+p*e+(e*p+e*e) := by noncomm_ring
    _ = p+e := by rw [hp, he, hpe, hep]; simp
theorem complementary_retraction (p e : R)
    (hp : p*p=p) (he : e*e=e) (hpe : p*e=0) (hep : e*p=0) :
    (1-p-e)*(1-p-e)=1-p-e := by
  have h := projector_extension p e hp he hpe hep
  calc
    (1-p-e)*(1-p-e) = 1-(p+e)-(p+e)+(p+e)*(p+e) := by noncomm_ring
    _ = 1-p-e := by rw [h]; noncomm_ring
theorem halmos_involution (p q : R)
    (hs : p*p+q*q=1) (hc : p*q=q*p) :
    (p*p+q*q=1) ∧ (p*q-q*p=0) := by
  constructor
  · exact hs
  · rw [hc]; sub_self
theorem contraction_40 : (2:ℕ)^40=1099511627776 := by norm_num
theorem dimension_counts :
    26+1=27 ∧ 64-27=37 ∧ 64+37=101 := by omega
end ObserverP27
