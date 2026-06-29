# ProofSmith

ProofSmith attacks a hard math conjecture and only accepts proof that a
formal proof kernel actually checks. No hand-waving, no "clearly". If the
kernel did not accept it, it does not count.

This repo's target is the **Erdős–Straus conjecture**: for every integer
n ≥ 2 there are positive integers x, y, z with

    4/n = 1/x + 1/y + 1/z

It is done in Lean 4 on top of mathlib.

## Honest headline

The conjecture is **not solved**. It is still open.

What this repo does have is a full, gap-free, kernel-checked reduction of
the whole conjecture down to one open family: the primes p ≡ 1 (mod 4).
Everything else is machine-verified. There is no hidden `sorry` and no
surprise axiom. You can clone it, build it, and check the same statuses
yourself.

## What is proved

| Lemma | What it says (cleared ℕ form) | Status |
|-------|-------------------------------|--------|
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

The reduction in one picture:

    ErdosStraus for all n ≥ 2
      ⇐ ErdosStraus for all primes p
          p = 2             → es_two     PROVED
          p ≡ 3 (mod 4)     → es_mod4    PROVED
          p ≡ 1 (mod 4)     → OpenCore   OPEN   ← the wall
      composite n: scale up from its least prime factor

## Build

One command. The toolchain installs itself from `lean-toolchain`
(`leanprover/lean4:v4.31.0`).

    lake build ProofSmith

Re-run the axiom audit (this is what proves there is no hidden gap):

    lake env lean ProofSmith/Audit.lean

Heads up: in the machine this was built on, the bundled linker is blocked
by an Application Control policy, so `lake exe cache get` does not work
and no Lean executable can be linked. The fix is to build the needed
mathlib subset from source. Oleans need no linker, so the library still
compiles. The first build is around 700 files, so it takes a while.

## Layout

    ProofSmith.lean                       root module + hello_world
    ProofSmith/ErdosStraus/Defs.lean      predicate, base cases, es_of_two
    ProofSmith/ErdosStraus/Scale.lean     es_scale
    ProofSmith/ErdosStraus/Residue.lean   es_four_k_three, es_mod4
    ProofSmith/ErdosStraus/Reduction.lean es_of_primes, OpenCore, north-star
    ProofSmith/Audit.lean                 #print axioms for every lemma
    docs/                                 target pick, decomposition, full report
    PROGRESS.md                           current state, read this first

## The open core

The one thing left is the primes p ≡ 1 (mod 4). The plan to push further
is the classical covering-congruence argument mod 840, which would shrink
the open part to the same handful of residues the literature stops at. It
would still not close the conjecture. Details are in `docs/REPORT.md`.
