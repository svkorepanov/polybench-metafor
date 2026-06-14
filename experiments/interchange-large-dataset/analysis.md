# Experiment: Loop Interchange — LARGE_DATASET

## Setup

| Parameter | Value |
|---|---|
| Transform | `interchangeGeneric.ts` — manual interchange (no pass class) |
| Dataset | `LARGE_DATASET` (2000×2000 for matrix kernels) |
| Compiler | `flang-22 -O3 -fopenmp` |
| Platform | Linux 6.17.0, x86_64, 3.8 GB RAM |
| Date | 2026-06-13 |
| Branch | `fix/emitter-paren-binop` |

## How to reproduce

```bash
# From polybench-metafor/ with LARGE_DATASET flags in preproc.sh and compile.sh
./preproc.sh
./weave-transpiler.sh interchangeGeneric
./compile.sh && ./execute.sh
./compare.sh > experiments/interchange-large-dataset/results.txt
```

## Known caveat

`interchangeGeneric` does not perform legality checking. Benchmarks with triangular
loop bounds (e.g. `cholesky`, `trisolv`) will produce incorrect output after interchange.
These were verified to be MATCH at SMALL_DATASET only because the test suite uses
`POLYBENCH_DUMP_ARRAYS` correctness checking there. At LARGE_DATASET only the timer
is compared, so MISMATCHes would be silent.

For full correctness confirmation: see `experiments/interchange-small-dataset/`.
