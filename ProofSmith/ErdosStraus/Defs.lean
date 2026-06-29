import Mathlib.Tactic.Ring

/-!
# Erdős–Straus conjecture: definitions and basic constructors

We work in the cleared-denominator form over `ℕ`. The unit-fraction
equation `4/n = 1/x + 1/y + 1/z` with positive denominators, after
multiplying through by `n*x*y*z`, is exactly

  `4 * (x*y*z) = n * (y*z + x*z + x*y)`.

## Faithfulness check (English)
For positive `n, x, y, z` the two statements are equivalent: dividing
`4*(x*y*z) = n*(y*z + x*z + x*y)` by the positive integer `n*x*y*z`
gives `4/n = 1/x + 1/y + 1/z`, and multiplying back recovers the cleared
form. No information is lost. So `ErdosStraus n` below is precisely the
claim that `4/n` is a sum of three unit fractions with positive integer
denominators, which is the per-`n` statement of the Erdős–Straus
conjecture (`n ≥ 2`). We use the cleared form so the whole development
stays inside `ℕ` arithmetic and is checked by `ring` over a commutative
semiring, with no division and no hidden side conditions.
-/

namespace ProofSmith

/-- `4/n` is a sum of three unit fractions with positive denominators,
written in cleared-denominator form over `ℕ`. -/
def ErdosStraus (n : ℕ) : Prop :=
  ∃ x y z : ℕ, 0 < x ∧ 0 < y ∧ 0 < z ∧
    4 * (x * y * z) = n * (y * z + x * z + x * y)

/-- If `4/n` is a sum of two unit fractions (`4*(a*b) = n*(a+b)` cleared)
then it is a sum of three: split `1/b = 1/(b+1) + 1/(b(b+1))`, i.e. use
witnesses `a, b+1, b*(b+1)`. -/
lemma es_of_two (n a b : ℕ) (ha : 0 < a) (hb : 0 < b)
    (hab : 4 * (a * b) = n * (a + b)) : ErdosStraus n := by
  refine ⟨a, b + 1, b * (b + 1), ha, by omega, Nat.mul_pos hb (by omega), ?_⟩
  calc 4 * (a * (b + 1) * (b * (b + 1)))
      = (b + 1) ^ 2 * (4 * (a * b)) := by ring
    _ = (b + 1) ^ 2 * (n * (a + b)) := by rw [hab]
    _ = n * ((b + 1) * (b * (b + 1)) + a * (b * (b + 1)) + a * (b + 1)) := by
        ring

/-- Base case `4/2 = 1/1 + 1/2 + 1/2`. -/
lemma es_two : ErdosStraus 2 :=
  ⟨1, 2, 2, by decide, by decide, by decide, by decide⟩

/-- Base case `4/3 = 1/1 + 1/4 + 1/12`. -/
lemma es_three : ErdosStraus 3 :=
  ⟨1, 4, 12, by decide, by decide, by decide, by decide⟩

end ProofSmith
