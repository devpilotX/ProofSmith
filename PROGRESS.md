# PROGRESS — ProofSmith

Read this first, every session. State lives in files, not memory.

## Target
Erdős–Straus conjecture: for every integer n >= 2, there are positive
integers x, y, z with 4/n = 1/x + 1/y + 1/z.

Proof assistant: Lean 4 (v4.31.0) + mathlib (tag v4.31.0), via elan+lake.

## Headline (honest, one sentence)
The Erdős–Straus conjecture is formally reduced, with a fully
kernel-checked proof, to a single open family: the primes p ≡ 1 (mod 4).
Everything except that family is machine-verified, no hidden gaps.

## Current phase
DONE for this pass. All phases complete. Library compiles (720 jobs,
exit 0), axiom audit is clean, decomposition + report written. The only
`sorry` is the OPEN core (primes ≡ 1 mod 4).

## Build (one command)
    lake build ProofSmith
Toolchain auto-installs from `lean-toolchain` (leanprover/lean4:v4.31.0).
NOTE: the mathlib olean cache cannot be fetched here because the bundled
linker `ld.lld.exe` is blocked by an Application Control policy, so the
`cache` exe will not link. We build the needed mathlib subset from source
(oleans need no linker). First build is ~700 files. To re-audit:
    lake env lean ProofSmith/Audit.lean

## What is machine-verified (status ledger)
| Lemma | Statement (cleared-denominator form over ℕ) | Status |
|-------|----------------------------------------------|--------|
| es_of_two | 4·ab = n·(a+b) ⟹ ErdosStraus n | PROVED |
| es_two | ErdosStraus 2 | PROVED |
| es_three | ErdosStraus 3 | PROVED |
| es_scale | ErdosStraus n ⟹ ErdosStraus (n·m), m>0 | PROVED |
| es_four_k_three | ErdosStraus (4k+3) | PROVED |
| es_mod4 | n%4=3 ⟹ ErdosStraus n | PROVED |
| es_of_primes | (∀ prime p, ES p) ⟹ ∀ n≥2, ES n | PROVED |
| es_prime_of_core | (∀ prime p≡1[4], ES p) ⟹ ∀ prime p, ES p | PROVED |
| erdos_straus_of_core | OpenCore ⟹ ∀ n≥2, ES n | PROVED |
| OpenCore | ∀ prime p, p%4=1 → ErdosStraus p | OPEN |
| erdos_straus | ∀ n≥2, ErdosStraus n | REDUCED to OpenCore (sorry) |

## Reduction map
ErdosStraus for all n≥2
  ⇐ es_of_primes ⇐ ErdosStraus for all primes
      prime p = 2            → es_two            PROVED
      prime p ≡ 3 (mod 4)    → es_mod4           PROVED
      prime p ≡ 1 (mod 4)    → OpenCore          OPEN  ← the wall
Composite n handled by es_scale on the least prime factor.

## Files
- ProofSmith/ErdosStraus/Defs.lean      predicate + faithfulness + es_of_two, es_two, es_three
- ProofSmith/ErdosStraus/Scale.lean     es_scale
- ProofSmith/ErdosStraus/Residue.lean   es_four_k_three, es_mod4
- ProofSmith/ErdosStraus/Reduction.lean es_of_primes, es_prime_of_core, OpenCore, north-star
- ProofSmith/Audit.lean                 #print axioms for all lemmas
- ProofSmith.lean                       root + hello_world

## Next action
Project complete for this pass. To extend, attack OpenCore (primes ≡ 1
mod 4) via the mod-840 covering-congruence identities (see the
next-attempt memo in docs/REPORT.md). Re-verify in any future session
with `lake build ProofSmith` and `lake env lean ProofSmith/Audit.lean`.

## Done so far
- Phase 0: target picked (docs/PHASE0_TARGET_SELECTION.md).
- Phase 1: elan + Lean 4.31.0 installed; mathlib v4.31.0 resolved+cloned;
  hello_world + whole library compiles from source.
- Phase 2: ErdosStraus predicate (cleared ℕ form) + faithfulness check +
  north-star theorem stub.
- Phase 4: easy leaves proved (es_two, es_three, es_of_two, es_four_k_three, es_mod4).
- Phase 5: es_scale + es_of_primes + es_prime_of_core; open core isolated
  as the primes ≡ 1 (mod 4).

## Environment gotchas
- elan 4.2.3 at C:\Users\Dipan\.elan\bin (persistent user PATH).
- Native linking is blocked (ld.lld.exe, App Control policy 0x11C7). So:
  no `lake exe cache get`, no compiled executables. Oleans build fine.
- Long commands run as detached background jobs via scripts/*.ps1; poll
  with scripts/status.ps1 -Tag <setup|build|audit>.
- git identity passed per commit with -c user.name/user.email (no global
  config touched).
