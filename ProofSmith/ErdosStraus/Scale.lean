import ProofSmith.ErdosStraus.Defs

/-!
# Multiplicative scaling

If `4/n` has a 3-term unit-fraction representation, so does `4/(n*m)`
for any `m > 0`: scale every denominator by `m`. This is the engine
behind the reduction to primes.
-/

namespace ProofSmith

/-- If `ErdosStraus n` holds then `ErdosStraus (n*m)` holds for `m > 0`.
Witnesses scale by `m`. -/
lemma es_scale (n m : ℕ) (hm : 0 < m) (h : ErdosStraus n) :
    ErdosStraus (n * m) := by
  obtain ⟨x, y, z, hx, hy, hz, hxyz⟩ := h
  refine ⟨x * m, y * m, z * m, Nat.mul_pos hx hm, Nat.mul_pos hy hm,
    Nat.mul_pos hz hm, ?_⟩
  calc 4 * (x * m * (y * m) * (z * m))
      = (4 * (x * y * z)) * (m * m * m) := by ring
    _ = (n * (y * z + x * z + x * y)) * (m * m * m) := by rw [hxyz]
    _ = n * m * (y * m * (z * m) + x * m * (z * m) + x * m * (y * m)) := by
        ring

end ProofSmith
