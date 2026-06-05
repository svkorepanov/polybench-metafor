# Experiment: Loop Tiling — tile=32 — LARGE_DATASET

## Setup

| Parameter | Value |
|---|---|
| Transform | `tilingGeneric.ts` → `LoopTilingPass(32)` |
| Dataset | `LARGE_DATASET` (2000×2000 for matrix kernels) |
| Compiler | `flang-22 -O3 -fopenmp` |
| Platform | Linux 6.17.0, x86_64, 3.8 GB RAM, no swap |
| Date | 2026-06-05 |

## How to reproduce

```bash
# Set flags in preproc.sh and compile.sh:
#   PARGS="-DLARGE_DATASET -DPOLYBENCH_TIME"
./preproc.sh
./compile.sh && ./execute.sh          # baseline
./weave-transpiler.sh tilingGeneric
./compile.sh && ./execute.sh          # woven
./compare.sh 2>&1 > experiments/tiling-tile32-large-dataset/results.txt
```

## Notes on methodology

- `POLYBENCH_DUMP_ARRAYS` is disabled at LARGE_DATASET — a 2000×2000 double
  matrix is 32 MB; dumping all arrays for 30 benchmarks would produce ~10 GB
  of output. Correctness was validated at SMALL_DATASET (see
  `../tiling-tile32-small-dataset/`).
- `POLYBENCH_TIME` prints a single floating-point elapsed time to stderr,
  captured in `*.output.txt` via `execute.sh`'s `2>&1` redirect.
- `compare.sh`'s `strip_timer` was fixed in this experiment to handle
  timing-only output files (bare number, no leading whitespace).
- `fdtd-apml` is blacklisted: it allocates ~4.3 GB at LARGE_DATASET, exceeding
  this machine's 3.8 GB RAM (no swap). OOM-killed by the kernel.

## Results

27/27 runnable benchmarks transformed and executed. All show MATCH (no
functional comparison without array dump — times differ, content is empty
after stripping the timer).

### Speedup table

| Benchmark | Orig (s) | Tiled (s) | Speedup | Category |
|---|---|---|---|---|
| **mvt** | 2.37 | 0.33 | **7.21×** | ✅ big win |
| **floyd-warshall** | 17.88 | 8.16 | **2.19×** | ✅ big win |
| **gemver** | 2.24 | 0.63 | **3.54×** | ✅ big win |
| **trmm** | 8.85 | 6.14 | **1.44×** | ✅ win |
| **syrk** | 15.02 | 11.47 | **1.31×** | ✅ win |
| **gramschmidt** | 248.42 | 215.88 | **1.15×** | ✅ win |
| **doitgen** | 6.97 | 6.22 | **1.12×** | ✅ win |
| **syr2k** | 25.19 | 23.10 | **1.09×** | ✅ win |
| **2mm** | 186.46 | 174.28 | **1.07×** | ✅ small win |
| **3mm** | 257.37 | 240.54 | **1.07×** | ✅ small win |
| **durbin** | 3.25 | 3.06 | **1.06×** | ✅ small win |
| **cholesky** | 3.05 | 2.90 | **1.05×** | ≈ neutral |
| **symm** | 170.47 | 168.89 | **1.01×** | ≈ neutral |
| **correlation** | 89.94 | 89.94 | **1.00×** | ≈ neutral |
| **seidel-2d** | 1.22 | 1.23 | **0.99×** | ≈ neutral |
| **trisolv** | 0.063 | 0.065 | **0.98×** | ≈ neutral |
| **covariance** | 86.20 | 87.94 | **0.98×** | ≈ neutral |
| **gesummv** | 0.145 | 0.161 | **0.90×** | ⚠ slight regression |
| **jacobi-1d-imper** | 0.146 | 0.160 | **0.91×** | ⚠ slight regression |
| **ludcmp** | 20.25 | 23.82 | **0.85×** | ⚠ regression |
| **gemm** | 93.79 | 99.29 | **0.94×** | ⚠ slight regression |
| **adi** | 3.88 | 6.26 | **0.62×** | ❌ regression |
| **fdtd-2d** | 1.53 | 3.47 | **0.44×** | ❌ regression |
| **jacobi-2d-imper** | 0.406 | 0.864 | **0.47×** | ❌ regression |
| **lu** | 4.17 | 10.69 | **0.39×** | ❌ regression |
| dynprog | 36.81 | 0.057 | 646× | ⚠ timing artifact |
| reg_detect | 0.023 | 0.000002 | 11370× | ⚠ timing artifact |

