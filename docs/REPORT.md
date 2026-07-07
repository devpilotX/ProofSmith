# VaultGuard — audit report

Two ERC-4626-style vaults, the inflation / donation / first-depositor
attack, and a set of safety checks run with both fuzzing and a symbolic
prover. The naive vault gets robbed. The hardened vault does not. The
point of the report is the contrast, and being straight about what was
actually proven versus only tested.

## Headline, one honest sentence

On the naive vault the inflation attack works and a victim loses their
whole deposit, shown both by a concrete exploit and by a Halmos
counterexample. The hardened vault (OpenZeppelin virtual-offset) stops it,
shown by a worked example and 20,000 fuzz runs, but NOT by a symbolic
proof, because the share math is nonlinear and the solver times out.

## Honesty gate

Every line in the status table carries exactly one label.

- PROVEN: Halmos checked it for ALL inputs inside the stated bound and
  found no counterexample. This is a proof, within that bound.
- TESTED: fuzzing or invariant runs passed. That is sampling, not a
  proof. Halmos either was not able to decide it in the time budget, or
  was not the tool used.
- FAILED: a counterexample or a working exploit was found. The inputs are
  shown.

Nothing here is called PROVEN because fuzzing passed. Only Halmos earns
PROVEN, and only inside the bound that is written next to it.

## Toolchain (pinned)

- Foundry forge 1.7.1, commit 4072e487, prebuilt Windows zip, sha256
  checked.
- solc 0.8.24, managed by forge.
- Halmos 0.3.3 with z3-solver 4.12.6.0. Python 3.14.6.
- forge-std v1.16.1.

Reproduce:

    forge test                                          # the TESTED runs
    python -m halmos --contract NaiveVaultHalmosTest    # naive symbolic
    python -m halmos --contract HardenedVaultHalmosTest # hardened symbolic

## What was built

- `src/IERC20.sol` and `src/MockERC20.sol` - a plain ERC-20 used as the
  underlying asset. No transfer hooks.
- `src/ERC4626Base.sol` - all the shared vault logic: the ERC-20 share
  accounting, deposit/mint/withdraw/redeem, access control, and the
  mulDiv rounding helpers.
- `src/NaiveVault.sol` - the vulnerable vault. `shares = assets * supply /
  totalAssets`, with a 1:1 rule when the vault is empty.
- `src/HardenedVault.sol` - the fix. Same vault, the only change is the
  conversion math adds a virtual offset: `shares = assets * (supply +
  10^offset) / (totalAssets + 1)`. Built with offset = 3.

The two vaults differ in four functions and nothing else. So any
difference in behavior comes from that math, not from anything around it.

## The properties

`totalAssets()` on both vaults is just `asset.balanceOf(vault)`. So a
direct token transfer into the vault (a donation) moves totalAssets with
no shares minted. That is the lever the attack pulls, and it is left in on
purpose for both vaults.

- I1 Solvency: `totalAssets()` is at least the redeem value of every share
  outstanding. The vault can pay everyone.
- I2 No round-trip profit: deposit, then immediately redeem the shares you
  got, and you never come out ahead.
- I3 Rounding direction: converting assets to shares and back never gains
  value, and the up-rounding previews (mint, withdraw) sit on the vault's
  side of the down-rounding converts (deposit, redeem).
- I4 No share theft: only a share owner or an approved spender can move or
  burn shares.
- INF Inflation resistance: the attacker in the donation attack cannot end
  up with more than they put in. This is the extra property, and it is the
  one that tells the two vaults apart.

## Status table

PROVEN bounds are written in the cell. "timeout" means Halmos ran but the
solver did not return inside the budget (60s per query on the naive run,
90s on the hardened run).

