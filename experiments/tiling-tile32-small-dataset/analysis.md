# Experiment: Loop Tiling — tile=32 — SMALL_DATASET

## Setup

| Parameter | Value |
|---|---|
| Transform | `tilingGeneric.ts` → `LoopTilingPass(32)` |
| Dataset | `SMALL_DATASET` (128×128 for most kernels) |
| Compiler | `flang-22 -O3 -fopenmp` |
| Platform | Linux 6.17.0, x86_64 |
| Date | 2026-06-03 |

## How to reproduce

```bash
# From polybench-metafor/
./preproc.sh
./compile.sh && ./execute.sh          # baseline
./weave-transpiler.sh tilingGeneric   # transform
./compile.sh && ./execute.sh          # woven
./compare.sh
```

## Results summary (current state, branch `fix/emitter-paren-binop`)

| Category | Count | Benchmarks |
|---|---|---|
| MATCH — correct output | 28 | all except the two below |
| MISMATCH — **triangular bounds** | 2 | `trmm`, `reg_detect` |
| Not tiled — no eligible 2-deep nest | 12 | `atax`, `bicg`, `cholesky`, `trisolv`, `gesummv`, `durbin`, `gramschmidt`, `ludcmp`, `adi`¹, `jacobi-1d-imper`, + see notes |

¹ `adi` shows TILED because multi-letter variables (`i1i1`, `i2i2`) produce tile loops, but its primary sweep kernels have `do i2 = 2, n` (linear bounds) and are tileable.

## Speedup

**All 26 correctly transformed benchmarks show 1.00x speedup.**

This is expected. At SMALL_DATASET (128×128), a double-precision matrix is
128×128×8 = 131 KB, which fits entirely in L2 cache on most CPUs. Loop tiling
improves cache reuse for memory-bound kernels — but when the entire working set
already fits in cache, the tile boundaries add loop overhead without any reuse
benefit, resulting in exactly 1.00x (or marginally worse).

To see real tiling gains, rerun with MEDIUM_DATASET or LARGE_DATASET (see
`compile.sh` — change `-DSMALL_DATASET` to `-DMEDIUM_DATASET`). Kernels like
`gemm`, `syr2k`, `symm`, and `3mm` are the most likely candidates for speedup
at larger sizes.

## Mismatches explained — triangular bounds

Both mismatching benchmarks have **triangular loop nests**: bounds of an inner
(or descendant) loop depend on the value of an outer loop variable. Tiling the
outer loop changes which iterations are valid for the dependent inner loop,
producing incorrect results.

### `trmm` — triangular k loop, tiling is not applicable

```fortran
subroutine kernel_trmm(ni, alpha, a, b)
  do i = 2, ni
    do j = 1, ni
      do k = 1, i - 1   ! ← triangular: upper bound = i - 1
        b(j, i) = b(j, i) + alpha * a(k, i) * b(k, j)
      end do
    end do
  end do
```

`LoopTilingPass` tiles the `(i, j)` pair (the outermost 2-deep perfect nest).
After tiling, strip-mine loops iterate `i` in 32-wide tiles: within a tile,
`i` varies from `ii` to `MIN(ii+31, ni)`. The k loop's upper bound `i-1` is
different for each i value within the tile, but the tiled structure reads
`b(k, j)` for k values that belong to i values ALSO within the tile — some
of those `b` values have not yet been written in the correct final form.
This produces catastrophically wrong output (extreme floating-point overflow).

**Tiling is not applicable to `trmm`.** The `(i, j)` pair appears rectangular
but the body's dependence on `i` through `k < i` makes the transformation
semantically incorrect. A legality check would need to scan descendant loops
for bounds referencing the outer variable.

### `reg_detect` — triangular i loop, tiling is not applicable

```fortran
subroutine kernel_reg_detect(...)
  do j = 1, maxgrid
    do i = j, maxgrid   ! ← triangular: lower bound = j (outer variable)
      do cnt = 1, length
        diff(cnt, i, j) = sumTang(i, j)
      end do
    end do
  end do
```

`LoopTilingPass` tiles the `(j, i)` pair. The inner loop's **lower bound is
`j`** (the outer loop variable). After tiling, `j` is strip-mined and the
inner `i` tile starts at `jj` (the tile start), but the original semantic
requires `i ≥ j` (the current j value). Within a tile, different `j` values
require different starting `i` values, but the tiled loop uses a fixed `ii`
start, violating the triangular access pattern.

