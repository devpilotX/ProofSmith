import ProofSmith.ErdosStraus.Defs
import ProofSmith.ErdosStraus.Scale
import ProofSmith.ErdosStraus.Residue
import Mathlib.Data.Nat.Prime.Basic

/-!
# Reduction to primes and isolation of the open core

* `es_of_primes`: if every prime satisfies `ErdosStraus`, then so does
  every `n ≥ 2`. Take the least prime factor `p = n.minFac`, write
  `n = p * m`, and scale a representation of `4/p` by `m`.

* `es_prime_of_core`: every prime is handled given the primes
  `≡ 1 (mod 4)`. The prime `2` and the primes `≡ 3 (mod 4)` are closed
  outright (`es_two`, `es_mod4`).

Combined, the whole conjecture reduces to the primes `≡ 1 (mod 4)`,
which is the isolated open core.
-/

namespace ProofSmith

/-- Reduction to primes. -/
lemma es_of_primes (H : ∀ p : ℕ, p.Prime → ErdosStraus p) :
    ∀ n : ℕ, 2 ≤ n → ErdosStraus n := by
  intro n hn
  have hn1 : n ≠ 1 := by omega
  have hp : (n.minFac).Prime := Nat.minFac_prime hn1
  obtain ⟨m, hm⟩ := Nat.minFac_dvd n
  have hmpos : 0 < m := by
    rcases Nat.eq_zero_or_pos m with h0 | h0
    · rw [h0, Nat.mul_zero] at hm; omega
    · exact h0
  rw [hm]
  exact es_scale n.minFac m hmpos (H _ hp)

/-- Every prime is handled given the open core (primes `≡ 1 mod 4`). -/
lemma es_prime_of_core
    (Hcore : ∀ p : ℕ, p.Prime → p % 4 = 1 → ErdosStraus p) :
    ∀ p : ℕ, p.Prime → ErdosStraus p := by
  intro p hp
  rcases hp.eq_two_or_odd with h2 | hodd
  · rw [h2]; exact es_two
  · have hcases : p % 4 = 1 ∨ p % 4 = 3 := by omega
    rcases hcases with h1 | h3
    · exact Hcore p hp h1
    · exact es_mod4 p h3

/-- The open core, isolated precisely: the primes `≡ 1 (mod 4)`. -/
def OpenCore : Prop := ∀ p : ℕ, p.Prime → p % 4 = 1 → ErdosStraus p

/-- Conditional theorem: the full conjecture reduces to `OpenCore`. This
is fully proved (no `sorry`): every `n ≥ 2` is covered once the open
core is. -/
theorem erdos_straus_of_core (h : OpenCore) :
    ∀ n : ℕ, 2 ≤ n → ErdosStraus n :=
  es_of_primes (es_prime_of_core h)

/-- North-star statement of the Erdős–Straus conjecture. The single gap
is `OpenCore` (primes `≡ 1 mod 4`), marked `sorry`. Everything else is
kernel-checked. -/
theorem erdos_straus : ∀ n : ℕ, 2 ≤ n → ErdosStraus n := by
  apply erdos_straus_of_core
  intro p _hp _hp4
  sorry

end ProofSmith
