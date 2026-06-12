# Experiment: Loop Interchange — SMALL_DATASET

## Setup

| Parameter | Value |
|---|---|
| Transform | `interchangeGeneric.ts` (manual, no pass class) |
| Dataset | `SMALL_DATASET` (128×128 for most kernels) |
| Compiler | `flang-22 -O3 -fopenmp` |
| Platform | Linux 6.17.0, x86_64 |
| Date | 2026-06-12 |
| Branch | `fix/emitter-paren-binop` |
| Baseline | Restored from `experiments/baseline-small-dataset/` (no baseline re-run needed) |

## How to reproduce

```bash
# Restore saved baseline (skips re-running originals)
find . -maxdepth 4 -name "*.output.txt" ! -path "*/woven_code/*" ! -path "*/experiments/*" | while read f; do
    bench=$(basename "$(dirname "$f")")
    cp "experiments/baseline-small-dataset/${bench}.output.txt" "$f"
done

./weave-transpiler.sh interchangeGeneric
./compile.sh

# Run only woven exes (baseline already in place)
find . -path "*/woven_code/*.exe" | while read exe; do
    dir=$(dirname "$exe"); base=$(basename "$exe" .exe)
    "$exe" > "$dir/$base.output.txt" 2>&1
done

./compare.sh
```

## Results summary

| Category | Count | Benchmarks |
|---|---|---|
| MATCH — correct output | 27 | all except the three below |
| MISMATCH — triangular bounds | 2 | `reg_detect`, `trmm` |
| MISMATCH — segfault (undefined outer bound) | 1 | `covariance` |

## What `interchangeGeneric` does

The script (`src-api/examples/interchangeGeneric.ts`) finds all top-level 2-deep
perfect loop nests inside `kernel_*` subroutines, then emits new code that swaps
the outer and inner `DO` controls while keeping the body unchanged:

```typescript
const newCode = [
  `do ${ic.code}`,   // original inner control becomes outer
  `do ${oc.code}`,   // original outer control becomes inner
  ...innerBody,
  `end do`,
  `end do`,
].join("\n");
outer.insert("replace", newCode);
```

It does **not** check whether the inner control's bounds reference the outer
variable (triangular bounds). It also does not perform any dependence analysis.

## Mismatch summary

| Benchmark | Interchanged pair | Root cause | Effect |
|---|---|---|---|
| `reg_detect` | `(j, i)` where inner is `do i = j, maxgrid` | Triangular inner bound copied verbatim → outer becomes `do i = j, maxgrid` with `j` undefined | Garbage loop count, wrong output (1516× artifact) |
| `covariance` | `(j1, j2)` where inner is `do j2 = j1, m` | Triangular inner bound → outer becomes `do j2 = j1, m` with `j1` undefined | Segfault |
| `trmm` | `(i, j)` — both bounds constant | Evaluation order change: nested `k=1..i-1` reads `b(k,j)` values that have been through extra accumulation rounds from prior `j`-outer iterations | Numerically wrong triangular product |

## Mismatch cases

### `reg_detect` — undefined outer variable after interchange

```fortran
! Original:
do j = 1, maxgrid
  do i = j, maxgrid   ! inner lower bound = j (outer variable)
    do cnt = 1, length
      diff(cnt, i, j) = sumTang(i, j)
    end do
  end do
end do

! After interchange (wrong):
do i = j, maxgrid     ! j is undefined here → undefined behavior
  do j = 1, maxgrid
    do cnt = 1, length
      diff(cnt, i, j) = sumTang(i, j)
    end do
  end do
end do
```

`ic.code` is `"i = j, maxgrid"` (copied verbatim from the inner control). After
interchange, this becomes the outer loop, but `j` no longer names a loop variable
at that scope. The runtime reads garbage from the stack for `j`, making the outer
loop run an arbitrary number of times with wrong bounds. The "1516× speedup"
artifact means the loop completes nearly instantly rather than doing useful work.

### `covariance` — segfault from undefined outer variable

```fortran
! Original:
do j1 = 1, m
  do j2 = j1, m    ! inner lower bound = j1 (outer variable)
    symmat(j2, j1) = 0.0D0
    do i = 1, n
      symmat(j2, j1) = symmat(j2, j1) + (dat(j1, i) * dat(j2, i))
    end do
    symmat(j1, j2) = symmat(j2, j1)
  end do
end do

! After interchange (wrong):
do j2 = j1, m     ! j1 is undefined → garbage loop bounds → segfault
  do j1 = 1, m
    ...
  end do
end do
```

Same pattern as `reg_detect`. `j1` is uninitialized when used as `j2`'s lower
bound, producing a segfault when the garbage value causes an out-of-bounds array
access inside the loop.

