# Baseline — SMALL_DATASET

Saved output files from a clean `./execute.sh` run with:
- `PARGS="-DSMALL_DATASET -DPOLYBENCH_DUMP_ARRAYS"`
- `flang-22 -O3 -fopenmp`
- No loop transformation applied

## Files

One `<benchmark>.output.txt` per benchmark (30 total). Each file contains
the array dump produced by `-DPOLYBENCH_DUMP_ARRAYS` followed by the cycle
counter from the polybench timer.

## How to restore baseline to benchmark directories

```bash
# From polybench-metafor/
while read bench; do
    src="experiments/baseline-small-dataset/${bench}.output.txt"
    dst=$(find . -maxdepth 4 -name "${bench}.output.txt" ! -path "*/woven_code/*" ! -path "*/experiments/*" | head -1)
    [ -f "$src" ] && [ -n "$dst" ] && cp "$src" "$dst"
done < utilities/benchmark_list
```

## Why this exists

`execute.sh` overwrites the `*.output.txt` files in each benchmark directory
on every run. Saving a known-good baseline here allows future experiments to:
- Skip re-running the baseline when only the woven version changed
- Restore the original output after a LARGE_DATASET run that overwrote the
  SMALL_DATASET results
- Cross-check a new baseline run for regressions
