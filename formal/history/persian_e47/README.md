# Persian Algebra × E47: historically grounded accordance

**Evidence status:** SymPy verifies four exact identities; Lean 4/Coq scripts are proposed and require independently checked compiler and axiom receipts. Do not label historical scholarship as validation of E47.

## The original historical source

British Library IO Islamic 461 (*al-Muʿādalāt*, dated 1198 CE) is an anonymous Arabic abridgment of a lost work by Sharaf al-Dīn al-Ṭūsī about cubic equations. The surviving manuscript contains diagrams. Hogendijk (1989) analyzes al-Ṭūsī's positive-root classification and the numerical approximation of the smallest positive root of `x³ + c = a x²`.

These proof files **do not reconstruct the historical approximation procedure**. They establish exact modern algebraic propositions concerning the same polynomial family.

## Four precise certificates

Let `f(x) = x³ − ax² + c`, `Tω(x) = x + ω f(x)`.

1. `f(2a/3) = c − 4a³/27`.
2. `f(x) − f(2a/3) = (x−2a/3)²(x+a/3)`.
3. `f(r)=0 ⇒ Tω(r)=r`.
4. `f(r)=0 ⇒ Tω(r+e)−r = [1−ωr(2a−3r)]e + ω(3r−a)e² + ωe³`.

For a,c>0, there are two, one distinct double, or zero positive roots according as 27c is less than, equal to, or greater than 4a³. The scalar iteration is locally attracting at the smaller root when `0<ω<2/[r(2a−3r)]`. These latter propositions are explanatory and **not included in the four Lean/Coq lemmas yet**.

E47's independent projector iteration `Γ=I−K²/99144`, with `K=(C−6I)(C−30I)`, preserves a 47-dimensional kernel in the 125-dimensional carrier. The comparison is about invariant preservation and controlled error reduction, *not* an identity of historical and modern algorithms.

## Reproduce

```sh
python3 -m pip install sympy
python3 formal/history/persian_e47/verify_symbolic.py
lake env lean formal/history/persian_e47/PersianCubic.lean   # requires Mathlib
coqc formal/history/persian_e47/PersianCubic.v
```

Only promote to compiler-PASS after both processes complete successfully and relevant axioms are audited.

## APA 7 references

British Library. (n.d.). *Al-Muʿādalāt* [Manuscript, IO Islamic 461, fols. 35v–180r]. Qatar Digital Library. https://qdl.qa/en/archive/81055/vdc_100025776458.0x000003

Hogendijk, J. P. (1989). Sharaf al-Dīn al-Ṭūsī on the number of positive roots of cubic equations. *Historia Mathematica, 16*(1), 69–85. https://doi.org/10.1016/0315-0860(89)90099-2

Ypma, T. J. (1995). Historical development of the Newton–Raphson method. *SIAM Review, 37*(4), 531–551. https://doi.org/10.1137/1037125

Gander, M. J., Henry, P., & Wanner, G. (2026). Landmarks in the history of iterative methods. *SIAM Review, 68*(1), 3–90. https://doi.org/10.1137/24M1680428
