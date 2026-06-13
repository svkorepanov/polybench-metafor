# Iteration 2 — Issue Analysis

Second pass: runs all four active transforms against SMALL_DATASET to measure
progress after the `LoopInterchangePass` implementation. Fission is carried
from iteration 1 without re-running.

## Contents

| File | Transform | Result | State |
|---|---|---|---|
| `interchange-analysis.md` | Interchange | **30/30** | Resolved |
| `unroll-analysis.md` | Unrolling | **30/30** | Resolved (unchanged) |
| `tiling-analysis.md` | Tiling | 28/30 | Open (`reg_detect`, `trmm`) |
| `fusion-analysis.md` | Fusion | **30/30** | Resolved |
| `fission-analysis.md` | Fission | 21/30 | Open (carried from iter 1) |
| `interchange-results.txt` | raw compare.sh output | — | — |
| `tiling-results.txt` | raw compare.sh output | — | — |
| `fusion-results.txt` | raw compare.sh output | — | — |
| `unroll-results.txt` | raw compare.sh output | — | — |

## Progress since iteration 1

| Transform | Iter 1 | Iter 2 | Delta |
|---|---|---|---|
| Interchange | 27/30 | **30/30** | +3 (all 3 fixed by `canInterchange()`) |
| Unrolling | 30/30 | **30/30** | — |
| Tiling | 28/30 | 28/30 | — (same 2 open) |
| Fusion | 27/30 | **30/30** | +3 (Check A/B/C in `_canFusePair`) |
| Fission | 21/30 | 21/30 | — (not re-run) |

## Open issues carried into iteration 3

1. **Tiling** — `reg_detect` and `trmm`: same structural patterns as interchange
   failures (triangular inner bound; nested loop in body uses outer variable).
   Detection rules are identical to `canInterchange()` checks. Fix: add a
   `canTile()` guard that mirrors those two checks.

2. **Fission** — 9 benchmarks: requires loop-carried dependency analysis,
   which is more complex than syntactic checks. No fix planned for iteration 3.
