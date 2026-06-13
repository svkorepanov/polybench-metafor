# Iteration 3 — Issue Analysis

Third pass: implements tiling legality checks and records the resolution with
concrete code examples showing what the transpiler produces and why each illegal
pair is blocked.

## Contents

| File | Transform | Result | State |
|---|---|---|---|
| `tiling-analysis.md` | Tiling | **30/30** | Resolved |
| `tiling-results.txt` | raw compare.sh output | — | — |

## Progress since iteration 2

| Transform | Iter 2 | Iter 3 | Delta |
|---|---|---|---|
| Tiling | 28/30 | **30/30** | +2 (Check 1 + Check 2 in `canTile()`) |
| Interchange | 30/30 | — | carried resolved |
| Unrolling | 30/30 | — | carried resolved |
| Fusion | 30/30 | — | carried resolved |
| Fission | 21/30 | — | not addressed |

## Fix summary

Extended `canTile()` in `src-api/code/LoopTiling.ts` with two checks (same patterns
as `canInterchange()`), using word-boundary regex to avoid false positives:

- **Check 1** — Triangular inner bound: reject if inner loop's lower or upper bound
  contains the outer loop variable as a whole word.
- **Check 2** — Nested loop in body references outer var: reject if any descendant
  loop inside the inner body has a bound containing the outer loop variable.

## Open issues carried into iteration 4

1. **Fission** — 9 benchmarks: requires loop-carried dependency analysis. No fix planned.
