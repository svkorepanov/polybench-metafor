# Experiment: Loop Unrolling — factor=4 — LARGE_DATASET

## Setup

| Parameter | Value |
|---|---|
| Transform | `unrollGeneric.ts` → `LoopUnrollPass(4)` |
| Dataset | `LARGE_DATASET` (2000×2000 for most kernels) |
| Compiler | `flang-22 -O3 -fopenmp` |
| Platform | Linux 6.17.0, x86_64 |
| Date | 2026-06-12 |
| Branch | `fix/emitter-paren-binop` (parenExpr fixes applied) |

## How to reproduce

```bash
# From polybench-metafor/
# Set compile.sh and preproc.sh: PARGS="-DLARGE_DATASET -DPOLYBENCH_TIME"
./preproc.sh
./compile.sh && ./execute.sh          # baseline
./weave-transpiler.sh unrollGeneric   # transform
./compile.sh && ./execute.sh          # woven
./compare.sh
```

## Results summary

| Category | Count | Notes |
|---|---|---|
| MATCH — correct output | 29 | All benchmarks except blacklisted |
| MISMATCH | 0 | None |
| Skipped (blacklisted) | 1 | `fdtd-apml` (OOM at LARGE_DATASET, ~4.3 GB) |

**Important caveat**: POLYBENCH_TIME mode outputs only a single timing number. The
`compare.sh` correctness check strips the last number and compares the remainder —
in timing-only mode this means comparing empty strings, so MATCH is trivially
satisfied for all benchmarks regardless of computational correctness. These results
confirm the woven code compiles and runs without crashing; they do not verify
numerical correctness at LARGE_DATASET. The SMALL_DATASET experiment (with
`-DPOLYBENCH_DUMP_ARRAYS`) provides the correctness guarantee: 30/30 MATCH.

## Speedup results

### Notable gains (>1.05×)

| Benchmark | Orig Time (s) | Speedup | Interpretation |
|---|---|---|---|
| `doitgen` | 6.789 | **1.26×** | 4D nest; unrolling the innermost `q` reduction cuts loop overhead |
| `2mm` | 168.4 | **1.17×** | Dense matmul pair; unrolled innermost k-loop helps ILP |
| `cholesky` | 2.528 | **1.14×** | Triangular decomp; inner j-loop benefits from unrolling |
| `3mm` | 253.2 | **1.10×** | Triple matmul; same ILP benefit as 2mm |
| `jacobi-2d-imper` | 0.365 | **1.07×** | 2D stencil; short inner loop length makes unrolling proportionally significant |
| `floyd-warshall` | 14.04 | **1.07×** | All-pairs shortest paths; innermost k-loop is independent per (i,j) pair |
| `bicg` | 0.121 | **1.06×** | Two independent accumulations per outer iteration |

### Notable regressions (<0.92×)

| Benchmark | Orig Time (s) | Speedup | Interpretation |
|---|---|---|---|
| `reg_detect` | 0.025 | **0.70×** | Very fast baseline (24 ms) — timing noise dominates; result unreliable |
| `jacobi-1d-imper` | 0.120 | **0.76×** | 1D stencil; compiler likely already auto-vectorizes the 1D loop better without unrolling |
| `lu` | 3.886 | **0.79×** | LU decomp with loop-carried dependency on pivot row; unrolling prevents vectorizer from optimizing the triangular access |
| `dynprog` | 42.65 | **0.86×** | Dynamic programming recurrence; unrolled body introduces more register pressure on a loop-carried chain |

### Neutral (0.92×–1.05×)

All remaining 21 benchmarks fall in this range, indicating the transformation neither
helps nor hurts at this dataset size. Dominant bottleneck is DRAM bandwidth for large
dense matrices — loop overhead reduction from unrolling is negligible compared to
memory latency.

## Comparison with tiling (LARGE_DATASET)

| Benchmark | Tiling speedup | Unrolling speedup | Better |
|---|---|---|---|
| `mvt` | 7.21× | 0.99× | Tiling (cache reuse) |
| `gemver` | 3.54× | 0.97× | Tiling |
| `floyd-warshall` | 2.19× | 1.07× | Tiling |
| `syrk` | 1.31× | 0.99× | Tiling |
| `doitgen` | 1.12× | 1.26× | **Unrolling** |
| `2mm` | 1.07× | 1.17× | **Unrolling** |
| `3mm` | 1.07× | 1.10× | Unrolling (slight edge) |
| `cholesky` | 1.05× | 1.14× | **Unrolling** |
| `lu` | 0.39× | 0.79× | Neither (both regress; unrolling less bad) |

Key observations:
- **Tiling wins** on benchmarks with strong cache-reuse potential (mvt, gemver,
  floyd-warshall): tiling tiles the outer loops, reusing whole cache lines across
  tiles.
- **Unrolling wins** on benchmarks that are instruction-throughput-limited rather
  than memory-bound (doitgen, 2mm, cholesky): reducing loop bookkeeping overhead
  and improving ILP matters when the data is already hot.
- **lu regresses in both** because both transforms interfere with the compiler's
  ability to vectorize the triangular dependency chain.

## Transform? column note

The `Transform?=TILED` label appears for all unrolled benchmarks because the
detection heuristic in `compare.sh` looks for 3-argument DO statements
(`DO var = lo, hi, step`). The unroll transform generates step-4 main loops
(`DO i = lo, hi, 4`) which trigger the same pattern as tile-stride loops.
A future improvement would add an `UNROLLED` detection path (e.g., look for
`DO i = lo, hi, 4` without an enclosing tile-stride loop) or pass the transform
name as a column header.

## Next experiments

1. **Tile + unroll** — apply tiling (tile=32) first, then unrolling (factor=4)
   on the inner loop to combine cache reuse with ILP.
2. **Fusion / fission** at LARGE_DATASET — run `fusionGeneric` and `fissionGeneric`
   and compare.
3. **Interchange** at LARGE_DATASET — run `interchangeGeneric` for column-major
   benchmarks (e.g., gemm, syrk) where swapping i/j loops may improve stride.
4. **Numerical correctness at LARGE_DATASET** — add `-DPOLYBENCH_DUMP_ARRAYS`
   to a LARGE_DATASET run for a subset of benchmarks (e.g., first 5 kernels)
   to verify the parenExpr fix holds at scale.
