# Iteration 2: Loop Fission — SMALL_DATASET

## Status: OPEN — 21/30 MATCH (not re-run; carried from iteration 1)

| Parameter | Value |
|---|---|
| Transform | `fissionGeneric.ts` → `LoopFissionPass` |
| Dataset | SMALL_DATASET |
| Last run | 2026-06-12 (iteration 1) |

Fission was not re-run in this iteration. Results and benchmark-level analysis
are recorded in the original experiment at
[`../../fission-small-dataset/analysis.md`](../../fission-small-dataset/analysis.md).

## Mismatch overview (from iteration 1)

All 9 failures are loop-carried dependencies: fission moves the producing
statement into one loop and the consuming statement into a separate loop, but
the consumer needs the producer's value from a previous iteration of the same
outer loop, not the current one.

| Benchmark | Loop structure | Dependency / Failure type | Effect |
|---|---|---|---|
| `trisolv` | outer `i`, 3 stmts | Loop-carried: `x(j)` read before divided | NaN |
| `cholesky` | outer `i`, 2 stmts | Loop-carried: `a(j,j)` used before `sqrt` | Wrong factors |
| `symm` | outer `i`, 2 stmts | Symmetric pair split into independent loops | Wrong values |
| `lu` | inner loop nest | Loop-carried: pivot row not finalized | Wrong LU |
| `ludcmp` | inner loop nest | Loop-carried: pivot row not finalized | Wrong LU |
| `gramschmidt` | outer `k`, 2 stmts | Loop-carried: un-normalized `q` used in later k | Wrong GS |
| `adi` | outer `t`, 2 stmts | Intra-step: row/col sweeps coupled | Wrong ADI |
| `fdtd-2d` | outer `t`, 4 stmts | Intra-step: `hz` depends on step-t `ex`/`ey` | Wrong FDTD |
| `fdtd-apml` | outer `t`, 4 stmts | Intra-step: same as `fdtd-2d` | Wrong FDTD |

## Open issues

`LoopFissionPass` has no legality check. A sound check requires detecting
loop-carried read-after-write dependencies: if statement B reads a value that
statement A writes, and A's write at iteration `i` is needed by B at iteration
`i` (same outer iteration, not `i-1`), splitting them is safe. If B at iteration
`i` needs A's value from an iteration `i' < i` (loop-carried), fission is illegal.

This requires at minimum a reaching-definition analysis across loop iterations —
more complex than the purely syntactic checks that fixed fusion and interchange.
