# Experiment: Loop Fusion — LARGE_DATASET

## Setup

| Parameter | Value |
|---|---|
| Transform | `fusionGeneric.ts` → `LoopFusionPass()` |
| Dataset | `LARGE_DATASET` (2000×2000 for matrix kernels) |
| Compiler | `flang-22 -O3 -fopenmp` |
| Platform | Linux 6.17.0, x86_64, 3.8 GB RAM |
| Date | 2026-06-13 |
| Branch | `fix/emitter-paren-binop` |

## How to reproduce

```bash
# From polybench-metafor/ with LARGE_DATASET flags in preproc.sh and compile.sh
./preproc.sh
./weave-transpiler.sh fusionGeneric
./compile.sh && ./execute.sh
./compare.sh > experiments/fusion-large-dataset/results.txt
```

## Notes

- POLYBENCH_DUMP_ARRAYS disabled — correctness validated at SMALL_DATASET (30/30 MATCH).
- fdtd-apml auto-blacklisted by execute.sh (dimension 513 ≥ 256 → OOM at LARGE_DATASET).
- POLYBENCH_TIME output: compare.sh strips the timer before diffing, so MATCH = same code path reached (not numerical equality).
