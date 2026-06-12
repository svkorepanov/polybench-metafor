# Iteration 2: Loop Tiling — SMALL_DATASET

## Status: OPEN — 28/30 MATCH (unchanged from iteration 1)

| Parameter | Value |
|---|---|
| Transform | `tilingGeneric.ts` → `LoopTilingPass(32)` |
| Dataset | SMALL_DATASET |
| Date | 2026-06-12 |
| Transpiler commit | `967e893` |

## Changes since iteration 1

No changes to `LoopTilingPass`. The two failures are structural: both benchmarks
have loop nests where the outermost 2-deep pair passes `canTile()` (both loops
are unit-step range loops) but the transformation is semantically incorrect due
to triangular access patterns. The tiling legality check was reverted in a prior
commit; this run confirms the regression is still present.

## Result

| Category | Count | Benchmarks |
|---|---|---|
| MATCH | 28 | all except the two below |
| MISMATCH | 2 | `reg_detect`, `trmm` |

## Open issues

| Benchmark | Tiled pair | Failure pattern | Legality check needed |
|---|---|---|---|
| `reg_detect` | `(j, i)` where inner is `do i = j, maxgrid` | Triangular inner bound: tile replaces `i = j, maxgrid` with `i = ii, MIN(ii+32-1, maxgrid)` but the effective range starts from an expression involving `j`, not `ii` | Check: inner lower/upper bound contains outer variable name |
| `trmm` | `(i, j)` rectangular, body has `do k = 1, i-1` | Evaluation-order violation: tile strips the outer-first traversal guarantee; `b(k,j)` is read before earlier `i`-iterations have finished accumulating into it | Check: descendant loop in body references outer variable in its bounds |

Both are the same structural patterns as interchange failures: triangular bounds
and nested loops with outer-variable bounds. The detection rules documented in
[`../iteration-one/interchange-legality-analysis.md`](../iteration-one/interchange-legality-analysis.md)
apply identically to tiling.

## Raw results

See `tiling-results.txt` in this folder.
