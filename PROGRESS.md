# PROGRESS — VaultGuard

Read this first. State lives in files, not memory.

## Mission
Build a naive ERC-4626-style vault and a hardened one, show the inflation
/ donation / first-depositor attack steals from the naive vault, and show
the hardened vault (virtual shares/assets offset, the OpenZeppelin fix)
kills the attack. Check four safety properties on both with Foundry
(fuzz/invariant) and Halmos (symbolic).

Properties:
- I1 Solvency: totalAssets() >= assets backing all shares.
- I2 No round-trip profit: deposit then immediate withdraw/redeem never
  returns more than was put in.
- I3 Rounding direction: deposits round shares down, redeem rounds assets
  down, mint/withdraw round the vault's way. No value extracted by rounding.
- I4 No share theft: only a share owner or an approved spender can move or
  burn shares.
- INF (the differentiator): the inflation attacker cannot profit. This is
  the property the naive vault breaks and the offset fixes.

## Honesty gate
- PROVEN = Halmos verified it for ALL inputs within the stated bounds.
- TESTED = fuzz/invariant passed but did NOT prove it.
- FAILED = a counterexample or working exploit was found, inputs shown.
Never call TESTED a PROVEN. State every bound.

## Toolchain (pinned, all confirmed running here)
- Foundry forge 1.7.1 (commit 4072e487), prebuilt Windows zip, sha256
  verified, at C:\Users\Dipan\foundry\bin (NOT on PATH for fresh shells,
  prepend it).
- solc 0.8.24 (managed by forge).
- Halmos 0.3.3, z3-solver 4.12.6.0 (pip, see requirements.txt).
- Python 3.14.6. forge/solc/halmos/z3 all execute, no App Control block.

## How to run
- prepend forge:  $env:Path = "C:\Users\Dipan\foundry\bin;" + $env:Path
- build:          forge build
- fuzz/invariant (TESTED):  forge test
- symbolic (PROVEN/FAILED): python -m halmos --contract <Name>
- long halmos runs go through scripts\bg.ps1 (writes _bg_<tag>.cmd, launch
  detached, poll with scripts\status.ps1 -Tag <tag>) to dodge timeouts.

## Phase status
- Phase 1 DONE: toolchain pinned + verified, trivial contract compiles.
- Phase 2 DONE: vaults built, only the 4 conversion fns differ.
- Phase 3 DONE: I1-I4 + INF as Foundry tests (VaultProperties.t.sol,
  InflationAttack.t.sol) AND halmos checks (VaultHalmos.t.sol).
- Phase 4 DONE: fuzz + halmos run, results locked (table below).
- Phase 5 DONE: test_inflationAttackStealsDeposit passes, victim loses the
  whole 10000e18 deposit.
- Phase 6 DONE: hardened re-run, attack fails (attacker loses ~5000e18,
  victim recovers 99.97%), properties still hold.
- Phase 7 DONE: docs/REPORT.md written.

## Results (locked)
Foundry: all 13 tests pass. invariant_I1_solvency + invariant_I4_share
Conservation (256 runs, 16384 calls, 0 reverts) on both vaults. testFuzz_
I2/I3/I4 (512 runs) on both. test_inflationAttackStealsDeposit pass.
test_hardenedResistsInflation pass. testFuzz_hardenedAttackerNeverProfits
(20000 runs) pass.

Halmos:
- Naive: I1 PROVEN (<2^64), I4 PROVEN (<2^64), I2 timeout, I3 timeout,
  INF FAILED (counterexample, profit found).
- Hardened: I4 PROVEN (<2^64), I1/I2/I3/INF all timeout (INF still timed
  out at bound 2^16 with 300s).

Honest table (PROVEN only where halmos verified):
| Prop | Naive | Hardened |
| I1   | PROVEN<2^64 + TESTED | TESTED |
| I2   | TESTED | TESTED |
| I3   | TESTED | TESTED |
| I4   | PROVEN<2^64 + TESTED | PROVEN<2^64 + TESTED |
| INF  | FAILED (exploit + halmos) | TESTED (fuzz 20000 + example) |

The lesson: I1-I4 hold on BOTH vaults. The inflation attack is only caught
by INF. Hardened INF is TESTED, not PROVEN, because the nonlinear mulDiv
times out in z3. We do not fake PROVEN.

## Next action
Project complete for this pass. Everything committed. To re-verify:
forge test, then python -m halmos --contract NaiveVaultHalmosTest and
--contract HardenedVaultHalmosTest.
