# Iteration 2: Loop Interchange — SMALL_DATASET

## Status: RESOLVED — 30/30 MATCH

| Parameter | Value |
|---|---|
| Transform | `interchangeGeneric.ts` → `LoopInterchangePass` |
| Dataset | SMALL_DATASET |
| Date | 2026-06-12 |
| Transpiler commit | `76ded39` |

## Changes since iteration 1

Iteration 1 used a manual string-based interchange script with no legality check
(27/30, three mismatches). Iteration 2 introduces `LoopInterchangePass` built on
`FortranJoinPoints` factory methods and two legality guards:

| Check | What it catches |
|---|---|
| **Check 1** — triangular inner bound | Inner loop's lower/upper bound contains the outer variable name → outer becomes undefined after swap |
| **Check 2** — nested loop in body uses outer variable in its bounds | Body contains a `do k = 1, i-1` loop → evaluation-order violation when i moves to inner position |

An additional implementation detail: LARA wraps each AST node in a fresh JavaScript
proxy on every access, so the `innerSet` deduplication that avoids interchanging inner
pairs of 3-deep nests keys on **loop variable name** rather than JS object identity.

## Result

| Category | Count | Benchmarks |
|---|---|---|
| MATCH | 30 | all |
| MISMATCH | 0 | — |

All three previously-failing benchmarks are now correctly skipped:

| Benchmark | Reason skipped |
|---|---|
| `reg_detect` | Check 1: inner `do i = j, maxgrid` — bound contains outer var `j` |
| `covariance` | Check 1: inner `do j2 = j1, m` — bound contains outer var `j1` |
| `trmm` | Check 2: pair `(i, j)` is outermost; body of `j` contains `do k = 1, i-1` — bound contains outer var `i`. Additionally, the `innerSet` key fix prevents `(j, k)` from being interchanged in isolation |

## Raw results

See `interchange-results.txt` in this folder.
