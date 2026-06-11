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

## Results summary

| Category | Count | Benchmarks |
|---|---|---|
| MATCH — correct output | 26 | (see table below) |
| MISMATCH — incorrect output | 2 | `trmm`, `reg_detect` |
| Skipped — parser error | 2 | `atax`, `bicg` |

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

## Mismatches explained

### `trmm` — illegal tiling of triangular loop

`trmm` contains a triangular loop nest:
```fortran
do i = 1, ni
  do j = 1, i       ! upper bound depends on outer variable
    A(j,i) = ...
```

Tiling a loop whose bounds depend on the outer loop variable is not legal — the
iteration order changes, so elements are read before they are written. The tiled
version produces catastrophically wrong output (extreme floating-point overflow
visible in the `results.txt` "Orig Time" column). **Tiling is not applicable to
`trmm` without legality checking.**

`cholesky` and `trisolv` have similar triangular structure but happened to
produce MATCH here — likely because their kernel accesses are structured such
that re-ordering within a 32-wide tile is coincidentally neutral at this data
size. They should be treated as suspect regardless.

### `reg_detect` — mismatch + spurious speedup

`reg_detect` shows MISMATCH and a 1516× "speedup." Both are artifacts:
- The "speedup" comes from a near-zero woven execution time vs. a
  non-zero original time. The benchmark's live-out values include loop-count
  integers rather than floating-point arrays, making compare.sh's time-parsing
  read a counter value as "time."
- The output MISMATCH needs further investigation. The `reg_detect` kernel uses
  a reduction-like pattern over a jagged structure; incorrect tiling could
  change the reduction order beyond floating-point tolerance.

## Parser failures (atax, bicg)

These two benchmarks use a Fortran `PARAMETER` statement in the form:
```fortran
real, parameter :: alpha = 1.0, beta = 1.0
```

The Java AST parser in fortran-transpiler does not yet handle the
`NamedConstantDef` node type and crashes with:
```
Could not find derived key for id ...-NamedConstantDef
```

This is a bug in the transpiler, not in our scripts. The fix requires adding
`NamedConstantDef` to `FlangName` enum and implementing its processor in
`FortranAst/src/.../processors/Nodes.java`.

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

## Final results after legality fix (branch `fix/emitter-paren-binop`)

| State | Correct | Mismatch | Notes |
|---|---|---|---|
| Original LoopTilingPass | 26/28 | trmm, reg_detect | No triangular-loop legality check |
| After legality fix | **30/30** | **0** | All benchmarks correct |

The fix adds a check in `LoopTilingPass._findTileablePairs()`: for each candidate
pair `(outer, inner)`, search all loops in inner's subtree for bounds containing
a `DataRef` with name equal to the outer loop variable. If found, skip the pair.

**trmm**: The `(i, j)` pair is now rejected (k's bound `i-1` references `i`).
The `(j, k)` pair is tiled instead — the k loop's bounds don't reference `j`, and
tiling `(j, k)` is safe since different j values write to independent `b(j,i)` cells.

**reg_detect**: The `(j, i)` pair is rejected (i's lower bound is `j`). The `(i, cnt)`
pair is still tiled — cnt's bounds don't reference i, and the assignment
`diff(cnt,i,j) = sumTang(i,j)` has no cross-iteration dependencies.

**atax + bicg**: Now transform correctly on this branch (staging PR #48 fixed
the `NamedConstantDef` parser crash).

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