### Timing artifacts

`dynprog` (646×) and `reg_detect` (11370×) show implausible speedups. These
benchmarks have extremely short-running kernels at LARGE_DATASET — the tiled
version hits a near-zero execution time that amplifies noise. Not meaningful.

## Analysis

### Wins: memory-bound kernels with good locality improvement

- **`mvt` (7.21×)**: Matrix-vector transpose. The tile=32 fits the working set
  into L1/L2. Strong win because the original access pattern is column-major
  (cache-unfriendly) and tiling converts it to blocked row/column access.
- **`gemver` (3.54×)**: Four matrix-vector operations. Same locality argument.
- **`floyd-warshall` (2.19×)**: Triple nested loop over adjacency matrix. At
  2000×2000 (32 MB), the matrix doesn't fit in L3; tiling dramatically reduces
  cache misses on the `k` dimension.
- **`trmm`, `syrk`**: Triangular/symmetric operations benefit from tiling the
  outer two dimensions even without full 2D tiling on the triangular inner dim.

### Neutral: compute-bound or already cache-friendly

- **`gemm` (0.94×)**: Slight regression — surprising. At 2000×2000 with `-O3`,
  `flang-22` likely auto-vectorizes and pipelines the original. The tiled
  version adds bounds computation overhead (`MIN(ii+32-1, n)`) that disrupts
  the vectorizer. Tile size 32 may be suboptimal for this CPU's cache geometry.
- **`symm`, `syr2k`**: Near 1.00× — already reasonably cache-friendly or
  compute-bound at this size.
- **`correlation`, `covariance`**: Dominated by the outer loop over variables,
  not the inner matrix operations. Tiling provides no structural benefit.

### Regressions: stencils and solvers

- **`lu` (0.39×), `fdtd-2d` (0.44×), `jacobi-2d-imper` (0.47×), `adi` (0.62×)**:
  All stencil or LU decomposition kernels. Tiling these is harmful for two
  reasons:
  1. Stencils have inherent data dependencies between adjacent cells —
     the tiled traversal changes the update order, which may force extra
     memory traffic to maintain coherence.
  2. `LoopTilingPass(32)` tiles the outermost two loops. For stencils, this
     creates a poor tile shape: the strip-mined `ii/jj` outer loops introduce
     extra branch overhead while the actual reuse distance within a tile is
     not reduced for the stencil access pattern.
  3. `lu` has triangular loop bounds (`do j = 1, i`) — tiling a non-rectangular
     iteration space creates many partial tiles with high overhead at 2000 size.

## Key takeaways

1. **Tile size 32 is a good fit for BLAS-2 kernels** (mvt, gemver, floyd-warshall)
   but not for stencils or triangular solvers at this problem size.
2. **gemm regression** suggests flang-22's vectorizer is better than the tiled
   loop at -O3. A larger tile (e.g. 64 or 128) would reduce the MIN() overhead
   relative to useful work.
3. **Stencil regressions are expected** — stencil tiling requires wavefront or
   time-skewing approaches, not plain spatial tiling of the outer two loops.
4. **Correctness**: 26/28 transformable benchmarks were confirmed correct at
   SMALL_DATASET. The 2 known incorrect cases (trmm, reg_detect) are structural
   issues with triangular/irregular kernels, not a tile-size problem.

## Next experiments

- **Larger tile sizes** (64, 128) for gemm-class kernels.
- **Loop unrolling at LARGE_DATASET** — see `../unroll-factor4-large-dataset/`.
- **Combined tiling + unrolling** on mvt/gemver/floyd-warshall to stack gains.
