# ProofSmith — Final Report

## A. Header
- Target: Erdős–Straus conjecture. For every integer n ≥ 2 there are
  positive integers x, y, z with 4/n = 1/x + 1/y + 1/z.
- Proof assistant: Lean 4, toolchain `leanprover/lean4:v4.31.0`.
- Library: mathlib, git tag `v4.31.0`.
- Allowed axioms: classical logic + choice (the mathlib default:
  `propext`, `Classical.choice`, `Quot.sound`). No extra axioms added.
- Headline, one honest sentence: the Erdős–Straus conjecture is reduced,
  with a fully kernel-checked proof and no hidden gaps, to a single open
  family, the primes p ≡ 1 (mod 4); everything else is machine-verified.

This is a partial result, not a solution. The conjecture is still open.
What is new here is a clean, compiling, gap-free reduction and a set of
verified lemmas, with the open part named as a precise formal statement.

## B. Status ledger and axiom check

| Lemma | Statement (cleared-denominator form over ℕ) | Status |
|-------|----------------------------------------------|--------|
| es_of_two | 4·a·b = n·(a+b) ⟹ ErdosStraus n | PROVED |
| es_two | ErdosStraus 2 | PROVED |
| es_three | ErdosStraus 3 | PROVED |
| es_scale | ErdosStraus n ⟹ ErdosStraus (n·m), m>0 | PROVED |
| es_four_k_three | ErdosStraus (4k+3) | PROVED |
| es_mod4 | n%4=3 ⟹ ErdosStraus n | PROVED |
| es_of_primes | (∀ prime p, ES p) ⟹ ∀ n≥2, ES n | PROVED |
| es_prime_of_core | (∀ prime p≡1[4], ES p) ⟹ ∀ prime p, ES p | PROVED |
| erdos_straus_of_core | OpenCore ⟹ ∀ n≥2, ES n | PROVED |
| OpenCore | ∀ prime p, p%4=1 → ErdosStraus p | OPEN |
| erdos_straus | ∀ n≥2, ErdosStraus n | REDUCED to OpenCore |

Definition of the predicate (Defs.lean):

    ErdosStraus n := ∃ x y z : ℕ, 0 < x ∧ 0 < y ∧ 0 < z ∧
      4 * (x * y * z) = n * (y * z + x * z + x * y)

Faithfulness: for positive n, x, y, z this cleared equation is
equivalent to 4/n = 1/x + 1/y + 1/z (divide or multiply by the positive
integer n·x·y·z). So `ErdosStraus n` is exactly the per-n Erdős–Straus
statement. We keep it in ℕ so every step is checked by `ring` over a
commutative semiring, with no division and no side conditions.

Axiom check, verbatim from `lake env lean ProofSmith/Audit.lean`:

    'ProofSmith.es_of_two' depends on axioms: [propext, Quot.sound]
    'ProofSmith.es_two' does not depend on any axioms
    'ProofSmith.es_three' does not depend on any axioms
    'ProofSmith.es_scale' depends on axioms: [propext]
    'ProofSmith.es_four_k_three' depends on axioms: [propext, Quot.sound]
    'ProofSmith.es_mod4' depends on axioms: [propext, Quot.sound]
    'ProofSmith.es_of_primes' depends on axioms: [propext, Classical.choice, Quot.sound]
    'ProofSmith.es_prime_of_core' depends on axioms: [propext, Quot.sound]
    'ProofSmith.erdos_straus_of_core' depends on axioms: [propext, Classical.choice, Quot.sound]
    'ProofSmith.erdos_straus' depends on axioms: [propext, sorryAx, Classical.choice, Quot.sound]

Reading: every PROVED lemma uses only default axioms and none mentions
`sorryAx`. The two base cases use no axioms at all. Only `erdos_straus`
carries `sorryAx`, and that is exactly the OPEN core (`OpenCore`). There
is no surprise axiom and no hidden `sorry`.

## C. Reduction map and dependency graph

    ErdosStraus for all n ≥ 2
      ⇐ es_of_primes ⇐ ErdosStraus for all primes p
          p = 2             → es_two     PROVED
          p ≡ 3 (mod 4)     → es_mod4    PROVED
          p ≡ 1 (mod 4)     → OpenCore   OPEN   ← the wall
      composite n: es_scale on the least prime factor p = n.minFac

Full node graph and per-node strategies: see docs/DECOMPOSITION.md.

## D. Formal source, in compile order
1. ProofSmith/ErdosStraus/Defs.lean — predicate, faithfulness note,
   `unit`-split helper `es_of_two`, base cases `es_two`, `es_three`.
   Imports `Mathlib.Tactic.Ring`.
