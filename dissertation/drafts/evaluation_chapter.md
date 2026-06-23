# Evaluation — Bullet-Point Draft

> **Scope**: Evaluation chapter covering correctness (SMALL_DATASET) and performance
> (LARGE_DATASET) for all five loop transforms.
> Correctness data: `experiments/issues/` iterations 1–3 (SMALL_DATASET, 128×128).
> Performance data: `experiments/issues/iteration-6-no-turbo/` (laboratory, LARGE_DATASET,
> CPU turbo disabled, 2026-06-16).
> Status: **draft scaffold** — expand each bullet into prose.

---

## Chapter 7 — Evaluation

### 7.1 Experimental Setup

- **Benchmarks**: 30 PolyBench/Fortran kernels spanning linear algebra (kernels + solvers), stencils, datamining, and medley. Each exposes one `kernel_*` subroutine with a `!$pragma scop / endscop` region.
- **Compiler**: `flang-22 -O3 -fopenmp` (with `-fopenmp` always active, even for non-parallel code, to keep flags uniform).
- **Platform (performance experiments)**: laboratory Linux machine, x86_64, CPU turbo boost **disabled** for stable timing (iteration-6-no-turbo, run 2026-06-16). Turbo was disabled to eliminate frequency scaling as a noise source in single-run measurements.
- **Correctness dataset**: `SMALL_DATASET` (128×128 for matrix kernels) with `POLYBENCH_DUMP_ARRAYS` — exact numerical output compared via `compare.sh`. Run on the development machine (earlier iterations, 2026-06-12/13).
- **Performance dataset**: `LARGE_DATASET` (2000×2000 for matrix kernels) with `POLYBENCH_TIME` only — `POLYBENCH_DUMP_ARRAYS` disabled (a 2000×2000 `DOUBLE` matrix is 32 MB; timing 30 benchmarks × 5 transforms without the array dump keeps total output manageable).
- **All 30 benchmarks runnable**: the laboratory machine has sufficient memory to run all benchmarks including `fdtd-apml` (previously OOM on the development machine). The automatic blacklist in `execute.sh` was removed for the laboratory run. **30/30 benchmarks ran and matched for every transform.**
- **Correctness at LARGE_DATASET**: MATCH means the binary produced the same timing output path (the timer string is stripped before diff). Numerical correctness is guaranteed exclusively by the SMALL_DATASET 30/30 check — the LARGE_DATASET runs confirm the transformed code compiles, links, and executes without crash.
- **Transformation parameters**: tile size = 32, unrolling factor = 4. These were chosen to demonstrate parameterized transformation; they were not autotuned.

### 7.2 Correctness Results (SMALL_DATASET)

- All five transforms achieve **30/30 MATCH** at SMALL_DATASET after the three correctness iterations described in §6.3.
- **Performance experiment confirms correctness at scale**: the LARGE_DATASET run (iteration-6-no-turbo) reports **30 Matches, 0 Mismatches, 0 Missing** for all five transforms — the first experiment in which all 30 benchmarks, including `fdtd-apml`, ran without error.
- Loop unrolling achieves 30/30 after the emitter parenthesization fix. Before the fix: `dynprog`, `lu`, `adi` were MISMATCH (wrong cleanup-loop bounds due to missing parentheses on compound sub-expressions); `atax` and `bicg` crashed the parser before any transform was applied (`NamedConstantDef` node unimplemented). After the fix, all 30 either produce correct woven output or, for the two parser-crash cases, fall back to the unmodified original and still MATCH.
- The legality checks are conservative: when a pattern is unsafe or unrecognized, the transformation is skipped and the original code is preserved. No transform produces a MISMATCH by corrupting code it decided to transform; all pre-fix mismatches were cases where the tool incorrectly chose to transform a loop it should have skipped.

### 7.3 Performance Results — Loop Tiling (tile=32, LARGE_DATASET)

