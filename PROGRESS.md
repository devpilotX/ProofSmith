# PROGRESS — ProofSmith

Read this first, every session. State lives in files, not memory.

## Target
Erdős–Straus conjecture: for every integer n >= 2, there are positive
integers x, y, z with 4/n = 1/x + 1/y + 1/z.

Proof assistant: Lean 4 + mathlib (via elan + lake).

## Current phase
Phase 1 — environment setup. Toolchain installed. Next: create the lake
project, depend on mathlib, fetch the cache, compile a hello-world lemma.

## What is machine-verified so far
Nothing yet. No Lean files compiled. The ledger is empty.

## Status ledger (will fill as lemmas land)
| Lemma | Statement (short) | Status |
|-------|-------------------|--------|
| (none yet) | | |

## Environment notes
- elan 4.2.3 at C:\Users\Dipan\.elan\bin, on the persistent user PATH.
- No toolchain installed yet. elan auto-fetches the one mathlib pins via
  the lean-toolchain file once the project exists.
- git repo initialized on branch main.
- Long commands (lake exe cache get, lake build) must run as a background
  job with polling. A single foreground call will time out.

## Next action
1. lake new / lake init a project named ProofSmith, add mathlib require.
2. Run lake exe cache get in the background, poll until done.
3. Build a trivial lemma (hello world) to prove the pipeline runs.
4. Then Phase 2: formalize the ErdosStraus predicate + north-star stub.

## Done so far
- Phase 0: target selection written in docs/PHASE0_TARGET_SELECTION.md.
  Three candidates analyzed (Erdős–Straus, Collatz, Frankl). Picked
  Erdős–Straus on tractability times significance.
- Phase 1 (partial): elan toolchain installed and verified.
