# Iteration 2: Loop Unrolling — SMALL_DATASET

## Status: RESOLVED — 30/30 MATCH (unchanged from iteration 1)

| Parameter | Value |
|---|---|
| Transform | `unrollGeneric.ts` → `LoopUnrollPass(4)` |
| Dataset | SMALL_DATASET |
| Date | 2026-06-12 |
| Transpiler commit | `76ded39` |

## Changes since iteration 1

No changes to `LoopUnrollPass`. Unrolling was already 30/30 in iteration 1
after the `parenExpr` wrapping fix for compound bounds and reverse-index bodies.
This run confirms the pass remains correct.

## Result

| Category | Count | Benchmarks |
|---|---|---|
| MATCH | 30 | all |
| MISMATCH | 0 | — |

No open issues.

## Raw results

See `unroll-results.txt` in this folder.
