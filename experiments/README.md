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
| [tiling-tile32-small-dataset](tiling-tile32-small-dataset/analysis.md) | tilingGeneric (tile=32) | SMALL | 26/28 | trmm, reg_detect | atax, bicg (parser bug) | 1.00x speedup — dataset too small to see cache effects |
| [unroll-factor4-small-dataset](unroll-factor4-small-dataset/analysis.md) | unrollGeneric (factor=4) | SMALL | 8/28 | all accumulation kernels | atax, bicg (parser bug) | emitter bug: missing parentheses in cleanup loop bound causes off-by-one; re-executes last iter on all accumulation loops |
