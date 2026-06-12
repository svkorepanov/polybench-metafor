# Experiment: Loop Fission — SMALL_DATASET

## Setup

| Parameter | Value |
|---|---|
| Transform | `fissionGeneric.ts` → `LoopFissionPass()` |
| Dataset | `SMALL_DATASET` (128×128 for most kernels) |
| Compiler | `flang-22 -O3 -fopenmp` |
| Platform | Linux 6.17.0, x86_64 |
| Date | 2026-06-12 |
| Branch | `fix/emitter-paren-binop` |

## Bug fix required before running

`LoopFissionPass._findLoops` and `LoopFusionPass._findAllFusableSets/_findFusableSets`
both iterate `$jp.children` directly. The staging branch includes `attributeSpecifier`
nodes with null Java backing objects, causing a NullPointerException during traversal.
Fix applied: wrap `$jp.children` in `try/catch` in all three methods, same pattern as
the existing fix in `LoopUnrollPass`.

## How to reproduce

```bash
# From polybench-metafor/
./preproc.sh
./compile.sh && ./execute.sh          # baseline
./weave-transpiler.sh fissionGeneric  # transform
./compile.sh && ./execute.sh          # woven
./compare.sh
```

## Results summary

| Category | Count | Benchmarks |
|---|---|---|
| MATCH — correct output | 21 | see below |
| MISMATCH — dependency violation | 9 | `trisolv`, `cholesky`, `symm`, `lu`, `gramschmidt`, `ludcmp`, `adi`, `fdtd-2d`, `fdtd-apml` |

## Mismatch summary

| Benchmark | Fissioned loop | Dependency type | What goes wrong |
|---|---|---|---|
| `trisolv` | outer `i` → 3 loops | Loop-carried forward-substitution: loop 2 reads `x(j)` before loop 3 divides it | NaN output throughout |
| `cholesky` | outer `i` → 2 loops | Loop-carried pivot: inner j-loop uses `a(j,j)` before the sqrt in loop 2 has been applied | Wrong Cholesky factors |
| `symm` | outer `i` → 2 loops | Symmetric pair: `c(i,j)` and `c(j,i)` updates separated into independent loops | Wrong symmetric values |
| `lu` | inner loop nest | Loop-carried pivot: multiplier row not finalized before update loop runs in next iteration | Wrong LU factors |
| `ludcmp` | inner loop nest | Same as `lu` | Wrong LU factors |
| `gramschmidt` | outer `k` → 2 loops | Loop-carried normalization: un-normalized `q` column used in later k iterations | Wrong orthogonalization; 6350× artifact (bad data computed fast) |
| `adi` | outer `t` → 2 t-loops | Intra-step coupling: row/column sweeps depend on each other within the same time step | Wrong ADI propagation |
| `fdtd-2d` | outer `t` → 4 t-loops | Intra-step field coupling: `hz` update depends on step-t `ex`/`ey`, not step-(t-1) | Wrong wave propagation |
| `fdtd-apml` | outer `t` → 4 t-loops | Same as `fdtd-2d` | Wrong wave propagation |

## Correctness analysis

Loop fission splits a loop with multiple body statements into one loop per
statement. This is semantically correct **only if** no statement reads a
value written by another statement in a different iteration (no loop-carried
anti-dependencies or output dependencies). `LoopFissionPass` does not check
legality — it applies fission unconditionally to any loop with ≥2 body
statements. The 9 mismatches all have loop-carried or intra-iteration
dependencies that fission violates.

### Mismatch cases

#### `trisolv` — loop-carried dependency through forward-substituted `x(j)`

```fortran
! Original (correct):
do i = 1, n
  x(i) = c(i)
  do j = 1, i-1
    x(i) = x(i) - (a(j,i) * x(j))   ! reads x(j), j < i
  end do
  x(i) = x(i) / a(i,i)              ! writes back divided value
end do

! After fission (wrong):
do i = 1, n; x(i) = c(i); end do
do i = 1, n
  do j = 1, i-1
    x(i) = x(i) - (a(j,i) * x(j))  ! x(j) is un-divided — division happens in loop 3
  end do
end do
do i = 1, n; x(i) = x(i) / a(i,i); end do
```

Loop 2 reads `x(j)` (j < i) which was already divided in the original code.
After fission, loop 2 runs before loop 3 (the division), so `x(j)` contains
the initialized-but-not-divided value, producing NaN (0/0) output.

#### `cholesky` — `a(j,j)` used before `sqrt` is applied

The outer `i`-loop body contains: inner j-loop that uses `a(j,j)` (the pivot
already processed by a prior i-iteration), then `a(i,i) = sqrt(a(i,i))`.
Fission splits these into two outer loops. In the first outer loop (j-loop),
`a(j,j)` is used for all `i` before any sqrt is applied (sqrt happens in the
second outer loop), so the diagonal elements appear as unsquare-rooted values.

#### `symm` — coupled update of symmetric pairs

The kernel writes `c(i,j)` and `c(j,i)` in a coordinated way within the same
loop body. Fission separates the two writes into independent loops, breaking
the symmetry invariant. Result: catastrophically wrong values.

#### `lu` and `ludcmp` — pivot row used before it is finalized