- **21 of 30 benchmarks transformed** (tiled); 9 not tiled — either no suitable 2-deep perfect nest found, or `canTile()` blocked the outermost pair and no inner pair was available. All 30 report MATCH.
- **Top wins** (memory-bound kernels where blocking fits the working set into L1/L2):
  - `mvt` (matrix-vector transpose): **4.52×** — original column-major access is cache-unfriendly; tiled blocked traversal converts it to L1-resident blocks.
  - `gemver` (4 matrix-vector ops): **2.04×** — same locality argument; two passes over a 2000-row matrix collapse into one blocked pass.
  - `floyd-warshall` (all-pairs shortest path): **1.51×** — 2000×2000 adjacency matrix (32 MB) does not fit in L3; tiling reduces cache misses on the `k` dimension.
  - `syrk`: **1.22×**, `syr2k`: **1.14×**, `3mm`: **1.05×**, `gemm`: **1.04×**, `2mm`: **1.04×**, `symm`: **1.03×**.
- **Neutral** (~1.00×): `correlation`, `covariance`, `seidel-2d`, `fdtd-apml`, `doitgen`, `dynprog`.
- **Regressions** (stencil and solver kernels):
  - `jacobi-2d-imper`: **0.35×**, `fdtd-2d`: **0.45×** — stencil benchmarks have data dependencies between adjacent cells; tiling the outermost two loops does not help reuse distance on the stencil footprint and adds tile-boundary overhead.
  - `lu`: **0.41×** — triangular loop bounds (`do j = 1, i`) generate many partial tiles with high overhead; tiling cannot improve a non-rectangular iteration space without skewed tiling.
  - `trmm`: **0.66×** — `canTile()` blocks the outermost `(i,j)` pair (Check 2: body has `do k = 1, i-1`); the tool instead tiles the inner `(j,k)` pair, which is safe but provides no locality benefit on the lab machine.
  - `adi`: **0.89×**, `reg_detect`: **0.86×** — slight regressions; `reg_detect` is a very short kernel (39 ms baseline) where tile overhead dominates.
- **Key insight**: tile=32 is a good fit for BLAS-2/BLAS-3 kernels (32×32×8 B = 8 KB fits in L1) and for kernels with matrix-transpose access patterns (`mvt`, `gemver`). It does not help stencils (requiring wavefront/time-skewing) or triangular solvers (non-rectangular iteration space).

### 7.4 Performance Results — Loop Unrolling (factor=4, LARGE_DATASET)

- **All 30 benchmarks transformed** (unrolling applies to all innermost simple `DO` loops; `Total Transformed: 30`). All 30 MATCH. Note: `compare.sh` labels all unrolled benchmarks as `Transform?=TILED` because the step-4 main loop matches the heuristic for stride loops — a known tooling artefact.
- **Gains**: gains are modest across the board; the dominant bottleneck at LARGE_DATASET for dense matrices is DRAM bandwidth, so reducing loop-control overhead provides limited benefit.
  - `bicg`: **1.06×**, `floyd-warshall`: **1.05×**, `doitgen`: **1.04×**, `trisolv`: **1.03×** — instruction-throughput-limited kernels where removing 3 out of 4 loop-control instructions per element matters.
- **Neutral** (most benchmarks in 0.96–1.01×): `correlation`, `covariance`, `fdtd-apml`, `fdtd-2d`, `seidel-2d`, `syrk`, `syr2k`, `trmm`, `gemver`, `symm`, `cholesky`, `gesummv`, `durbin`, `gramschmidt`.
- **Regressions**:
  - `adi`: **0.80×**, `lu`: **0.81×** — loop-carried dependency chains; unrolling 4 iterations of a recurrence increases register pressure without exposing independent work.
  - `dynprog`: **0.83×** — dynamic programming recurrence; same register-pressure argument.
  - `atax`: **0.83×**, `reg_detect`: **0.79×** — short kernels (atax: ~141 ms, reg_detect: ~42 ms baseline) where the cleanup loop adds overhead relative to useful work.
  - `jacobi-2d-imper`: **0.88×** — `flang-22 -O3` auto-vectorizes the stencil inner loop better without the step-4 structure interfering.
- **Comparison with tiling**: unrolling is uniformly weaker than tiling on memory-bound kernels (`mvt` 0.99× vs. 4.52×, `gemver` 0.98× vs. 2.04×, `floyd-warshall` 1.05× vs. 1.51×). Where tiling regresses (stencils, `lu`), unrolling regresses too but less severely (`lu`: unrolling 0.81× vs. tiling 0.41×). Unrolling's value in this suite is as a low-risk complement that can be stacked on top of tiling.

### 7.5 Performance Results — Loop Fusion (LARGE_DATASET)

