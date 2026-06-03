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
preproc.sh           .F90 + .h  →  .preproc.f90   cpp: expand dataset size + dump-arrays macros
compile.sh           .preproc.f90 → .exe           flang-22 -O3 -fopenmp + utilities/fpolybench.c
execute.sh           .exe         → .output.txt    capture timing + live-out array dump
weave.sh             .preproc.f90 → woven_code/    source-to-source transform via metafor-omp (OpenMP)
weave-transpiler.sh  .preproc.f90 → woven_code/    source-to-source transform via fortran-transpiler
compare.sh           original vs woven → correctness check + speedup table
run-all-transforms.sh               runs all 5 loop transforms in sequence
```

`weave.sh` targets `$HOME/metafor-omp` (OpenMP auto-parallelizer). A `scripts/analyse.js`
file must exist there — it is **not** committed to this repo.

`weave-transpiler.sh` targets `../fortran-transpiler` (loop transformations — see below).

Compiler: `flang-22` + `clang-22`. Flags: `-O3 -fopenmp`.

---

## Quick-Start: end-to-end with fortran-transpiler

```bash
# 1. Build the transpiler (once)
cd ../fortran-transpiler/Fortran-JS
npm install && npm run build
cd -

# 2. Preprocess all 30 benchmarks
./preproc.sh

# 3. Compile originals and capture baseline timing
./compile.sh
./execute.sh

# 4. Apply a loop transformation to all 30 benchmarks
./weave-transpiler.sh tilingGeneric

# 5. Compile the transformed versions
./compile.sh

# 6. Run transformed versions and compare
./execute.sh
./compare.sh
```

### Single-benchmark example (3mm with loop tiling)

```bash
# Run from the fortran-transpiler directory
export NVM_DIR="$HOME/.nvm" && \. "$NVM_DIR/nvm.sh" && nvm use 22
cd ../fortran-transpiler/Fortran-JS

npx metafor classic api/examples/tilingGeneric.js \
    -p ../../polybench-metafor/linear-algebra/kernels/3mm/3mm.preproc.f90 \
    -o ../../polybench-metafor/linear-algebra/kernels/3mm/

# Transformed output appears in:
#   linear-algebra/kernels/3mm/woven_code/
```

---

## Connection with ../fortran-transpiler

`../fortran-transpiler` (`@specs-feup/metafor`) is a source-to-source Fortran compiler built on the
LARA metaprogramming framework. It applies **loop transformations** (as opposed to metafor-omp which
inserts OpenMP directives). It is the same underlying metafor framework — a different script set.

### Build prerequisites

The transpiler must be built before `weave-transpiler.sh` can run:

```bash
export NVM_DIR="$HOME/.nvm" && \. "$NVM_DIR/nvm.sh"
nvm use 22
cd ../fortran-transpiler/Fortran-JS
npm install
npm run build       # tsc -b src-api src-code → produces api/ and code/
```

Verify the build succeeded:

```bash
ls ../fortran-transpiler/Fortran-JS/code/index.js   # must exist
```

**Java binaries** — the metafor framework bridges to a JVM at runtime. The
`java-binaries/` directory must be present inside `Fortran-JS/`. It is excluded
from git (`.gitignore`) and must be obtained from CI artifacts or a local Gradle
build of `FortranWeaver/`. Without it, `npx metafor` will fail with a JVM/classpath error.

### Loop transformations in fortran-transpiler

| Transform | Generic script (polybench) | Pass class |
|---|---|---|
| Loop tiling | `tilingGeneric.ts` | `LoopTilingPass(32)` |
| Loop unrolling | `unrollGeneric.ts` | `LoopUnrollPass(4)` |
| Loop fusion | `fusionGeneric.ts` | `LoopFusionPass()` |
| Loop fission | `fissionGeneric.ts` | `LoopFissionPass()` |
| Loop interchange | `interchangeGeneric.ts` | manual (no pass class) |

All generic scripts match any subroutine whose name starts with `kernel_` — one per `.preproc.f90` file:

```typescript
Query.search(Subroutine, ($jp) => $jp.moduleName.startsWith('kernel_')).get()
```

The original single-benchmark examples (`loopTiling.ts`, `unrollInnermost.ts`, etc.) are hardcoded
to `kernel_3mm` and live in `fortran-transpiler/Fortran-JS/src-api/examples/`.

### Build the transpiler

```bash
cd ../fortran-transpiler/Fortran-JS
npm install
npm run build
```

### Invoke a single benchmark manually

```bash
cd ../fortran-transpiler/Fortran-JS
npx metafor classic api/examples/tilingGeneric.js \
    -p ../../polybench-metafor/linear-algebra/kernels/3mm/3mm.preproc.f90 \
    -o ../../polybench-metafor/linear-algebra/kernels/3mm/
```

---

## Applying fortran-transpiler across all 30 benchmarks

### Step 1 — Preprocess

```bash
./preproc.sh
```

Produces `*.preproc.f90` throughout the tree.

### Step 2 — Run a transformation

```bash
./weave-transpiler.sh [TRANSFORM]
```

`TRANSFORM` defaults to `tilingGeneric`. Valid values:

| TRANSFORM | What it does |
|---|---|
| `tilingGeneric` | Loop tiling with tile size 32 |
| `unrollGeneric` | Innermost loop unrolling by factor 4 |
| `fusionGeneric` | Loop fusion |
| `fissionGeneric` | Loop fission |
| `interchangeGeneric` | Loop interchange (unsafe for non-perfect nests) |

`woven_code/` output goes inside each benchmark's directory. Running two transforms in sequence
overwrites the same `woven_code/` directories. To keep results separate, rename between runs:

```bash
./weave-transpiler.sh tilingGeneric
find . -type d -name woven_code -exec sh -c \
    'mv "$1" "$(dirname "$1")/woven_code_tiling"' _ {} \;
./weave-transpiler.sh unrollGeneric
```

To run all 5 transforms in sequence (results will be overwritten each time):

```bash
./run-all-transforms.sh
```

### Step 3 — Compile, execute, compare

```bash
./compile.sh
./execute.sh
./compare.sh
```

`compare.sh` prints a table: benchmark name, whether OpenMP/transform directives were inserted,
whether output matches, original time, and speedup.

### Known caveats

- **`interchangeGeneric`** does not check legality. Benchmarks with triangular loop bounds
  (e.g. `cholesky`, `trisolv`) will produce incorrect output after interchange.
- **`moduleName` case**: `startsWith('kernel_')` is case-sensitive. If the Fortran parser
  uppercases identifiers, the predicate will silently skip all subroutines. Test with one
  benchmark first; add `.toLowerCase()` if needed.
- The metafor tool creates `woven_code/` inside the directory passed to `-o`. `compare.sh`
  searches for `woven_code/` directories, so pass `-o "$bench_dir"` (not `-o "$bench_dir/woven_code"`).