LU decomposition updates row i using the already-updated columns k < i. Fission
separates the "compute multiplier" and "update row" steps into distinct loops.
In the multiplier loop for i=3, column k=2 hasn't been finalized yet (that
happens in the update loop later), producing wrong multipliers.

#### `gramschmidt` — norm computed and applied in separate loops

The kernel computes `nrm = sum(r(k,i)^2)` then normalizes `q(j,i) /= nrm`.
After fission these are two separate outer loops: all norms are computed first,
then all normalizations. If later k values depend on already-normalized q-columns
(as Gram-Schmidt requires), the un-normalized q values produce wrong orthogonality.
The "speedup" of 6350× is an artifact: the fissioned kernel completes faster
because its inner loops do less useful work (computing with wrong data).

#### `adi` — row and column sweeps are tightly coupled

ADI splits the time derivative into alternating row (i) and column (j) implicit
sweeps. Each sweep reads from the prior sweep's output within the same time step.
Fission separates the two sweeps into independent t-loops, so sweep 2 uses only
the initial-condition values for sweep 1, not the intra-step updated values.

#### `fdtd-2d` and `fdtd-apml` — intra-step field coupling

The FDTD time-step loop contains 4 body statements: set boundary, update `ey`,
update `ex`, update `hz`. After fission, these become 4 separate `t`-loops.
`hz` in the original code depends on the within-step updated `ex` and `ey`;
after fission, `hz` in time step t reads `ex`/`ey` from time step t-1, not
the just-computed step-t values, producing wrong wave propagation.

```
Original:  DO t → [ey_bc, ey_update, ex_update, hz_update]  (hz uses step-t ex/ey)
Fissioned: DO t → ey_bc; DO t → ey_update; DO t → ex_update; DO t → hz_update
                                                              ↑ uses step-(t-1) ex/ey
```

## Transform? column

The `compare.sh` `Transform?` column shows `NO` for all fission results.
Fission creates new loops with the same 2-argument `DO var = lo, hi` form — no
step argument, no OMP directives — so neither the `OMP` nor `TILED` heuristics
trigger. This is a known limitation of the current detection logic; it does not
mean fission was unapplied. A correct detection would count `DO` statements in
the woven file vs the original and mark `FISSIONED` when the count increased.

## 21 benchmarks that match correctly

Benchmarks where fission is applied and produces correct output are those whose
loop bodies consist of independent statements (no loop-carried dependencies):

| Category | Benchmarks |
|---|---|
| Dense linear algebra (rectangular, independent updates) | `gemm`, `syr2k`, `syrk`, `2mm`, `3mm`, `doitgen`, `gemver`, `trmm`, `mvt`, `gesummv`, `atax`, `bicg` |
| Solvers without pivot coupling | `durbin`, `dynprog` |
| Stencils with independent axes | `jacobi-1d-imper`, `jacobi-2d-imper`, `seidel-2d` |
| Data mining | `correlation`, `covariance` |
| Medley | `floyd-warshall`, `reg_detect` |

For most of these benchmarks, fission produces a structurally valid but
semantically equivalent transformation — the split loops compute the same
result as the original because statements are already independent.

## Speedup

All 21 matching benchmarks show ~1.00× speedup at SMALL_DATASET. Fission's
performance benefit comes from improved cache locality when split loops access
different arrays — only relevant when data exceeds cache, i.e., at LARGE_DATASET.
At SMALL_DATASET the working set fits in L2, so fission adds overhead (more
loop-entry/exit overhead per nest) without any reuse benefit.

## Current limitation of LoopFissionPass

`LoopFissionPass` has no legality check. It applies fission to any loop with
≥2 body statements without examining whether statements share dependencies.
A correct implementation would require:
1. Build a use-def graph for the loop body
2. Check for output dependencies (write-after-write), anti-dependencies
   (write-after-read across iterations), and true dependencies (read-after-write
   across iterations)
3. Only fission if the chosen partition is dependency-free

Adding a legality check would reduce the MATCH count from 21 to fewer but make
the applied transformations semantically correct.

## Cross-transform mismatch overview (SMALL_DATASET)

All mismatches observed across fission, fusion, and interchange experiments
grouped by benchmark and failure type.

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

**Pattern summary**:
- Fission failures are all **producer–consumer splits**: one loop produces a value that the next loop needs, but fission lets the first loop run to completion for ALL outer iterations before the consumer loop starts, breaking loop-carried read-after-write chains.
- Fusion failures are **incomplete-producer merges**: the first loop hasn't finished producing (across all iterations) when the fused second loop starts reading.
- Interchange failures are either **undefined bound variables** (inner bound copies outer variable name verbatim) or **evaluation order violations** in triangular accumulations.

## Next experiments

1. **Fission at LARGE_DATASET** — repeat for the 21 correct benchmarks to measure
   cache-separation speedup on memory-bound kernels.
2. **Fusion at SMALL_DATASET** — run `fusionGeneric` and compare; fusion is the
   inverse transform and should be safe for more benchmarks (merging is always
   legal if loop bounds match; only performance matters).
3. **Fission legality check** — add dependency analysis to `LoopFissionPass` to
   avoid the 9 mismatches (future fortran-transpiler work).
