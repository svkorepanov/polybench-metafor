# ADI Segfault Analysis — !$omp tile sizes(32,32) with Non-Canonical Loop Bounds

## Summary

`adi.omp-tile.exe` crashes with a segfault at runtime when compiled with
`-fopenmp-version=51`. The other three benchmarks (2mm, 3mm, trisolv) run fine.

## Root Cause

Flang-22's incomplete OMP 5.1 `tile` implementation only handles loops in
**canonical form**: `do i = 1, n` (lower bound = 1, step = 1, constant upper bound).

All 4 tile sites in `kernel_adi` violate this:

| Tile site | Problematic bound |
|---|---|
| `do i2 = 2, n` | lower bound = 2, not 1 |
| `do i2 = 1, n - 2` | upper bound = `n-2`, not `n` |
| `do i1 = 2, n` | lower bound = 2, not 1 |
| `do i1 = 1, n - 2` | upper bound = `n-2`, not `n` |

When flang generates tiled code for a loop like `do i2 = 2, n`, it appears to
treat the lower bound as 1, producing incorrect tile index calculations that
access memory out of bounds at runtime.

## Evidence

Comparison of loop bounds at each tile site across benchmarks:

- **2mm** (no crash): all tiled loops are `do i = 1, ni` / `do j = 1, nj` — canonical
- **3mm** (no crash): all tiled loops are `do i = 1, ni` / `do j = 1, nj` etc. — canonical
- **trisolv** (no crash): uses `sizes(32)` (1D tile) on outer loop `do i = 1, n` only;
  the inner loop `do j = 1, i - 1` is non-canonical but is not tiled
- **adi** (crash): every `!$omp tile sizes(32,32)` site has at least one loop with
  a lower bound of 2 or an upper bound of `n - 2`

## Fix Options

1. **Normalize loop bounds** before applying the tile directive — substitute
   `i2' = i2 - 1` so the loop becomes `do i2p = 1, n-1`, then adjust array
   indices inside the body accordingly.
2. **Skip tiling** on loops with non-unit lower bounds or non-constant upper
   bounds until flang's OMP 5.1 support matures.
3. **Use a different tiling strategy** (e.g. the manual strip-mine approach
   already used in the transpiler-generated woven code) which is not subject
   to this compiler limitation.
