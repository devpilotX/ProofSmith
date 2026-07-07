# devpilotX — Formal Methods & Smart Contract Security

This repository hosts three independent research projects, each on its own
branch. The `main` branch (here) is the **ProofSmith** project. The other
two projects live as orphan branches with no shared history.

## Projects

| Branch | Project | What it does |
|--------|---------|-------------|
| `main` | **ProofSmith** | Lean 4 formal proof reducing the Erdős–Straus conjecture to a single open family |
| `vault-verify` | **VaultVerify** | ERC-20 vault reentrancy audit — safe vs buggy, P1/P2/P3 proven with Halmos + Foundry |
| `vault-guard` | **VaultGuard** | ERC-4626 inflation attack audit — naive vs hardened vault, I1–I4 + INF proven/tested |

---

## ProofSmith (this branch)

ProofSmith attacks the **Erdős–Straus conjecture**: for every integer
n ≥ 2 there are positive integers x, y, z with

    4/n = 1/x + 1/y + 1/z

Done in Lean 4 on top of mathlib. The conjecture is not solved — it is
still open. What this repo delivers is a full, gap-free, kernel-checked
reduction of the whole conjecture down to one open family: the primes
p ≡ 1 (mod 4). No hidden `sorry`, no surprise axiom.

### What is proved

| Lemma | Status |
|-------|--------|
| es_of_two, es_two, es_three | PROVED |
| es_scale, es_four_k_three, es_mod4 | PROVED |
| es_of_primes, es_prime_of_core | PROVED |
| erdos_straus_of_core | PROVED |
| OpenCore (primes p ≡ 1 mod 4) | OPEN |
| erdos_straus (full conjecture) | REDUCED to OpenCore |

### Build

    lake build ProofSmith

Axiom audit (confirms no hidden gap):

    lake env lean ProofSmith/Audit.lean

Toolchain auto-installs from `lean-toolchain` (`leanprover/lean4:v4.31.0`).

### Layout

    ProofSmith/ErdosStraus/Defs.lean      predicate, base cases, es_of_two
    ProofSmith/ErdosStraus/Scale.lean     es_scale
    ProofSmith/ErdosStraus/Residue.lean   es_four_k_three, es_mod4
    ProofSmith/ErdosStraus/Reduction.lean es_of_primes, OpenCore, north-star
    ProofSmith/Audit.lean                 #print axioms for every lemma
    docs/                                 target selection, decomposition, report
    PROGRESS.md                           full state — read this first

---

## VaultVerify (branch: `vault-verify`)

A minimal ERC-20 deposit/withdraw vault audited for three safety properties.
Shows a concrete reentrancy exploit on a buggy vault and proves the safe
vault resists it.

**Toolchain:** Foundry forge 1.5.1, solc 0.8.24, Halmos 0.3.3, z3 4.12.6.0

**Properties:**
- P1 Solvency: vault token balance ≥ sum of all user balances
- P2 No theft: a user cannot withdraw more than they deposited
- P3 No tampering: one user's action cannot change another's balance

**Results:**

| Property | Safe vault | Buggy vault |
|----------|-----------|-------------|
| P1 Solvency | PROVEN (Halmos) + TESTED (Foundry invariant) | FAILED (exploit + Halmos counterexample) |
| P2 No theft | PROVEN (Halmos) + TESTED (Foundry invariant) | FAILED (10 in, 110 out) |
| P3 No tampering | PROVEN (Halmos) + TESTED (Foundry fuzz) | not the broken property |

**Reproduce:**

    forge test
    python -m halmos --contract VaultHalmosTest    # safe: 5/5 PASS
    python -m halmos --contract BuggyHalmosTest    # buggy: FAIL

---

## VaultGuard (branch: `vault-guard`)

Two ERC-4626-style vaults — naive and hardened (OpenZeppelin virtual-offset
fix) — audited against an inflation / donation / first-depositor attack.

**Toolchain:** Foundry forge 1.7.1, solc 0.8.24, Halmos 0.3.3, z3 4.12.6.0

**Properties:**
- I1 Solvency: totalAssets() ≥ redeem value of all shares
- I2 No round-trip profit: deposit then redeem never returns more than put in
- I3 Rounding direction: share math always rounds in the vault's favour
- I4 No share theft: only owner/approved spender can move or burn shares
- INF Inflation resistance: the donation attacker cannot profit

**Results:**

| Property | Naive vault | Hardened vault |
|----------|-------------|----------------|
| I1 Solvency | PROVEN (Halmos, <2^64) + TESTED | TESTED |
| I2 No round-trip profit | TESTED | TESTED |
| I3 Rounding direction | TESTED | TESTED |
| I4 No share theft | PROVEN (Halmos, <2^64) + TESTED | PROVEN (Halmos, <2^64) + TESTED |
| INF Inflation resistance | FAILED (exploit + Halmos counterexample) | TESTED (fuzz 20 000 runs + worked example) |

**Reproduce:**

    forge test
    python -m halmos --contract NaiveVaultHalmosTest
    python -m halmos --contract HardenedVaultHalmosTest

---

## Honesty gate (all projects)

- **PROVEN** = a symbolic tool (Halmos / Lean kernel) verified it for all
  inputs in the stated bounds. No counterexample exists in that range.
- **TESTED** = fuzzing or invariant runs passed. That is sampling, not a proof.
- **FAILED** = a counterexample or working exploit was found, inputs shown.
- **OPEN** = not yet proved, not yet disproved.

Nothing is called PROVEN because fuzzing passed.
