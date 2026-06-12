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

## Summary table across all transforms (SMALL_DATASET)

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