### `trmm` — changed evaluation order breaks triangular accumulation

```fortran
! Original:
do i = 2, ni          ! ← outer
  do j = 1, ni        ! ← inner
    do k = 1, i - 1   ! k-loop bounds use outer variable i
      b(j, i) = b(j, i) + alpha * a(k, i) * b(k, j)
    end do
  end do
end do

! After interchange:
do j = 1, ni          ! ← outer (was inner)
  do i = 2, ni        ! ← inner (was outer)
    do k = 1, i - 1
      b(j, i) = b(j, i) + alpha * a(k, i) * b(k, j)
    end do
  end do
end do
```

The interchange of `(i, j)` is syntactically valid: `k = 1, i-1` still uses the
current inner variable `i` correctly. However, the computation is semantically
incorrect. In the original, for each value of `i`, the entire `j = 1..ni` range
updates `b(*, i)` before moving to `i+1`. The body reads `b(k, j)` for `k < i`.

In the original, `b(k, j)` for `k < i` is a value that was finalized by earlier
**i** iterations. Specifically, `b(k, j)` = `b(j=k, i=j)` as written in outer
iteration `i=j`. Because i advances monotonically and `k < i`, this finalized
value is always available before it is read.

After interchange, `j` is the outer variable. Within j's iteration, all `i` values
run their k-loops. For a fixed `j=X`, iteration `i=5, k=1` reads `b(1, X)`. This
value was last written by the `j=1` outer iteration (specifically at `i=X, k=1`).
But `j=1` ran ALL its `i` values (2..ni), including `i=X`, before `j=X` started.
So `b(1, X)` as seen at `(j=X, i=5, k=1)` has been modified by the full triangular
accumulation in `j=1`'s inner loop — one extra round of updates compared to what
the original intended. The result is numerically wrong output (not NaN or infinity,
but incorrect floating-point values throughout the matrix).

**Key distinction from reg_detect/covariance**: the bounds of the interchanged
pair `(i, j)` are both constant (`i = 2, ni`; `j = 1, ni`). The interchange is
syntactically valid. The semantic error comes from the data dependence through
`b(k, j)` combined with the triangular inner loop: the correct computation
requires `b(k, j)` to have been written by exactly `k-1` prior updates when
it is read, but after interchange it has been written `k-1 + extra` times.

## Why 27 other benchmarks match (including other triangular-structured kernels)

Benchmarks like `trisolv` (`do j = 1, i-1`) and `cholesky` (inner loops with
triangular bounds) **match** because their innermost triangular loop is **not**
the direct inner of a 2-deep perfect nest that the script targets. The script
only interchanges the top-level 2-deep pair. For `trisolv`, the outer loop has
a body that is not a single DO statement (the j-loop and the division statement
coexist), so no 2-deep perfect nest is found and nothing is interchanged. For
kernels whose top-level pair has rectangular constant bounds, the interchange
is legal and produces correct output.

## Transform? column

Interchange produces 2-argument `DO` loops (no step, no OMP directives), so
`compare.sh` reports `Transform?=NO` for all benchmarks, even those where the
interchange was applied. This is a known limitation of the detection heuristic.

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
- Fission failures are all **producer–consumer splits**: fission runs the producing loop to completion for ALL outer iterations before the consumer starts, breaking loop-carried chains.
- Fusion failures are **incomplete-producer merges**: the first loop hasn't finished producing when the fused second loop starts reading, exposing partial intermediate results.
- Interchange failures are either **undefined bound variables** (inner bound copies outer variable name verbatim) or **evaluation order violations** in triangular accumulations.

## Summary: MATCH counts across all 5 transforms (SMALL_DATASET)

| Transform | MATCH | MISMATCH | Root cause of failures |
|---|---|---|---|
| Tiling (tile=32) | 28/30 | 2 | Triangular bounds (trmm, reg_detect) |
| Unrolling (factor=4) | 30/30 | 0 | — |
| Fission | 21/30 | 9 | Loop-carried dependencies (solvers, stencils) |
| Fusion | 27/30 | 3 | Flow deps requiring full prior-loop completion |
| **Interchange** | **27/30** | **3** | Triangular bounds / undefined outer variable |

## Next experiments

1. **Interchange at LARGE_DATASET** — for the 27 correct benchmarks, measure
   stride improvement from column-major → row-major access patterns on
   matrix kernels (e.g., `gemm`, `syrk`, `symm`).
2. **Legality check** — filter out pairs where `ic.code` references the outer
   variable name before applying interchange.
3. **Tile + interchange** — tile first (producing `ii/jj` outer loops with
   rectangular bounds), then interchange the inner `i/j` pair to improve
   locality within tiles.