| Property | Naive vault | Hardened vault |
|----------|-------------|----------------|
| I1 Solvency | PROVEN (Halmos, amounts < 2^64) + TESTED (invariant, 16384 calls) | TESTED (invariant, 16384 calls). Halmos timeout | 
| I2 No round-trip profit | TESTED (fuzz 512). Halmos timeout | TESTED (fuzz 512). Halmos timeout |
| I3 Rounding direction | TESTED (fuzz 512). Halmos timeout | TESTED (fuzz 512). Halmos timeout |
| I4 No share theft | PROVEN (Halmos, amounts < 2^64) + TESTED (fuzz 512) | PROVEN (Halmos, amounts < 2^64) + TESTED (fuzz 512) |
| INF Inflation resistance | FAILED (Halmos counterexample + concrete exploit) | TESTED (fuzz 20000 + worked example). Halmos timeout |

Read this honestly:

- The four "standard" safety properties I1 to I4 hold on BOTH vaults. The
  inflation attack does not break solvency, does not break the rounding
  direction, does not steal shares, and is not a single-user round-trip
  profit. That is exactly why it is a sneaky bug. If you only check the
  usual invariants, the naive vault looks fine.
- The attack shows up only in INF, the economic property. INF FAILED on
  the naive vault and holds (TESTED) on the hardened one.
- Halmos PROVEN results are I1 and I4 on naive, and I4 on hardened. The
  rest of the symbolic checks timed out on the nonlinear mulDiv, so they
  are TESTED only. We do not upgrade those to PROVEN.

## The attack, with numbers (naive vault)

This is `test/InflationAttack.t.sol::test_inflationAttackStealsDeposit`,
and it passes, meaning the theft really happens. Token has 18 decimals.

Start: empty vault.

1. Attacker is the first depositor with 1 wei. The empty-vault rule mints
   1:1, so the attacker gets 1 share. Vault holds 1 wei, total supply is 1.
2. Attacker donates 10,000 tokens (10000e18) straight into the vault with
   a plain transfer. No shares minted. Now totalAssets = 10000e18 + 1,
   total supply is still 1. One share is now "worth" the whole pile.
3. Victim deposits 10,000 tokens. Their shares are
   `10000e18 * 1 / (10000e18 + 1)`, which floors to 0. The victim gets
   ZERO shares. Their 10,000 tokens are now sitting in the vault owned by
   nobody but the attacker's single share.
4. Attacker redeems their 1 share. It is the only share, so it is worth
   everything: 20000e18 + 1 tokens come out.

Result, straight from the test logs:

    attacker shares from 1 wei  : 1
    victim shares for 10000e18  : 0
    attacker spent (dep+donate) : 10000000000000000000001
    attacker got back           : 20000000000000000000001
    victim got back             : 0

The attacker spent 10000e18 + 1 and walked away with 20000e18 + 1. Profit
is exactly 10000e18, the victim's entire deposit. The victim holds 0
shares and recovers nothing.

Halmos found the same kind of break on its own,
`check_INF_attackerCannotProfit` on `NaiveVaultHalmosTest`, FAILED with
this counterexample (amounts bounded below 2^40):

    atkDeposit = 32609076096
    donation   = 441410692761
    victimDeposit = 569731158106

Run through the naive math, the attacker spends 474019768857 and gets back
474019768860, a profit of 3 wei. Tiny, but it is still the attacker ending
with more than they put in, which is all it takes to make INF false. The
solver picked an easy rounding profit. The concrete test is the same idea
turned up to a stolen 10,000 tokens.

## The fix, with numbers (hardened vault)

`src/HardenedVault.sol`, offset = 3, so virtual shares = 1000 and virtual
assets = 1. The conversion becomes:

    shares = assets * (totalSupply + 1000) / (totalAssets + 1)
    assets = shares * (totalAssets + 1) / (totalSupply + 1000)

There is no empty-vault special case. The +1000 and +1 keep the
denominator at least 1 and put virtual shares and a virtual asset between
the first depositor and the price. Those virtual shares belong to nobody,
so any donation is partly captured by the void.

Same attack, hardened vault, from
`test_hardenedResistsInflation` logs:

    attacker shares from 1 wei  : 1000
    victim shares for 10000e18  : 1999
    attacker spent (dep+donate) : 10000000000000000000001
    attacker got back           : 5001250312578144536134
    victim got back             : 9997499374843710927733

