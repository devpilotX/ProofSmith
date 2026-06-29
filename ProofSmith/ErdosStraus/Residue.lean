import ProofSmith.ErdosStraus.Defs

/-!
# Residue-class closure: `n ≡ 3 (mod 4)`

For `n = 4k+3` there is a clean two-term identity
`4/n = 1/(k+1) + 1/((4k+3)(k+1))`. In cleared form this is
`4 * ((k+1) * ((4k+3)(k+1))) = (4k+3) * ((k+1) + (4k+3)(k+1))`, which
`es_of_two` turns into a three-term representation.
-/

namespace ProofSmith

/-- Explicit closure for `n = 4k+3`. -/
lemma es_four_k_three (k : ℕ) : ErdosStraus (4 * k + 3) := by
  refine es_of_two (4 * k + 3) (k + 1) ((4 * k + 3) * (k + 1)) (by omega)
    (Nat.mul_pos (by omega) (by omega)) ?_
  ring

/-- Closure for every `n ≡ 3 (mod 4)`. -/
lemma es_mod4 (n : ℕ) (h : n % 4 = 3) : ErdosStraus n := by
  obtain ⟨k, rfl⟩ : ∃ k, n = 4 * k + 3 := ⟨n / 4, by omega⟩
  exact es_four_k_three k

end ProofSmith
