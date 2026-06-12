# Iteration 2: Loop Fusion — SMALL_DATASET

## Status: OPEN — 27/30 MATCH (unchanged from iteration 1)

| Parameter | Value |
|---|---|
| Transform | `fusionGeneric.ts` → `LoopFusionPass` |
| Dataset | SMALL_DATASET |
| Date | 2026-06-12 |
| Transpiler commit | `967e893` |

## Changes since iteration 1

`LoopFusionPass` itself is unchanged. `fusionGeneric.ts` was updated in `967e893`
to print `FUSED` / `SKIPPED` based on `result.appliedPass`, enabling the
`.transform-status` marker written by `weave-transpiler.sh` (YES = transform
applied; NO = no eligible consecutive loops found). The three failure patterns
are documented in
[`../iteration-one/fusion-legality-analysis.md`](../iteration-one/fusion-legality-analysis.md)
but the legality checks have not yet been implemented. This run confirms the
issue set is stable with the new YES/NO markers.

## Result

| Category | Count | Benchmarks |
|---|---|---|
| MATCH | 27 | all except the three below |
| MISMATCH | 3 | `gemver`, `doitgen`, `atax` |

## Open issues

| Benchmark | Fused loops | Failure pattern | Legality check needed |
|---|---|---|---|
| `atax` | Two inner `do j = 1, ny` | Check A: reduction `tmp(i)` not complete — written inside inner loop with subscript = outer var only | Write depth > 1 + pure outer-var subscript |
| `doitgen` | Two outer `do p = 1, np` | Check C: write-back `a(p)` before inner s-loop finishes reading `a(s)` | Scalar write at outer level in B; ranged read in A's inner loop |
| `gemver` | Four outer `do i = 1, n` | Check B (×2): A updated column-by-column while x reads row-by-row; x built incrementally while w reads it fully | Write `X(w,v)` in A, read `X(v,w)` in B |

## Raw results

See `fusion-results.txt` in this folder.
