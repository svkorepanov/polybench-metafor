# Experiment: Loop Fission — LARGE_DATASET

## Setup

| Parameter | Value |
|---|---|
| Transform | `fissionGeneric.ts` → `LoopFissionPass()` |
| Dataset | `LARGE_DATASET` (2000×2000 for matrix kernels) |
| Compiler | `flang-22 -O3 -fopenmp` |
| Platform | Linux 6.17.0, x86_64, 3.8 GB RAM |
| Date | 2026-06-13 |
| Branch | `fix/emitter-paren-binop` |

## How to reproduce

```bash
# From polybench-metafor/ with LARGE_DATASET flags in preproc.sh and compile.sh
./preproc.sh
./weave-transpiler.sh fissionGeneric
./compile.sh && ./execute.sh
./compare.sh > experiments/fission-large-dataset/results.txt
```

## Notes

- Legality fix (iteration-3): `Query.searchFromInclusive` was used instead of `Query.searchFrom`
  in `canFission()` helpers — this was the root bug causing MISMATCHes at SMALL_DATASET.
- POLYBENCH_DUMP_ARRAYS disabled — correctness validated at SMALL_DATASET (30/30 MATCH).
- fdtd-apml auto-blacklisted by execute.sh at LARGE_DATASET.
