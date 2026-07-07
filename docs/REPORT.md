# VaultVerify — audit report

A minimal ERC-20 vault, three safety properties, and proof that the
properties hold for the safe version and break for a buggy version. The
point of the report is the contrast: the same checks pass on one
contract and fail on the other, and the failure comes with a real
exploit.

## Honesty gate

Every property below carries exactly one label.

- PROVEN: a symbolic tool (Halmos) checked it for all inputs in the
  stated bounds. No counterexample exists in that range.
- TESTED: fuzzing or invariant testing passed, but that is sampling, not
  a proof. It did not prove the property.
- FAILED: a counterexample was found. The exact input is shown.

Nothing here is called PROVEN because fuzzing passed. Halmos is the only
thing that earns PROVEN.

## What was built

- `src/IERC20.sol` - the token interface.
- `src/MockERC20.sol` - a plain ERC-20 (no transfer hooks).
- `src/Vault.sol` - the SAFE vault. deposit/withdraw a single ERC-20.
- `src/BuggyVault.sol` - same interface, reentrancy bug in withdraw.
- `src/ReentrantToken.sol` - an ERC-777 style token that calls the
  recipient on transfer. This is what makes reentrancy reachable.

## Toolchain (pinned)

- Foundry forge 1.5.1-stable (commit b0a9dd9).
- solc 0.8.24.
- Halmos 0.3.3 with z3-solver 4.12.6.0 and yices 2.6.4 (see
  requirements.txt). Python 3.14.6.

Reproduce:

    forge build
    forge test                              # the TESTED runs
    python -m halmos --contract VaultHalmosTest   # the PROVEN runs (safe)
    python -m halmos --contract BuggyHalmosTest   # the FAILED run (buggy)

Note: the buggy halmos run needs a solver that Halmos fetches on first
use. If it asks to download yices, allow it with
`HALMOS_ALLOW_DOWNLOAD=1`.

## The three properties

Written against the vault's accounting, where `balanceOf[u]` is the
amount the vault records as owed to user `u`, and `token.balanceOf(vault)`
is the real token backing.

- P1 Solvency: `token.balanceOf(vault) >= sum of balanceOf[u]`, always.
  The vault can always cover everything it owes.
- P2 No theft: a user cannot withdraw more than they deposited. They
  cannot end with more tokens than they started.
- P3 No tampering: one user's deposit or withdraw does not change another
  user's recorded balance.

## Status table

| Property | Safe vault | Tool | Buggy vault | Tool |
|----------|-----------|------|-------------|------|
| P1 Solvency | PROVEN + TESTED | Halmos + Foundry invariant | FAILED | Halmos counterexample + exploit test |
| P2 No theft | PROVEN + TESTED | Halmos + Foundry invariant | FAILED | exploit test (10 in, 110 out) |
| P3 No tampering | PROVEN + TESTED | Halmos + Foundry fuzz | not the broken property | n/a |

## Safe vault: how each property was checked

Foundry (TESTED). `test/VaultInvariant.t.sol` drives random deposits and
withdraws across three actors.

- `invariant_P1_solvency`: 256 runs, 16384 calls, 0 reverts, passed.
- `invariant_P2_conservation`: recorded balances net exactly to deposits
  minus withdrawals. 256 runs, 16384 calls, passed.
- `testFuzz_P3_noTampering`: 256 runs, passed.

Halmos (PROVEN). `test/VaultHalmos.t.sol` uses symbolic amounts and a
symbolic actor, all bounded below 2^128 so sums cannot overflow. Result:
5 passed, 0 failed.

    check_P1_solvency_deposit    PASS
    check_P1_solvency_withdraw   PASS
    check_P2_noTheft             PASS
    check_P3_noTampering_deposit PASS
    check_P3_noTampering_withdraw PASS

So for the safe vault P1, P2, P3 are PROVEN (Halmos) and also TESTED
(Foundry). The Foundry runs agree with the proofs, which is a good smoke
signal but adds no proof strength.

## Buggy vault: the bug