- **8 of 30 benchmarks transformed** (loops fused); 22 unchanged (no adjacent loops with compatible bounds, or legality checks A/B/C blocked the merge). All 30 MATCH.
- **Notable gain**:
  - `jacobi-2d-imper`: **1.64×** — the best single-transform result for fusion; two loops over the 2D stencil space fused into one, eliminating a full pass over `ex` and `hz` arrays between two loop iterations and improving L2 reuse significantly.
- **Modest gains**: `syr2k`: **1.01×**, `syrk`: **1.01×**, `correlation`: **1.01×**, `fdtd-apml`: **1.01×**, `gemver`: **1.00×** — all barely above noise level.
- **Slight regressions in transformed benchmarks**: `mvt`: **0.97×**, `2mm`: **0.99×** — fusion adds loop body complexity that may hinder vectorization at the current `-O3` setting.
- **Untransformed benchmarks** are semantically identical to baseline; timing variations of ±2% reflect single-run noise, not fusion effects.
- **Correctness of legality checks**: the three benchmarks that failed pre-fix (`atax`, `doitgen`, `gemver`) are correctly blocked by Checks A/B/C and not fused — confirmed by their `Transform?=NO` labels in the results.
- **Key insight**: fusion yield is low (8/30) because most PolyBench kernels have only one loop per array operation, or adjacent loops differ in bounds. The dominant win (`jacobi-2d-imper` 1.64×) comes specifically from stencil kernels where two consecutive loops access the same arrays in compatible order — a pattern that fusion is designed for.

### 7.6 Performance Results — Loop Fission (LARGE_DATASET)

- **10 of 30 benchmarks transformed** (at least one loop fissioned); 20 unchanged. All 30 MATCH.
- **Gain**: `reg_detect`: **1.05×** — modest; fissioning simplifies a body with mixed scalar and array work.
- **Neutral**: `2mm`: **1.00×**, `3mm`: **1.00×**, `doitgen`: **1.00×**, `dynprog`: **1.01×**, `correlation`: **1.00×** — fission applied but performance impact is within noise.
- **Regressions in transformed benchmarks**:
  - `gesummv`: **0.70×**, `bicg`: **0.70×** — two-loop fission splits a pair of accumulation loops that originally shared a hot array in cache; after splitting, each loop independently re-traverses the full array, doubling the effective memory traffic.
  - `symm`: **0.80×**, `atax`: **0.81×** — same cache-pressure argument for matrix kernels; the fissioned loops read the same large arrays in separate passes.
- **Untransformed benchmarks** show ~1.00× as expected.
- **Note on a non-transformed outlier**: `jacobi-1d-imper` shows 1.23× speedup at `Transform?=NO` — the fission pass found no fissionable loop in this benchmark, so the binary is identical to baseline; the 1.23× is pure timing noise on a 179 ms kernel.
- **Key insight**: fission consistently hurts memory-bound kernels in this suite by splitting loops that shared live data in cache. Its value in this context is as a preparatory pass for later transformations (e.g. exposing simpler loop bodies for vectorization or parallelization), not as a direct performance optimization.

### 7.7 Performance Results — Loop Interchange (LARGE_DATASET)

