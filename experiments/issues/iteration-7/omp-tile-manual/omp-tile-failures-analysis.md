# OMP Tile Failures Analysis — run-omp-tile-verify.sh

## Overview

Out of 29 benchmarks tested (fdtd-apml blacklisted), 6 fail when compiled/run
with `!$omp tile sizes(32,32)` under flang-22 `-fopenmp-version=51`.

| Benchmark | Failure mode | Category |
|---|---|---|
| covariance | Compile error | Triangular loop (variable trip count) |
| dynprog | Compile error | Triangular loop (variable trip count) |
| reg_detect | Compile error | Triangular loop (variable trip count) |
| trmm | Segfault | Non-canonical lower bound |
| adi | Segfault | Non-canonical lower/upper bounds |
| fdtd-2d | Segfault | Non-canonical lower/upper bounds |

---

## Category 1 — Compile Error: Variable Trip Count (Triangular Loops)

Flang rejects `!$omp tile` when the inner loop's trip count depends on the
outer loop's induction variable, because OpenMP 5.1 tile requires
loop-invariant (rectanglar) iteration spaces.

Error message:
```
error: Trip count must be computable and invariant
```

### covariance

```fortran
!$omp tile sizes(32,32)
do j1 = 1, m
  do j2 = j1, m     ! lower bound = j1 (outer variable)
```

Inner trip count = `m - j1 + 1` — shrinks with each step of `j1`.
Triangular iteration space; cannot be tiled into fixed-size rectangles.

### dynprog

```fortran
!$omp tile sizes(32,32)
do i = 1, length - 1
  do j = i + 1, length   ! lower bound = i + 1 (outer variable)
```

Inner trip count = `length - i` — shrinks with each step of `i`.
Same triangular structure as covariance.

### reg_detect (3 tile sites, all triangular)

```fortran
!$omp tile sizes(32,32)
do j = 1, maxgrid
  do i = j, maxgrid    ! lower bound = j (outer variable)
```

All three tile sites in `kernel_reg_detect` apply `sizes(32,32)` to a nest
where the inner loop starts at `j`, giving trip count `maxgrid - j + 1`.

---

## Category 2 — Segfault: Non-Canonical Loop Bounds

These benchmarks compile successfully because flang can compute the trip
count at compile time — but flang's incomplete OMP 5.1 tile code generation
does not correctly handle loops whose lower bound is not 1 or whose upper
bound is an expression like `n - 2`. The generated tile index arithmetic
uses the wrong offset, producing out-of-bounds memory accesses at runtime.

### trmm

```fortran
!$omp tile sizes(32,32)
do i = 2, ni        ! lower bound = 2, not 1
  do j = 1, ni      ! canonical
    do k = 1, i - 1 ! NOT tiled (3rd level), but body is data-dependent
```

Only `i` and `j` are tiled. Trip counts are `ni-1` and `ni` — computable,
so it compiles. At runtime, flang's tile code treats `i` as starting at 1
when computing tile indices, causing the first tile to access `b(*,1)` and
`a(*,1)` instead of `b(*,2)` / `a(*,2)`.

### adi (4 tile sites)

| Tile site | Violation |
|---|---|
| `do i2 = 2, n` | lower bound = 2 |
| `do i2 = 1, n - 2` | upper bound = n-2 (expression) |
| `do i1 = 2, n` | lower bound = 2 |
| `do i1 = 1, n - 2` | upper bound = n-2 (expression) |

Every tile site in `kernel_adi` violates canonicity. Trip counts are
`n-1` or `n-2` — computable, so compilation succeeds. The tile index
offset errors cause out-of-bounds writes into `x` and `b`.

(See also `adi-segfault-analysis.md` for earlier analysis of this benchmark.)

### fdtd-2d (3 tile sites)

```fortran
!$omp tile sizes(32,32)
do i = 2, nx        ! lower bound = 2
  do j = 1, ny

!$omp tile sizes(32,32)
do i = 1, nx
  do j = 2, ny      ! lower bound = 2

!$omp tile sizes(32,32)
do i = 1, nx - 1    ! upper bound = nx-1 (expression)
  do j = 1, ny - 1  ! upper bound = ny-1 (expression)
```

The first two sites have a lower bound of 2 on one loop each. The third
site has expression upper bounds on both loops. All three segfault for the
same offset-calculation reason as `trmm` and `adi`.

---

## Root Cause Summary

Flang-22's OMP 5.1 `tile` implementation has two distinct limitations:

1. **Compile-time check**: Rejects loops whose inner trip count is not
   loop-invariant (triangular nests). Correct behaviour per the spec.

2. **Code generation bug**: Accepts loops with non-unit lower bounds or
   expression upper bounds (trip count is computable), but generates
   incorrect tile index arithmetic that causes segfaults at runtime.
   The generated code appears to assume `lower = 1` when offsetting tile
   indices, so `do i = 2, n` is tiled as if it were `do i = 1, n-1`.

---

## Fix Options

### For triangular loops (covariance, dynprog, reg_detect)

- **Skip tiling** entirely on nests with data-dependent inner bounds.
  The transpiler's `tilingGeneric` already handles this correctly
  (it checks for perfect rectangular nests before tiling).
- **Loop splitting** — not practical for these kernels.

### For non-canonical bounds (trmm, adi, fdtd-2d)

- **Normalize loop bounds** before applying `!$omp tile`: replace
  `do i = lb, ub` with `do i = 1, ub-lb+1` and adjust array indices
  in the body by adding `lb-1`.
- **Wait for flang maturity** — the warning
  `OpenMP support for version 51 in flang is still incomplete`
  already signals that this path is not production-ready.
- **Use strip-mine manually** instead of `!$omp tile`, which gives
  full control over index arithmetic and is what `tilingGeneric`
  already does in the woven code.