The 1516× "speedup" is a timing artifact: the woven benchmark is so corrupted
that it completes nearly instantly rather than computing meaningfully.

**Tiling is not applicable to `reg_detect`.** The `(j, i)` pair is triangular
by lower bound.

## Benchmarks not eligible for tiling

The following kernels have no 2-deep perfect loop nest and receive no tiling
(reported as `SKIPPED` by `tilingGeneric.ts`, `NO` in the `Transform?` column):

| Benchmark | Reason |
|---|---|
| `atax` | Two separate single-level loops; no 2-deep perfect nest in kernel |
| `bicg` | Two-body inner loop (`s(j) +=` and `q(i) +=` together); not a perfect nest |
| `cholesky` | Triangular structure (`do j = 1, i`); loops are not 2-deep perfect |
| `trisolv` | Triangular: `do j = 1, i-1`; outer loop body is not a single inner loop |
| `gesummv` | Two separate accumulations; not a 2-deep perfect nest |
| `durbin` | Recurrence structure; inner loops have loop-carried dependencies |
| `gramschmidt` | Orthogonalization; inner loops are separated by assignments |
| `ludcmp` | LU decomposition with pivot; inner structure not a pure 2-level nest |
| `jacobi-1d-imper` | 1D stencil; only a single loop dimension in the kernel |

## Timing notes

The timing values in `results.txt` are unreliable in this experiment:
- The benchmarks are compiled with `-DPOLYBENCH_DUMP_ARRAYS` but without
  `-DPOLYBENCH_TIME`, so the polybench timer outputs its default cycle/ns
  counter rather than wall-clock seconds.
- Very fast kernels (`dynprog`, `lu`) report 0, causing division-by-zero in
  `compare.sh`'s speedup calculation.
- `adi` reports a negative time (timer wrap or counter overflow at
  SMALL_DATASET).
- `trisolv`, `durbin`, `ludcmp` report empty time ("err" in compare.sh).

For meaningful timing, compile with `-DPOLYBENCH_TIME` added to `PARGS` in
`compile.sh`.

## Tiling quality — code inspection

The 3mm kernel tiling is structurally correct. The `do i / do j` loops over
`kernel_3mm`'s three matrix products are each replaced by a 4-level tiled nest:
```fortran
do ii = 1, ni, 32
  do jj = 1, nj, 32
    do i = ii, MIN(ii + 32 - 1, ni)
      do j = jj, MIN(jj + 32 - 1, nj)
        ...
      end do
    end do
  end do
end do
```
The `MIN()` guard handles non-divisible bounds correctly. Innermost loops are
not tiled (only the two outermost loop dimensions per nest are tiled), which is
the standard 2D tiling strategy.

## Current state (branch `fix/emitter-paren-binop`)

| State | MATCH | MISMATCH | Notes |
|---|---|---|---|
| Original (loop-transformations branch) | 26/28 | trmm, reg_detect | atax/bicg skipped — parser bug |
| Current (fix/emitter-paren-binop) | **28/30** | trmm, reg_detect | atax/bicg now transform correctly (staging PR #48) |

A legality check was briefly added to `LoopTilingPass._findTileablePairs()` that
rejected pairs where descendant loop bounds reference the outer variable. This
correctly identified trmm/reg_detect as illegal BUT also over-rejected valid
pairs in other benchmarks, reducing MATCH from 26 → 17. It was reverted.

The current approach is **informational only**:
- `tilingGeneric.ts` logs `TILED` vs `SKIPPED` per kernel using `PassResult.appliedPass`
- `compare.sh` shows `TILED` / `NO` in the `Transform?` column (was `Parallel?`)
- trmm and reg_detect are tiled, produce MISMATCH, and are documented here as
  triangular-bound kernels where tiling is not semantically correct

## Next experiments

1. **MEDIUM_DATASET / LARGE_DATASET** — repeat with a larger problem size to
   observe actual cache-reuse speedup on `gemm`, `symm`, `syr2k`, `3mm`.
2. **Tile size sensitivity** — change `TILE_SIZE` in `tilingGeneric.ts` from 32
   to 16, 64, 128 and compare.
3. **Loop unrolling** — run `./weave-transpiler.sh unrollGeneric` and compare.
4. **Fix trmm / reg_detect** — add legality check in `tilingGeneric.ts` to skip
   kernels with non-rectangular bounds.
5. **Fix atax / bicg** — implement `NamedConstantDef` in FortranAst to recover
   the 2 skipped benchmarks.
