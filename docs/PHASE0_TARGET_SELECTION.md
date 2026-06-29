# Phase 0 — Target Selection

Goal: pick one hard or open conjecture where I can make real,
machine-checked progress in Lean 4 + mathlib. Full resolution is the
stretch goal. The honest required goal is a clean formal decomposition,
some newly verified non-trivial lemmas, and a precisely isolated open
core, with zero hidden gaps.

Below are three candidates at the edge of formal math, then the pick.

---

## Candidate 1 — Erdős–Straus conjecture

a. Statement.
   Natural language: for every integer n >= 2, the fraction 4/n is a
   sum of three unit fractions. That is, there are positive integers
   x, y, z with 4/n = 1/x + 1/y + 1/z.
   Near-formal: ∀ n ≥ 2, ∃ x y z > 0, 4/n = 1/x + 1/y + 1/z.

b. Known results.
   Open since 1948. Verified by computer for all n up to very large
   bounds (past 10^17). It is known that the conjecture can only
   possibly fail for n in a short list of residue classes mod 840, and
   only for primes. Erdős, Mordell, Yamamoto and others gave explicit
   constructions covering almost all residue classes. In mathlib today
   there is no formalization of the conjecture or its partial results,
   but all the raw materials exist: rationals, divisibility, Nat.minFac
   and the prime API, and the ring / field_simp tactics.

c. Difficulty.
   The obstruction is that the easy congruence constructions cover every
   class except a thin set (primes p ≡ 1 mod 24, refined to a few
   squares mod 840). For those, no single polynomial identity is known
   to always work, and the search for witnesses ties into deep questions
   about which n admit short Egyptian fractions. The hard core is a
   genuine wall, not a gap in bookkeeping.

d. Smallest honest win.
   Formally prove the multiplicative reduction (it is enough to prove it
   for primes) plus explicit closures for several residue classes
   (even n, n ≡ 0 mod 3, n ≡ 3 mod 4, ...). Then state the leftover
   classes as the precise open core. Each closure is a "build a witness,
   verify the arithmetic" lemma the kernel can fully check.

e. Library readiness.
   High. Witnesses are explicit polynomials in a parameter, and the
   verification is one ring identity over ℚ (or a cross-multiplied
   identity over ℕ). The reduction to primes needs Nat.minFac, which
   mathlib has. Almost nothing has to be built from scratch.

---

## Candidate 2 — Collatz conjecture

a. Statement.
   Define T(n) = n/2 if n even, 3n+1 if n odd. Conjecture: for every
   n >= 1, iterating T eventually reaches 1.
   Near-formal: ∀ n ≥ 1, ∃ k, T^[k] n = 1.

b. Known results.
   Open since the 1930s. Verified by computer to about 2^68. Tao (2019)
   proved almost all orbits reach a value that is almost bounded, but
   that is an analytic statement well beyond current formalization.
   mathlib has the natural numbers and iteration but no Collatz theory.

c. Difficulty.
   No usable structure. The map mixes multiplication and division so
   orbits look pseudo-random. There is no known reduction that shrinks
   the problem to a finite check, so a formal attack stalls almost
   immediately past trivial sub-cases.

d. Smallest honest win.
   Powers of two reach 1 (easy), and some residue classes drop below
   their start after a few steps. These are real but thin, and the
   residue-drop proofs need fiddly case analysis with little leverage
   toward the core.

e. Library readiness.
   Medium. Self-contained in ℕ, no mathlib needed, but the meaningful
   lemmas give weak structural progress.

---

## Candidate 3 — Frankl's union-closed sets conjecture

a. Statement.
   In any finite family of sets closed under union (with at least one
   nonempty set), some element lies in at least half the sets.

b. Known results.
   Open since 1979. Gilmer (2022) proved a constant-fraction version
   (about 1%), later improved to roughly 0.38 by several groups. These
   use an entropy / information-theoretic argument.

c. Difficulty.
   The recent progress is analytic (entropy inequalities on random
   subsets). Formalizing that machinery is a large project on its own,
   and the gap from 0.38 to 0.5 is wide open.

d. Smallest honest win.
   Formalize the statement and small finite cases. The Gilmer bound is a
   big formalization effort with heavy entropy prerequisites.

e. Library readiness.
   Low to medium. mathlib has finite sets and some entropy, but wiring
   up the Gilmer argument is heavy and risky inside a budget.

---

## Pick: Erdős–Straus conjecture

Reason: tractability times significance is highest. It is a genuinely
open problem, yet the partial structure is clean and citable, and every
piece I would claim is a kernel-checkable arithmetic fact. I can deliver
a real reduction lemma (enough to prove it for primes), several verified
residue-class closures, and a precisely stated open core, all with no
hidden gaps. Collatz gives weak leverage. Frankl needs heavy analytic
prerequisites that do not fit the budget. Erdős–Straus lets the verified
code and the status ledger carry the result, which is exactly what this
project is graded on.

Plan of attack (refined in later phases):
- Define ErdosStraus n over ℕ with an explicit unit-fraction predicate.
- Prove a "two terms to three terms" splitting helper.
- Prove explicit closures: n even, n ≡ 0 mod 3, n ≡ 3 mod 4, and more.
- Prove the multiplicative reduction to primes.
- Combine: isolate the open core as primes in specific residue classes.
- Audit with #print axioms. Report honest statuses.
