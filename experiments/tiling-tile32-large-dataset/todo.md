# TODO: Loop Tiling — tile=32 — LARGE_DATASET

## Current state (as of 2026-06-05)

| Step | Status |
|---|---|
| preproc.sh set to LARGE_DATASET + POLYBENCH_TIME | DONE |
| compile.sh set to LARGE_DATASET + POLYBENCH_TIME | DONE |
| `./preproc.sh` — 30 benchmarks preprocessed | DONE |
| Baseline `./compile.sh` — 30 originals compiled | DONE |
| Baseline `./execute.sh` — 28/30 ran (covariance, correlation missing) | PARTIAL |
| `./weave-transpiler.sh tilingGeneric` — 28/30 transformed | DONE |
| Compile tiled + execute tiled + compare | PENDING |
| unrollGeneric experiment | PENDING (do after tiling) |

---

## Steps to complete this experiment

### 1. Finish the two missing baseline runs

```bash
./execute.sh
```

(Reruns all — quick for the 28 already done, adds covariance + correlation.)

### 2. Compile tiled versions

```bash
./compile.sh
```

`compile.sh` picks up both `*.preproc.f90` files and
`woven_code/*.preproc.f90` files, so both original and tiled executables
are built in one pass.

### 3. Execute tiled versions

```bash
./execute.sh
```

### 4. Save results

```bash
./compare.sh 2>&1 > experiments/tiling-tile32-large-dataset/results.txt
cat experiments/tiling-tile32-large-dataset/results.txt
```

### 5. Archive tiled woven_code dirs (before running unroll)

```bash
find . -type d -name woven_code -exec sh -c \
    'mv "$1" "$(dirname "$1")/woven_code_tiling"' _ {} \;
```

This preserves the tiled source for inspection without blocking the next
transform's output directory.

---

## Then: run the unroll experiment

See `../unroll-factor4-large-dataset/todo.md` — start there after step 5 above.

---

## After both experiments: restore default settings

```bash
# preproc.sh
sed -i 's/-DLARGE_DATASET -DPOLYBENCH_TIME/-DSMALL_DATASET -DPOLYBENCH_DUMP_ARRAYS/' preproc.sh

# compile.sh
sed -i 's/-DLARGE_DATASET -DPOLYBENCH_TIME/-DSMALL_DATASET -DPOLYBENCH_DUMP_ARRAYS/' compile.sh

# Re-preprocess for small dataset
./preproc.sh
```

---

## What to expect

At LARGE_DATASET (2000×2000), tiling with tile=32 should show real speedup on
memory-bound kernels. Preliminary baseline times (seconds, single-threaded):

| Benchmark | Baseline time |
|---|---|
| symm | 183.5s |
| gramschmidt | 198.5s |
| 2mm | 156.1s |
| 3mm | 331.6s |
| gemm | 96.5s |
| syr2k | 26.2s |
| dynprog | 41.1s |
| ludcmp | 20.8s |
| floyd-warshall | 15.5s |
| doitgen | 6.4s |

Tiling benefits most on kernels whose working set exceeds L2/L3 cache. At
2000×2000, a single double-precision matrix is 32 MB — well above typical L3.
Expect 1.5–4× speedup on gemm-class kernels; stencils (jacobi, seidel) will
show little gain since they have low arithmetic intensity.

Correctness: POLYBENCH_DUMP_ARRAYS is disabled at this size, so compare.sh
will show MATCH for all benchmarks (empty output files diff as equal). Treat
all MATCH results here as timing-only; correctness was validated on
SMALL_DATASET in the `../tiling-tile32-small-dataset/` experiment.