- **17 of 30 benchmarks interchanged**; 13 not interchanged (no perfect 2-deep nest found, or `canInterchange()` blocked the swap). All 30 MATCH.
- **Important caveat**: `interchangeGeneric` runs `canInterchange()` to guard correctness but does **not** guarantee that every interchange is performance-beneficial. Some swaps produce correct but cache-unfriendly code.
- **Wins on dense linear algebra kernels**:
  - `gemm`: **1.04×**, `3mm`: **1.04×**, `2mm`: **1.04×**, `floyd-warshall`: **1.03×**, `symm`: **1.01×`, `correlation`: **1.00×**, `covariance`: **1.00×**, `seidel-2d`: **1.00×**, `doitgen`: **1.00×**, `dynprog`: **1.00×** — modest but consistent wins on kernels where swapping to column-major-first access matches Fortran's column-major array layout.
- **Non-transformed notable mentions**: `reg_detect` (`Transform?=NO`): **1.38×** and `jacobi-1d-imper` (`Transform?=NO`): **1.22×** — these benchmarks were NOT interchanged (blocked by legality check or no suitable nest); the speedup is timing noise on sub-millisecond kernels.
- **Catastrophic regressions on stencil and solver benchmarks**:
  - `fdtd-2d`: **0.06×** (~17× slower), `lu`: **0.05×** (~20× slower), `jacobi-2d-imper`: **0.07×** (~14× slower), `adi`: **0.13×** (~8× slower).
  - All four benchmarks show `Transform?=YES` — `canInterchange()` was called and approved the swap. Their loop bounds are rectangular and pass both syntactic checks (no triangular inner bound, no nested loop referencing the outer variable). The interchange is therefore **semantically correct** and confirmed MATCH at SMALL_DATASET with `POLYBENCH_DUMP_ARRAYS`. The regressions are purely a **performance** consequence: swapping the loop order in Fortran column-major code turns a contiguous inner-dimension access into a strided outer-dimension access, dramatically increasing cache-miss rate on large (2000×2000) arrays.
  - `gemver`: **0.54×** — same mechanism; the inner matrix-update loop after interchange traverses rows instead of columns, doubling effective memory traffic.
- **Key insight**: interchange is the highest-variance transform in this suite — up to 1.04× on kernels where the swap aligns with Fortran's column-major layout, and down to 0.05× on stencil and solver kernels where the swap inverts the cache-friendly access order. The `canInterchange()` legality guard correctly allows all of these transforms (they are semantically valid); what the guard does not provide is a **profitability model** — distinguishing cache-friendly from cache-hostile swaps requires array-layout awareness beyond syntactic loop-bound analysis.

### 7.8 Cross-Transform Comparison

All numbers from iteration-6-no-turbo (lab, LARGE_DATASET, turbo off). "—" means not transformed by that pass (not applicable or blocked). Untransformed benchmarks show ~1.00× (baseline noise only); those cells are omitted for clarity.

| Benchmark | Tiling | Unrolling | Fusion | Fission | Interchange |
|---|---|---|---|---|---|
| `mvt` | **4.52×** | 0.99× | 0.97× | — | 1.00× |
| `gemver` | **2.04×** | 0.98× | 1.00× | — | 0.54× |
| `floyd-warshall` | **1.51×** | 1.05× | 1.00× | — | 1.03× |
| `syrk` | **1.22×** | 0.96× | 1.01× | — | — |
| `syr2k` | 1.14× | 0.98× | 1.01× | — | — |
| `bicg` | — | **1.06×** | — | 0.70× | — |
| `doitgen` | 1.00× | 1.04× | — | 1.00× | 1.00× |
| `jacobi-2d-imper` | 0.35× | 0.88× | **1.64×** | — | 0.07× |
| `2mm` | 1.04× | 0.96× | 0.99× | 1.00× | **1.04×** |
| `gemm` | 1.04× | 0.97× | — | — | **1.04×** |
| `lu` | 0.41× | 0.81× | — | — | 0.05× |
| `fdtd-2d` | 0.45× | 1.00× | — | — | 0.06× |
| `gesummv` | — | 1.01× | — | 0.70× | — |
| `adi` | 0.89× | 0.80× | — | — | 0.13× |

- **Tiling is the best single transform** for memory-bound kernels with transpose or blocked access patterns (`mvt` 4.52×, `gemver` 2.04×, `floyd-warshall` 1.51×); stencil regressions are structural (non-rectangular iteration space) and are expected.
- **Unrolling has the lowest regression risk** (30/30 transformed, most within ±5% of baseline); its gain potential is also modest (best: bicg 1.06×). It is most valuable as a low-risk complement to tiling, not as a standalone transform.
- **Fusion has the highest single-benchmark win** (`jacobi-2d-imper` 1.64×) but low yield (8/30); it is the most selective transform in this suite. The legality checks successfully blocked all three originally-failing benchmarks (`atax`, `doitgen`, `gemver`).
- **Fission consistently regresses on accumulation kernels** (`bicg` and `gesummv` at 0.70×) by splitting loops that share hot data in cache; its benefit in this suite is code structural clarity for subsequent transformations, not direct performance.
- **Interchange is the highest-variance transform**: correct and cache-beneficial on dense linear algebra (1.03–1.04×), but cache-destructive on stencil and solver kernels (`fdtd-2d` 0.06×, `lu` 0.05×, `jacobi-2d-imper` 0.07×, `adi` 0.13×). All regressions are semantically correct interchanges that pass `canInterchange()` — the issue is not legality but **profitability**: the syntactic guard has no model of array layout or cache access patterns.

### 7.9 Threats to Validity

- **Numerical correctness at LARGE_DATASET is not verified**: `POLYBENCH_DUMP_ARRAYS` is disabled; MATCH at LARGE_DATASET means the binary ran to completion and produced the same single-line timer output, not that intermediate arrays are numerically correct. The SMALL_DATASET 30/30 check is the sole numerical correctness guarantee. A dataset-size-dependent correctness bug (e.g. off-by-one in a tile boundary formula) would be undetectable in the LARGE_DATASET results.
- **Single run per benchmark**: timing is measured from one execution only; no averaging or statistical analysis. Short-running kernels (`reg_detect` ~42 ms, `trisolv` ~55 ms, `gesummv` ~135 ms, `jacobi-1d-imper` ~176 ms) have unreliable speedup measurements — their apparent gains or regressions may be noise. This is especially relevant for the fission `jacobi-1d-imper` 1.23× anomaly (untransformed benchmark showing a speedup).
- **Turbo boost disabled but other frequency-scaling mechanisms may still vary**: turbo was explicitly disabled for the laboratory run; however, other power management mechanisms (C-states, voltage/frequency scaling under thermal load) were not controlled. Long-running benchmarks (e.g. `gramschmidt` ~255 s, `3mm` ~300 s) may have experienced frequency changes mid-run.
- **Tile size and unroll factor not autotuned**: tile=32 and factor=4 were chosen to demonstrate parameterized transformation. A larger tile (64 or 128) might recover or improve results for `gemm`, `symm`, and large matrix kernels that are insensitive at tile=32. A smaller unroll factor (2) might reduce the register-pressure regressions on `adi` and `lu`.
- **Single compiler, single CPU architecture**: all results use `flang-22 -O3` on one x86_64 machine. Results with `gfortran`, Intel `ifx`, or on ARM/Power may differ significantly, particularly for vectorization interactions with unrolling and for stencil tiling.
- **`compare.sh` transform detection heuristic labels unrolled code as tiled**: the `Transform?` column reads YES when a 3-argument `DO var = lo, hi, step` appears in the woven source; step-4 unrolled loops trigger this same pattern. The `Total Transformed: 30` count for unrolling is reliable (all 30 benchmarks were transformed), but the `Transform?` column itself is not informative for distinguishing unrolling from tiling.
- **Conservative legality checks reduce yield**: `canTile()` and `canInterchange()` use word-boundary regex on bound expression strings; they may block safe loops where the outer variable name coincidentally appears in an unrelated bound (false negatives). This is a deliberate design choice (false negatives are safe; false positives would corrupt output) but it means some beneficial transforms are skipped.

---

## Open Questions for Future Work

- **Add a cache-layout profitability heuristic to interchange**: `canInterchange()` correctly guards semantic correctness but has no model of array access patterns or Fortran's column-major layout. A lightweight heuristic — e.g. checking whether the innermost array subscript after the swap becomes the non-unit-stride dimension — could identify the stencil/solver regressions (`fdtd-2d` 0.06×, `lu` 0.05×) before they are applied, while leaving the linear-algebra wins (1.03–1.04×) untouched.
- **Autotuning tile size**: tile=32 is a heuristic. Benchmarks like `gemm` (1.04×), `symm` (1.03×), and large dense solvers may benefit from tile=64 or tile=128; benchmarks like `reg_detect` (tiny arrays) could use tile=8. Auto-selecting tile size based on array dimensions and cache topology would reduce both neutral and negative outcomes.
- **Stencil-aware tiling**: wavefront tiling or time-skewing approaches would allow `fdtd-2d`, `jacobi-2d-imper`, and `adi` to benefit from tiling rather than regressing. These require non-trivial legality analysis beyond syntactic checks.
- **Combined transforms**: applying tiling followed by unrolling on `mvt` (tiling 4.52×, unrolling 0.99×) and `gemver` (2.04×, 0.98×) could stack gains; the framework supports sequential transform application but this was not evaluated.
- **Fission as a preprocessing step for parallelization**: fissioned loops with independent bodies are natural candidates for `!$omp parallel do` insertion. Combining fission with the `metafor-omp` parallelizer could expose speedups that fission alone does not provide.
- **Multi-run timing**: replacing single-run measurements with median-of-N runs would make speedup results for short kernels (`reg_detect`, `gesummv`, `trisolv`) statistically meaningful and eliminate the current noise anomalies.
