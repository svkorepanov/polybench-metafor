# Iteration 4 — All 5 Transforms at LARGE_DATASET

## Goal

Measure real execution time and speedup for all 5 loop transforms at `LARGE_DATASET`
(n=2000 for most matrix kernels, no `POLYBENCH_DUMP_ARRAYS`).

## Dataset

`LARGE_DATASET` via `-DLARGE_DATASET -DPOLYBENCH_TIME` in both `preproc.sh` and `compile.sh`.

Typical sizes:
- Matrix kernels (gemm, symm, 3mm, …): NI=NJ=NK=NL=2000
- atax, gemver: NX=NY=8000
- doitgen: NQ=NR=NP=256
- fdtd-apml: 513³ — **OOM on 4 GB RAM, auto-blacklisted by execute.sh**

## Prior iterations

| Iteration | Scope | Result |
|---|---|---|
| 1 | Tiling, Unrolling at SMALL_DATASET | 30/30 MATCH each |
| 2 | Fusion, Interchange at SMALL_DATASET + legality analysis | 30/30 MATCH each |
| 3 | Fission at SMALL_DATASET — `searchFromInclusive` bug fixed | 30/30 MATCH |

## Transforms run

| Transform | Results file | Status |
|---|---|---|
| tilingGeneric (tile=32) | `../../tiling-tile32-large-dataset/results.txt` | |
| unrollGeneric (factor=4) | `../../unroll-factor4-large-dataset/results.txt` | |
| fusionGeneric | `../../fusion-large-dataset/results.txt` | |
| fissionGeneric | `../../fission-large-dataset/results.txt` | |
| interchangeGeneric | `../../interchange-large-dataset/results.txt` | |

## Important notes on correctness at LARGE_DATASET

`POLYBENCH_TIME` mode outputs only the execution timer. `compare.sh` strips the
timer before diffing, so in timing-only mode MATCH = both programs produced the
same non-timer output (empty strings for all benchmarks that print nothing else).
MATCH here means the code ran to completion without crashing, **not** that the
numerical answers are identical. Numerical correctness was established at SMALL_DATASET
(30/30 MATCH with `POLYBENCH_DUMP_ARRAYS`) in iterations 1–3.

## Interchange caveat

`interchangeGeneric` has no legality check. Benchmarks with triangular loop bounds
(`cholesky`, `trisolv`, `lu`, …) can produce wrong results after interchange.
This is invisible at LARGE_DATASET because only the timer is compared.

## Results summary

See `results-summary.txt` once the run completes.
