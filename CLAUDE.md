# polybench-metafor — Project Overview

## What this repo is

30 PolyBench/Fortran benchmarks for evaluating compiler optimizations and automatic parallelization. Based on PolyBench/C 3.2, translated to Fortran.

### Benchmark categories
- `linear-algebra/kernels/` — 15 kernels (2mm, 3mm, atax, gemm, symm, syrk, trmm, …)
- `linear-algebra/solvers/` — 5 solvers (lu, gramschmidt, durbin, …)
- `stencils/` — 6 benchmarks (jacobi-1d, jacobi-2d, fdtd-2d, adi, seidel-2d, …)
- `datamining/` — 2 benchmarks (correlation, covariance)
- `medley/` — 2 benchmarks (floyd-warshall, reg_detect)

Every benchmark: one `.F90` source + one `.h` header with dataset size macros.

### Structural pattern in every benchmark

Each benchmark exposes a `kernel_<name>` subroutine whose hot loop nest is marked for polyhedral analysis:

```fortran
subroutine kernel_<name>(...)
  !$pragma scop
    do i = ...
      do j = ...
        ! array work
      end do
    end do
  !$pragma endscop
end subroutine
```

---

## Script pipeline

```
preproc.sh    .F90 + .h  →  .preproc.f90   cpp: expand dataset size + dump-arrays macros
compile.sh    .preproc.f90 → .exe           flang-22 -O3 -fopenmp + utilities/fpolybench.c
execute.sh    .exe         → .output.txt    capture timing + live-out array dump
weave.sh      .preproc.f90 → woven_code/   source-to-source transform via metafor
compare.sh    original vs woven → correctness check + speedup table
```

`weave.sh` currently targets `$HOME/metafor-omp` (OpenMP auto-parallelizer). A `scripts/analyse.js`
file must exist there — it is **not** committed to this repo.

Compiler: `flang-22` + `clang-22`. Flags: `-O3 -fopenmp`.

---

## Connection with ../fortran-transpiler

`../fortran-transpiler` (`@specs-feup/metafor`) is a source-to-source Fortran compiler built on the
LARA metaprogramming framework. It applies **loop transformations** (as opposed to metafor-omp which
inserts OpenMP directives). It is the same underlying metafor framework — a different script set.

### Loop transformations in fortran-transpiler

| Transform | Source file |
|---|---|
| Loop unrolling | `Fortran-JS/src-api/code/LoopUnroll.ts` |
| Loop tiling | `Fortran-JS/src-api/code/LoopTiling.ts` |
| Loop fusion | `Fortran-JS/src-api/code/LoopFusion.ts` |
| Loop fission | `Fortran-JS/src-api/code/LoopFision.ts` |
| Loop interchange | `Fortran-JS/src-api/examples/loopInterchange.ts` |

### Build the transpiler

```bash
cd ../fortran-transpiler/Fortran-JS
npm install
npm run build
```

### Invoke it on a single benchmark

```bash
cd ../fortran-transpiler/Fortran-JS
npx metafor classic src-api/examples/loopTiling.ts \
    -p ../../polybench-metafor/linear-algebra/kernels/3mm/3mm.preproc.f90 \
    -o ../../polybench-metafor/linear-algebra/kernels/3mm/woven_code
```

---

## Applying fortran-transpiler across all 30 benchmarks

### Step 1 — Preprocess

```bash
./preproc.sh
```

Produces `*.preproc.f90` throughout the tree.

### Step 2 — Generalize the transformation script

The existing example scripts in `fortran-transpiler/Fortran-JS/src-api/examples/` are **hardcoded
for `kernel_3mm`**. Create a generic version that finds any `kernel_*` subroutine:

```typescript
// e.g. Fortran-JS/src-api/examples/tilingGeneric.ts
import Query from "@specs-feup/lara/api/weaver/Query.js";
import LoopTilingPass from "../pass/LoopTilingPass.js";
import { Subroutine } from "../Joinpoints.js";

const subroutines = Query.search(Subroutine).get()
  .filter(s => s.moduleName.startsWith('kernel_'));

for (const sub of subroutines) {
  new LoopTilingPass(32).apply(sub);
}
```

### Step 3 — Create a weave script for fortran-transpiler

Create `weave-transpiler.sh` in this repo, modeled on `weave.sh`:

```bash
#!/bin/bash
TRANSPILER_ROOT="../fortran-transpiler/Fortran-JS"
SCRIPT="src-api/examples/tilingGeneric.ts"   # swap for any transformation
POLYBENCH_ROOT=$(pwd)

find . -path "*/woven_code" -prune -o -name "*.preproc.f90" -print | while read -r bench_file; do
    abs_bench=$(realpath "$bench_file")
    bench_dir=$(dirname "$abs_bench")

    cd "$TRANSPILER_ROOT" || exit
    npx metafor classic "$SCRIPT" -p "$abs_bench" -o "$bench_dir/woven_code"
    cd "$POLYBENCH_ROOT" || exit
done
```

### Step 4 — Compile, execute, compare (unchanged)

```bash
./compile.sh
./execute.sh
./compare.sh
```

`compare.sh` prints a table: benchmark name, whether OpenMP/transform directives were inserted,
whether output matches, original time, and speedup.
