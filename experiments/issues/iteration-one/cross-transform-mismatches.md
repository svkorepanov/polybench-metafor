# Cross-Transform Mismatch Overview — SMALL_DATASET

All correctness failures observed across fission, fusion, and interchange
experiments. Each row gives the benchmark, which loop structure was targeted,
the root dependency or legality issue, and the observable effect.

| Transform | Benchmark | Loop structure | Dependency / Failure type | Effect |
|---|---|---|---|---|
| **Fission** | `trisolv` | outer `i`, 3 stmts | Loop-carried: `x(j)` read before divided | NaN |
| **Fission** | `cholesky` | outer `i`, 2 stmts | Loop-carried: `a(j,j)` used before `sqrt` | Wrong factors |
| **Fission** | `symm` | outer `i`, 2 stmts | Symmetric pair split into independent loops | Wrong values |
| **Fission** | `lu` | inner loop nest | Loop-carried: pivot row not finalized | Wrong LU |
| **Fission** | `ludcmp` | inner loop nest | Loop-carried: pivot row not finalized | Wrong LU |
| **Fission** | `gramschmidt` | outer `k`, 2 stmts | Loop-carried: un-normalized `q` used in later k | Wrong GS |
| **Fission** | `adi` | outer `t`, 2 stmts | Intra-step: row/col sweeps coupled | Wrong ADI |
| **Fission** | `fdtd-2d` | outer `t`, 4 stmts | Intra-step: `hz` depends on step-t `ex`/`ey` | Wrong FDTD |
| **Fission** | `fdtd-apml` | outer `t`, 4 stmts | Intra-step: same as `fdtd-2d` | Wrong FDTD |
| **Fusion** | `atax` | two inner `j`-loops | Flow dep: `tmp(i)` partial when `y(j)` reads it | Wrong y vector |
| **Fusion** | `doitgen` | two outer `p`-loops | WAR: `a(p)` written before s-loop finishes reading it | Wrong matrix product |
| **Fusion** | `gemver` | four outer `i`-loops | Flow dep (×2): partial A when x reads it; partial x when w reads it | Wrong x and w |
| **Interchange** | `reg_detect` | `(j, i)` with `i = j, maxgrid` | Triangular inner bound → outer `do i = j` with undefined `j` | Garbage output |
| **Interchange** | `covariance` | `(j1, j2)` with `j2 = j1, m` | Triangular inner bound → outer `do j2 = j1` with undefined `j1` | Segfault |
| **Interchange** | `trmm` | `(i, j)` rectangular, nested `k=1..i-1` | Evaluation order change: `b(k,j)` has extra accumulations from prior `j` iterations | Wrong triangular product |

## Pattern summary

| Category | Transforms affected | Common cause |
|---|---|---|
| **Producer–consumer split** | Fission | Fission runs the producing loop to completion for ALL outer iterations before the consumer starts, breaking loop-carried read chains |
| **Incomplete-producer merge** | Fusion | Fusion interleaves a loop that is still accumulating with a loop that consumes the final result, exposing partial intermediate values |
| **Undefined bound variable** | Interchange | The inner loop's bound expression references the outer loop variable; after swap, that variable is out of scope in the new outer loop |
| **Evaluation order violation** | Interchange, Tiling | Rectangular bounds make the transform syntactically valid, but the body has a triangular inner dependency (`k < i`) whose correctness relies on a specific outer iteration order |

## See also

- Detailed per-benchmark analysis: [`../fission-small-dataset/analysis.md`](../fission-small-dataset/analysis.md)
- Detailed per-benchmark analysis: [`../fusion-small-dataset/analysis.md`](../fusion-small-dataset/analysis.md)
- Detailed per-benchmark analysis: [`../interchange-small-dataset/analysis.md`](../interchange-small-dataset/analysis.md)
- Tiling mismatches (trmm, reg_detect): [`../tiling-tile32-small-dataset/analysis.md`](../tiling-tile32-small-dataset/analysis.md)