`src/BuggyVault.sol`, withdraw:

    function withdraw(uint256 amount) external {
        uint256 bal = balanceOf[msg.sender];        // read into a stale local
        require(bal >= amount, "insufficient");
        require(token.transfer(msg.sender, amount), "transfer failed"); // interaction
        balanceOf[msg.sender] = bal - amount;        // effect, using stale bal
    }

Two mistakes, both classic:
1. Interaction before effect. The token transfer happens before the
   balance is updated.
2. The new balance is written from a stale local `bal` that was read
   before the external call.

With a plain ERC-20 this is harmless, because `transfer` never hands
control back. That is exactly why the plain-token symbolic and fuzz
checks do not flag it. The danger appears only when the token calls the
recipient back, which `ReentrantToken` does (a real ERC-777 feature).

## Exploit walkthrough

Setup: a victim deposits 100. The vault holds 100 tokens and records
`balanceOf[victim] = 100`.

1. Attacker deposits 10. Vault now holds 110, records
   `balanceOf[attacker] = 10`.
2. Attacker calls `withdraw(10)`.
   - `bal = 10`, check passes.
   - vault sends 10 tokens to the attacker. The token then calls the
     attacker's `tokensReceived` hook BEFORE the balance is written.
3. Inside the hook the attacker calls `withdraw(10)` again. The recorded
   balance is still 10 (not yet written), so the check passes again and
   another 10 tokens go out. The hook fires again. Repeat.
4. After 11 nested withdrawals the vault has paid out 110 tokens. As the
   stack unwinds, each frame writes `balanceOf[attacker] = bal - amount
   = 10 - 10 = 0`. No underflow, so nothing reverts.

Result: the attacker deposited 10 and walked away with 110. The vault
now holds 0 but still records `balanceOf[victim] = 100`. The victim
cannot withdraw. Solvency (P1) and no-theft (P2) are both broken.

This is `test/Reentrancy.t.sol::test_exploitDrainsBuggyVault`, and it
passes (the drain really happens). The same file's
`test_safeVaultResistsReentrancy` runs the identical attack against the
safe vault: the re-entrant withdraws revert because the balance was
already debited, the token hook swallows the revert, and the attacker
gets back only their own 10. The victim's 100 stays put.

## The tool catches it

Halmos, `test/BuggyHalmos.t.sol::check_P1_solvency_buggy`, runs the buggy
vault with the callback token and an attacker that re-enters once, with
symbolic victim and attacker amounts. It returns FAIL with a
counterexample:

    victimDep = 2^95
    atkUnit   = 2^95
    [FAIL] check_P1_solvency_buggy(uint256,uint256)

That is the symbolic version of the same finding: there exist amounts
where one re-entry already breaks solvency. The concrete exploit test is
the human-readable version with the numbers 100 / 10 / 110.

A note on honesty: if you run the safe-vault Halmos and Foundry checks
against the buggy vault but keep the plain `MockERC20`, they PASS. That
is not a contradiction. Those checks assume a token that does not call
back, so they cannot see reentrancy. The bug is only visible once the
threat model includes a callback token. That gap between "what the spec
assumed" and "what the token can do" is the whole lesson.

## The fix

Use checks-effects-interactions: update state before the external call,
and never write back a stale cached balance. The safe vault does this:

    function withdraw(uint256 amount) external {
        require(balanceOf[msg.sender] >= amount, "insufficient");
        balanceOf[msg.sender] -= amount;                 // effect first
        require(token.transfer(msg.sender, amount), "transfer failed"); // interaction last
    }

Now a re-entrant call during the transfer sees the already-reduced
balance and the check fails, so it cannot withdraw twice. A reentrancy
guard (a mutex modifier) would also work and is worth adding as defense
in depth, but correct ordering alone closes this hole, and Halmos proves
it for the safe vault.

## Limits of what was proven

- The Halmos proofs bound amounts below 2^128 (and 2^96 for the buggy
  search) so arithmetic cannot overflow 2^256. Overflowing inputs revert
  and are not the property under test.
- Solvency and tampering use two fixed, distinct users. That is enough to
  express both properties for these functions, which only ever touch the
  caller's own entry, but it is not an arbitrary-N proof.
- The proofs cover the deposit and withdraw flows of these specific
  contracts against the modeled tokens. They are not a statement about
  every possible ERC-20.
