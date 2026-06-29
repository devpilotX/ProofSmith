import ProofSmith.ErdosStraus.Defs
import ProofSmith.ErdosStraus.Scale
import ProofSmith.ErdosStraus.Residue
import ProofSmith.ErdosStraus.Reduction

/-!
# ProofSmith root module

Aggregates the Erdős–Straus development and keeps a hello-world lemma
that proves the toolchain pipeline compiles end to end.
-/

namespace ProofSmith

/-- Trivial true lemma. If this compiles, the pipeline works. -/
theorem hello_world : 2 + 2 = 4 := by decide

end ProofSmith
