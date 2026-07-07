# PROGRESS — VaultVerify

Read this first. State lives in files, not memory.

## Mission
Build a minimal ERC-20 Vault (deposit/withdraw) and verify three safety
properties, then a buggy reentrancy version the tooling catches.

- P1 Solvency: token balance of the vault >= sum of all user balances.
- P2 No theft: a user cannot withdraw more than they deposited.
- P3 No tampering: one user's action cannot change another's balance.

Honesty gate: PROVEN = a symbolic tool (Halmos) verified it for all
inputs in stated bounds. TESTED = fuzzing/invariants passed but did not
prove it. FAILED = counterexample found, show the input.

## Toolchain (pinned, all confirmed running here)
- Foundry forge 1.5.1-stable (commit b0a9dd9), from prebuilt Windows zip.
- solc 0.8.24 (managed by forge).
- Halmos 0.3.3, z3-solver 4.12.6.0 (pip, see requirements.txt).
- Python 3.14.6. forge/solc/halmos/z3 all execute (no App Control block).

## How to run
- Build:   forge build
- Fuzz/invariant tests (TESTED):  forge test
- Symbolic proofs (PROVEN):       python -m halmos --contract <Name>
  (halmos.exe is at %LOCALAPPDATA%\Python\pythoncore-3.14-64\Scripts,
   not on PATH, so use `python -m halmos`.)
- Long runs go through scripts/bg.ps1 (reads _bg_<tag>.cmd) + poll with
  scripts/status.ps1 -Tag <tag>, to dodge single-command timeouts.

## Phase status
- Phase 1 DONE: tooling installed + pinned, trivial contract compiles,
  trivial fuzz + halmos symbolic check both pass. Pipeline proven.
- Phase 2 DONE: src/IERC20.sol, src/MockERC20.sol (plain ERC20),
  src/Vault.sol (safe, deposit=transferFrom-then-credit,
  withdraw=debit-then-transfer). Compiles clean (lint_on_build off).
- Phase 3 DONE: test/VaultHalmos.t.sol (check_ symbolic) + test/VaultInvariant.t.sol (invariant + fuzz).
- Phase 4 DONE (safe vault): forge TESTED + halmos PROVEN for P1/P2/P3.
- Phase 5 DONE: BuggyVault + ReentrantToken + Attacker. Concrete exploit
  drains buggy vault; halmos finds solvency counterexample; safe vault
  resists. Full forge suite green (6/6); buggy halmos check = FAIL.
- Phase 6 DONE: docs/REPORT.md written (property table, tools, exploit
  walkthrough, fix, limits). Project complete.
- Phase 3: P1/P2/P3 as Foundry invariant tests AND halmos symbolic tests.
- Phase 4: run fuzz, then halmos; record PROVEN/TESTED/FAILED.
- Phase 5: buggy reentrancy Vault, same checks, show FAILED + exploit.
- Phase 6: docs/REPORT.md audit write-up.

## Status table (safe vault verified; buggy vault pending Phase 5)
| Property | Safe vault | Tool | Buggy vault | Tool |
|----------|-----------|------|-------------|------|
| P1 solvency | PROVEN + TESTED | halmos + forge invariant | FAILED | halmos counterexample + exploit test |
| P2 no theft | PROVEN + TESTED | halmos + forge invariant | FAILED | exploit test (10 in, 110 out) |
| P3 no tampering | PROVEN + TESTED | halmos + forge fuzz | not broken by this bug | n/a |

Buggy vault: halmos check_P1_solvency_buggy = [FAIL], counterexample
victimDep = atkUnit = 2^95. Concrete exploit test_exploitDrainsBuggyVault:
victim deposits 100, attacker deposits 10 and re-enters 10x, attacker
walks away with 110, vault holds 0 against 100 recorded. Safe vault
resists the identical attack. The bug breaks P1 and P2; P3 is about the
balanceOf mapping, which reentrancy never cross-writes.

halmos safe run: 5 checks passed, 0 failed (check_P1_solvency_deposit/
withdraw, check_P2_noTheft, check_P3_noTampering_deposit/withdraw).
forge: invariant_P1_solvency + invariant_P2_conservation (16384 calls,
0 reverts) + testFuzz_P3_noTampering all pass.

## Next action
Done. All six phases complete. To re-verify: forge test (TESTED),
python -m halmos --contract VaultHalmosTest (PROVEN, safe),
python -m halmos --contract BuggyHalmosTest (FAILED, buggy).