2. ProofSmith/ErdosStraus/Scale.lean — `es_scale` (multiplicative
   scaling). Pure `ring`.
3. ProofSmith/ErdosStraus/Residue.lean — `es_four_k_three`, `es_mod4`.
4. ProofSmith/ErdosStraus/Reduction.lean — `es_of_primes`,
   `es_prime_of_core`, `OpenCore`, `erdos_straus_of_core`, and the
   north-star `erdos_straus` (the sole `sorry`). Imports
   `Mathlib.Data.Nat.Prime.Basic` for the least-prime-factor API.
5. ProofSmith.lean — root, imports the above plus `hello_world`.
6. ProofSmith/Audit.lean — `#print axioms` for every lemma.

Build (one command), after `elan` is installed:

    lake build ProofSmith

The toolchain auto-installs from `lean-toolchain`. Re-run the axiom
audit with:

    lake env lean ProofSmith/Audit.lean

## E. Failure log (what broke, what it ruled out)
1. `lake exe cache get` failed. The bundled linker `ld.lld.exe` is
   blocked by a Windows Application Control policy (error 0x11C7).
   `clang` cannot link, so the `cache` executable cannot be built, so the
   prebuilt mathlib olean cache cannot be fetched, and no Lean executable
   can be produced at all in this environment. Confirmed with a minimal C
   link test. Unblock-File did not help (it is not a Mark-of-the-Web
   issue, it is a hash/policy block I cannot override without admin).
   Ruled out: the cache, and anything that needs native linking.
   Workaround that worked: build only the needed mathlib subset from
   source. Oleans are produced by `lean.exe` and need no linker, so the
   library compiles fine (720 jobs).
2. First formalization used the ℚ unit-fraction form with `field_simp`.
   That pulls a much larger chunk of mathlib (Rat, field and order-field
   hierarchy, norm_cast), which is expensive to build from source with no
   cache. Switched to the cleared-denominator ℕ form. This cut the build
   to the `ring` + `Nat.Prime` closure (~700 files) and removed all casts
   and side conditions. Ruled out: heavy ℚ/field dependency here.
3. mod-3 residue closure not achieved. The two-term trick that closes
   n ≡ 3 (mod 4) (because 4 divides n+1) does not drop out for
   n ≡ 2 (mod 3): after subtracting 1/((n+1)/3) the remainder is not a
   unit fraction. So the open core stays at p ≡ 1 (mod 4) rather than
   shrinking to p ≡ 1 (mod 12). Not a dead end, just not done; see memo.

## F. Progress statement and next-attempt memo

What is machine-verified now that was not before (in this project):
- A gap-free Lean reduction of Erdős–Straus to the primes p ≡ 1 (mod 4).
- The multiplicative scaling lemma `es_scale` and the reduction to primes
  `es_of_primes` via the least prime factor.
- Explicit verified closures for n even-by-scaling, p = 2, and the whole
  class n ≡ 3 (mod 4).
- An axiom check proving no hidden `sorry` and no extra axioms.

Largest fragment closed: every n ≥ 2 whose least prime factor is 2 or is
≡ 3 (mod 4) is fully handled, and all composites reduce to their prime
factors. The single remaining frontier is the primes ≡ 1 (mod 4).

Next attempt for the OPEN core (most promising unexplored path):
- Formalize the classical covering-congruence argument modulo 840. It is
  known that 4/n is solvable for every n except possibly the primes
  p ≡ 1, 11², 13², 17², 19², 23² (mod 840). The build blocks already in
  hand (`es_of_two` plus `ring`) are exactly what is needed: add one
  explicit polynomial identity per covered residue class mod 840, select
  by `n % 840` with `omega`/`decide` case splits, and the open core
  shrinks from "p ≡ 1 (mod 4)" to those ~6 residues mod 840, which is the
  same wall the literature stops at. This is finite and mechanical, just
  laborious. It would not solve the conjecture (those residues are
  genuinely open) but it would push the formal frontier to the known
  edge.
- A smaller intermediate win: a clean family for one more small modulus
  (for example tightening toward p ≡ 1 (mod 24)) using the same
  two-term-then-split pattern.

## Honesty statement
Nothing here is claimed as proved unless the kernel accepted it and the
axiom check is clean. The conjecture itself is NOT solved. The word
"reduced" is used in the precise sense of the ledger: `erdos_straus`
depends on `OpenCore`, which is `sorry`, and that dependency is visible
in the axiom output. A skeptic can clone the repo, run `lake build
ProofSmith`, and reach the same statuses.
