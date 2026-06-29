# Phase 3 — Decomposition and proof strategies

The target splits into a small directed acyclic graph of lemmas. Proving
the leaves and the structural lemmas reduces the whole conjecture to one
open node. Arrows point from a lemma to what it depends on.

## Dependency graph

    erdos_straus  (north-star, ∀ n≥2, ErdosStraus n)   [REDUCED, sorry on OpenCore]
      └─ erdos_straus_of_core                          [PROVED]
           ├─ es_of_primes                             [PROVED]
           │    ├─ es_scale                            [PROVED]
           │    └─ Nat.minFac / minFac_prime / minFac_dvd   (library)
           └─ es_prime_of_core                         [PROVED]
                ├─ es_two                              [PROVED]   (p = 2)
                ├─ es_mod4                             [PROVED]   (p ≡ 3 mod 4)
                │    └─ es_four_k_three                [PROVED]
                │         └─ es_of_two                 [PROVED]
                └─ OpenCore                            [OPEN]     (p ≡ 1 mod 4)

    es_three  [PROVED]  — independent sanity identity, not on the critical
                          path (p = 3 is already covered by es_mod4).

How the leaves imply the root: `erdos_straus_of_core` takes `OpenCore`
and produces the full statement by composing `es_of_primes` (kills all
composites and reduces to primes) with `es_prime_of_core` (handles every
prime except the open family). So once `OpenCore` is closed, the root is
closed, with no other gap. That is exactly what the `#print axioms`
output confirms: only `erdos_straus` carries `sorryAx`.

## Node table: statement, status, dependencies, strategy

| Node | Statement | Status | Depends on | Strategy |
|------|-----------|--------|-----------|----------|
| es_of_two | `4ab = n(a+b)` ⟹ `ErdosStraus n` | PROVED | predicate | construct witnesses `a, b+1, b(b+1)`; the split `1/b = 1/(b+1)+1/(b(b+1))` becomes the factor `(b+1)^2`; close by `ring` |
| es_two | `ErdosStraus 2` | PROVED | predicate | explicit witnesses `1,2,2`; `decide` |
| es_three | `ErdosStraus 3` | PROVED | predicate | explicit witnesses `1,4,12`; `decide` |
| es_scale | `ErdosStraus n` ⟹ `ErdosStraus (n·m)`, `m>0` | PROVED | predicate | construct witnesses `xm, ym, zm`; factor `m^3`; rewrite by hypothesis; `ring` |
| es_four_k_three | `ErdosStraus (4k+3)` | PROVED | es_of_two | reduce to a 2-term identity with `a=k+1, b=(4k+3)(k+1)`; `ring` |
| es_mod4 | `n%4=3` ⟹ `ErdosStraus n` | PROVED | es_four_k_three | rewrite `n = 4(n/4)+3` by `omega`; apply leaf |
| es_of_primes | `(∀ prime p, ES p)` ⟹ `∀ n≥2, ES n` | PROVED | es_scale, minFac API | take least prime factor `p=n.minFac`, write `n=p·m`, scale `4/p` by `m` |
| es_prime_of_core | `(∀ prime p≡1[4], ES p)` ⟹ `∀ prime p, ES p` | PROVED | es_two, es_mod4 | case split: `p=2`, or `p` odd with `p%4∈{1,3}` by `omega` |
| erdos_straus_of_core | `OpenCore` ⟹ `∀ n≥2, ES n` | PROVED | es_of_primes, es_prime_of_core | compose the two reductions |
| OpenCore | `∀ prime p, p%4=1 → ES p` | OPEN | — | the frontier (see next-attempt memo in REPORT.md) |
| erdos_straus | `∀ n≥2, ES n` | REDUCED | erdos_straus_of_core, OpenCore | `sorry` stands exactly for `OpenCore` |

## Strategy library used here
- construction of a witness (es_two, es_three, es_of_two, es_scale, es_four_k_three)
- algebraic identity verified by `ring` over the commutative semiring ℕ
- reduction to a known library theorem (es_of_primes uses `Nat.minFac`)
- case split (es_prime_of_core on parity and residue mod 4)
- reduction of a general residue statement to a parametric leaf (es_mod4)
- generic decision procedure for closed arithmetic (`decide`) and for
  linear integer goals with div/mod (`omega`)

## Strategies considered and not used (yet)
- A residue closure for `p ≡ 2 (mod 3)` would shrink the open core from
  `p ≡ 1 (mod 4)` to `p ≡ 1 (mod 12)`. The clean two-term trick that
  works for mod 4 does not drop out for mod 3, so it is left for later
  (see REPORT.md failure log and next-attempt memo).
