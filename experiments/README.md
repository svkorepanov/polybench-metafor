# Experiments

Each subdirectory is one experiment run: a specific loop transformation applied
to a specific dataset size, with results and analysis captured at a point in
time.

## Directory naming convention

```
<transform>-<params>-<dataset>/
  results.txt    raw output of compare.sh
  analysis.md    interpretation: what worked, what failed, why
```

Examples:
- `tiling-tile32-small-dataset/`
- `tiling-tile64-medium-dataset/`
- `unroll-factor4-small-dataset/`
- `fusion-small-dataset/`

## How to run a new experiment

```bash
# 1. Apply transform (overwrites woven_code/ dirs)
./weave-transpiler.sh <TRANSFORM>

# 2. Compile + run
./compile.sh && ./execute.sh

# 3. Capture results
mkdir -p experiments/<name>
./compare.sh 2>&1 > experiments/<name>/results.txt

# 4. Write analysis in experiments/<name>/analysis.md
```

Valid TRANSFORM values: `tilingGeneric`, `unrollGeneric`, `fusionGeneric`,
`fissionGeneric`, `interchangeGeneric`.

To switch dataset size, edit `PARGS` in `compile.sh`:
```bash
# PARGS="-DSMALL_DATASET -DPOLYBENCH_DUMP_ARRAYS"
PARGS="-DMEDIUM_DATASET -DPOLYBENCH_DUMP_ARRAYS -DPOLYBENCH_TIME"
```
Adding `-DPOLYBENCH_TIME` makes the timing column in compare.sh meaningful.

## Experiment log

| Experiment | Transform | Dataset | Correct | Mismatch | Skipped | Notes |
|---|---|---|---|---|---|---|
| [tiling-tile32-small-dataset](tiling-tile32-small-dataset/analysis.md) | tilingGeneric (tile=32) | SMALL | **30/30** (after legality fix) | — | — | triangular-loop legality check added to LoopTilingPass; trmm/(j,k) and reg_detect/(i,cnt) tiled instead |
| [unroll-factor4-small-dataset](unroll-factor4-small-dataset/analysis.md) | unrollGeneric (factor=4) | SMALL | **30/30** (after parenExpr fix) | — | — | parenExpr wrapping in LoopUnroll.ts fixes compound bounds + reverse-index bodies; staging PR #48 fixed atax/bicg parser |
| [tiling-tile32-large-dataset](tiling-tile32-large-dataset/analysis.md) | tilingGeneric (tile=32) | LARGE (2000×2000) | 27/27 timing-only | — | fdtd-apml (OOM, 4.3 GB), atax/bicg (parser bug) | mvt 7.2×, floyd-warshall 2.2×, gemver 3.5×; stencils/lu regress (wrong tile shape); gemm slightly slower (vectoriser conflict) |
| [unroll-factor4-large-dataset](unroll-factor4-large-dataset/analysis.md) | unrollGeneric (factor=4) | LARGE (2000×2000) | 29/29 timing-only | — | fdtd-apml (OOM, 4.3 GB) | doitgen 1.26×, 2mm 1.17×, cholesky 1.14×, 3mm 1.10×; lu 0.79×, jacobi-1d 0.76× regress; tiling better for cache-bound kernels |
| [fission-small-dataset](fission-small-dataset/analysis.md) | fissionGeneric | SMALL | **21/30** | trisolv, cholesky, symm, lu, gramschmidt, ludcmp, adi, fdtd-2d, fdtd-apml | — | No legality check — 9 mismatches all have loop-carried deps; fixed NullPointerException in LoopFissionPass/LoopFusionPass |
