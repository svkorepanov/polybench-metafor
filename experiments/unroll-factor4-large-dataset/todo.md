# TODO: Loop Unrolling — factor=4 — LARGE_DATASET

## Prerequisite

Complete `../tiling-tile32-large-dataset/todo.md` first (steps 1–5).
This experiment starts after tiled woven_code dirs have been renamed.

---

## Steps to complete this experiment

### 1. Verify tiled dirs are archived and woven_code is clear

```bash
find . -type d -name woven_code   # should return nothing
find . -type d -name woven_code_tiling | wc -l  # should be 28
```

### 2. Apply unroll transform

```bash
./weave-transpiler.sh unrollGeneric
```

Expected: 28/30 (atax, bicg always fail — parser bug, unrelated to dataset size).

### 3. Compile unrolled versions

```bash
./compile.sh
```

### 4. Execute unrolled versions

```bash
./execute.sh
```

### 5. Save results

```bash
./compare.sh 2>&1 > experiments/unroll-factor4-large-dataset/results.txt
cat experiments/unroll-factor4-large-dataset/results.txt
```

### 6. Clean up and restore settings

```bash
# Remove woven dirs from this run
find . -type d -name woven_code -exec rm -rf {} + 2>/dev/null

# Restore preproc.sh and compile.sh to small-dataset defaults
sed -i 's/-DLARGE_DATASET -DPOLYBENCH_TIME/-DSMALL_DATASET -DPOLYBENCH_DUMP_ARRAYS/' preproc.sh
sed -i 's/-DLARGE_DATASET -DPOLYBENCH_TIME/-DSMALL_DATASET -DPOLYBENCH_DUMP_ARRAYS/' compile.sh

# Re-preprocess for small dataset (needed for future experiments)
find . -name "*.preproc.f90" | xargs rm -f
./preproc.sh
```

---

## What to expect

Unrolling by 4 benefits innermost loops with independent iterations by reducing
loop overhead and enabling better register use. At LARGE_DATASET the bottleneck
shifts from instruction overhead to memory bandwidth, so gains are likely modest
(0–20%) or even negative for cache-unfriendly access patterns.

Key comparison with tiling results:
- Kernels where tiling wins (gemm-class): unrolling alone likely slower or flat
- Kernels where tiling is neutral (stencils): unrolling may show small gains
- Together (tile + unroll): combining both transforms is a future experiment

Known mismatches at SMALL_DATASET that persist here (timing-only run, so
all show MATCH in compare.sh regardless):
- dynprog, lu, adi — compound lower bounds (i+1, k+1) trigger the emitter
  parenthesization bug that LoopUnroll.ts cannot fully fix without an emitter change