The victim is not zeroed out, they get 1999 shares. The attacker spent
about 10000e18 and got back about 5001e18, so the attack cost them about
4999e18. The victim redeems about 9997.5e18, which is 99.97% of their
deposit. The donation that was supposed to rob the victim got eaten by the
virtual shares and turned into the attacker's loss.

`testFuzz_hardenedAttackerNeverProfits` runs this scenario with 20,000
random parameter sets and the attacker never once comes out ahead.

## What Halmos could and could not cover

This is the part that matters for trusting the table.

- The vault uses `shares = assets * supply / totalAssets`. That is a
  multiplication of two unknowns divided by a third. Over 256-bit
  bitvectors that is nonlinear and z3 is slow on it.
- It went through on I1 for the naive vault, because after a single
  deposit the naive solvency check collapses to `dep * dep / dep <= dep`,
  which the solver handled in 0.13s. It also went through on I4 on both
  vaults, because no-share-theft is access control with almost no
  arithmetic (0.2 to 0.3s).
- It did NOT go through on I2, I3 on either vault, or on I1 and INF on the
  hardened vault. Those all timed out (60s per query on naive, 90s on
  hardened). The hardened math is worse because the offset makes the
  solvency relation quadratic in the deposit, `dep*1000*(dep+1) /
  (1000*(dep+1))`, instead of the naive `dep*dep/dep`.
- For the hardened INF property specifically, the headline fix, we tried
  hard to get a proof. We dropped the bound all the way to 2^16 and gave
  the solver 300s on the single query. It still timed out. So the hardened
  vault's inflation resistance is TESTED, not PROVEN. We are not going to
  call it PROVEN.

What that means for the claims:

- "The naive vault is vulnerable" is solid. It is shown by a concrete
  passing exploit and by an independent Halmos counterexample. FAILED is
  the strongest kind of result and it does not depend on any bound.
- "I1 solvency and I4 no-share-theft hold" are PROVEN for amounts below
  2^64, which is 18.4e18, about 18 tokens at 18 decimals. Above that the
  proof says nothing. Realistic balances can exceed 2^64, so this is a
  real limit. The fuzz and invariant runs go up to 1e30, which covers
  realistic sizes, but those are TESTED, not PROVEN.
- "The hardened vault stops the attack" is TESTED, not PROVEN. The
  evidence is the worked example, 20,000 fuzz runs with no attacker
  profit, and the standard OpenZeppelin argument that the virtual shares
  always take a cut of any donation. That is good evidence. It is not a
  proof. A real proof would need a solver that reasons about mulDiv
  symbolically, or a hand proof of the share-price monotonicity lemma that
  is out of scope here.

## Assumptions baked into the checks

- Every symbolic amount is assumed below a power of two (2^64 for I1 to I4,
  2^40 for the INF search) so that `a*b` cannot overflow 2^256. Overflowing
  inputs revert in Solidity 0.8 and are not the property under test.
- The asset is a plain, well-behaved ERC-20. No fee-on-transfer, no
  rebasing, no reentrancy. A weird token is a different threat model.
- The symbolic checks use fixed, distinct addresses (alice, bob, attacker,
  victim). That is enough to state these properties for functions that only
  ever touch the caller's own entry, but it is not an arbitrary-N argument.
- The hardened vault keeps `totalAssets() = balanceOf(vault)`, so donations
  still move the price. The defense is the virtual offset, not hiding the
  donation. A vault that instead tracks deposited assets internally would
  resist donations a different way, and is not what was tested here.

## The bottom line

The inflation attack is real and the naive vault loses a full deposit to
it. The four invariants people usually reach for do not catch it, which is
the actual lesson. The virtual-offset fix works in every test and every
worked example we ran. We could prove solvency and no-share-theft with
Halmos at bounded sizes, but we could not prove the inflation resistance
itself. That one stays TESTED, and saying otherwise would be the exact
kind of dishonesty the honesty gate is there to stop.
