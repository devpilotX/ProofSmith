import ProofSmith.ErdosStraus.Defs
import ProofSmith.ErdosStraus.Scale
import ProofSmith.ErdosStraus.Residue
import ProofSmith.ErdosStraus.Reduction

/-!
# Audit

Run with `lake env lean ProofSmith/Audit.lean`. Every PROVED lemma must
report only the standard axioms `[propext, Classical.choice, Quot.sound]`
(or fewer) and must NOT mention `sorryAx`. The north-star `erdos_straus`
is expected to report `sorryAx` because it depends on the OPEN core.
-/

open ProofSmith

-- PROVED leaves and structure: expect NO sorryAx.
#print axioms es_of_two
#print axioms es_two
#print axioms es_three
#print axioms es_scale
#print axioms es_four_k_three
#print axioms es_mod4
#print axioms es_of_primes
#print axioms es_prime_of_core
#print axioms erdos_straus_of_core

-- North-star: expected to depend on `sorryAx` via the OPEN core.
#print axioms erdos_straus
