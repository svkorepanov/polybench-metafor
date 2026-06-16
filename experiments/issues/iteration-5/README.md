# Iteration 5 — Setup Correctness Check (SMALL_DATASET)

## Goal

Verify that all 5 loop transforms produce 30/30 MATCH on a fresh machine.
This iteration is the first thing to run after setting up a new environment —
it confirms the full toolchain (flang-22, Node 22, java-binaries, fortran-transpiler)
is wired together correctly before committing to a multi-hour LARGE_DATASET run.

## Dataset

`SMALL_DATASET` with `POLYBENCH_DUMP_ARRAYS` — full array values are written to
output files so `compare.sh` can diff them directly. Any numerical divergence
caused by an incorrect transformation shows up as MISMATCH. This is a stricter
check than the LARGE_DATASET / POLYBENCH_TIME runs in iteration-4, where only
the exit code is compared.

## Scripts

| Script | Purpose |
|---|---|
| `run-iteration5.sh` | Setup check + all 5 transforms on SMALL_DATASET |
| `run-single.sh` | One benchmark × one transform, full pipeline inline |

### run-iteration5.sh

```bash
./run-iteration5.sh
```

1. Checks prerequisites: flang-22, clang-22, java 21+, node 22, transpiler built,
   java-binaries present. Aborts if any check fails.
2. Patches `preproc.sh` and `compile.sh` to use SMALL_DATASET + DUMP_ARRAYS,
   restoring them on exit via `trap`.
3. Runs preproc → compile → execute for originals.
4. For each of 5 transforms: weave → compile → execute → compare.
5. Saves per-transform results to this directory and a combined summary to
   `results-summary.txt`.

Expected outcome: 30/30 MATCH for every transform (fdtd-apml SKIPPED if
FDTD_DIM < 256 at SMALL_DATASET — it should not be blacklisted here).

### run-single.sh

```bash
./run-single.sh <benchmark> <transform> [SMALL_DATASET|LARGE_DATASET]
```

Runs the complete pipeline for one benchmark inline — no shared scripts to
patch. Useful for debugging a single failing case without re-running all 30.

```bash
# Examples
./run-single.sh 3mm tilingGeneric
./run-single.sh jacobi-2d-imper fusionGeneric SMALL_DATASET
./run-single.sh gemm unrollGeneric LARGE_DATASET
```

## Expected results

| Transform | Applied | MATCH | Notes |
|---|---|---|---|
| tilingGeneric | 21/30 | 30/30 | `canTile()` skips triangular nests |
| unrollGeneric | 30/30 | 30/30 | always applies |
| fusionGeneric | 8/30 | 30/30 | `_canFusePair()` guards anti-deps |
| fissionGeneric | 10/30 | 30/30 | `canFission()` guards scalar + WAR deps |
| interchangeGeneric | 17/30 | 30/30 | `canInterchange()` guards triangular bounds |

These match iteration-3 results (SMALL_DATASET correctness baseline).

## Prior context

Iterations 1–3 established these results and the legality checks that achieve
30/30 MATCH. Iteration-4 extended to LARGE_DATASET for performance measurement.
This iteration re-runs SMALL_DATASET as a quick sanity check for new machines.
