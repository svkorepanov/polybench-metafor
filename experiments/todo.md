# Experiment Playbook

End-to-end guide: fresh machine → running a loop transformation experiment across all 30
PolyBench/Fortran benchmarks and capturing results.

---

## 1. System Dependencies

### 1.1 Compiler toolchain

```bash
# LLVM/Flang 22 + Clang 22 (Fortran + C compiler)
wget -qO- https://apt.llvm.org/llvm.sh | bash -s -- 22
apt-get install -y flang-22 clang-22

# Verify
flang-22 --version   # should print "flang version 22.x.x"
clang-22 --version
```

### 1.2 Java (required by the metafor JVM bridge)

```bash
apt-get install -y openjdk-21-jdk

# Verify
java -version        # openjdk 21.x.x
```

### 1.3 Node.js via NVM (required by fortran-transpiler)

```bash
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash
export NVM_DIR="$HOME/.nvm" && . "$NVM_DIR/nvm.sh"

nvm install 22
nvm use 22
node --version       # v22.x.x
npm --version
```

Add to `~/.bashrc` or `~/.zshrc` so NVM loads in every shell:
```bash
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
```

---

## 2. Repository Setup

### 2.1 Clone polybench-metafor (this repo)

```bash
git clone <polybench-metafor-url> polybench-metafor
cd polybench-metafor
```

### 2.2 Clone fortran-transpiler (sibling directory)

```bash
# Must be placed at ../fortran-transpiler relative to polybench-metafor
cd ..
git clone <fortran-transpiler-url> fortran-transpiler
```

The expected directory layout:

```
parent/
  polybench-metafor/    ← this repo
  fortran-transpiler/   ← transpiler (sibling)
    Fortran-JS/
      src-api/
      src-code/
      java-binaries/    ← JVM bridge (NOT in git — see §2.3)
```

### 2.3 Obtain java-binaries (JVM bridge)

`java-binaries/` is excluded from git. Obtain it from CI artifacts or a Gradle build
of `FortranWeaver/`:

```bash
# Option A — copy from CI artifact
cp -r /path/to/artifact/java-binaries fortran-transpiler/Fortran-JS/

# Option B — build from source (requires Gradle)
cd fortran-transpiler/FortranWeaver
./gradlew jar
# then copy the produced jar into Fortran-JS/java-binaries/
```

Without `java-binaries/`, every `npx metafor` call fails with a JVM/classpath error.

### 2.4 Build fortran-transpiler

```bash
export NVM_DIR="$HOME/.nvm" && . "$NVM_DIR/nvm.sh" && nvm use 22

cd fortran-transpiler/Fortran-JS
npm install
npm run build        # tsc -b src-api src-code → produces api/ and code/

# Verify
ls code/index.js     # must exist
```

Rebuild whenever TypeScript source under `src-api/` or `src-code/` changes.

---

## 3. Configure the Dataset

Two macros control dataset size and output mode. They must be set **identically** in both
`preproc.sh` and `compile.sh` — a mismatch causes silent timer failures (0-byte output).

Edit the `PARGS` line in **both** scripts:

| Goal | preproc.sh `PARGS` | compile.sh `PARGS` |
|---|---|---|
| Correctness check (small, with array dump) | `-I $UTILITIES_DIR -DSMALL_DATASET -DPOLYBENCH_DUMP_ARRAYS` | `-DSMALL_DATASET -DPOLYBENCH_DUMP_ARRAYS` |
| Timing only (small) | `-I $UTILITIES_DIR -DSMALL_DATASET -DPOLYBENCH_TIME` | `-DSMALL_DATASET -DPOLYBENCH_TIME` |
| Timing only (large, production scale) | `-I $UTILITIES_DIR -DLARGE_DATASET -DPOLYBENCH_TIME` | `-DLARGE_DATASET -DPOLYBENCH_TIME` |

**`-DPOLYBENCH_TIME` must appear in `preproc.sh`**: the timer macros are expanded by cpp
at preprocessing time. If the flag is only in `compile.sh`, all benchmarks produce 0-byte
output and the speedup column in compare.sh shows garbage.

**`POLYBENCH_DUMP_ARRAYS` is incompatible with LARGE_DATASET**: a single 2000×2000 double
matrix is 32 MB; dumping all 30 benchmarks × 2 runs ≈ 10 GB. Use `POLYBENCH_TIME` at
LARGE_DATASET and validate correctness separately at SMALL_DATASET.

---

## 4. Running an Experiment

All scripts run from the `polybench-metafor/` root.

### Step 1 — Preprocess

Expands dataset-size macros and timer macros from `.F90 + .h` into `.preproc.f90`:

```bash
./preproc.sh
```

Re-run after changing `PARGS` in `preproc.sh` or after editing any `.h` header.

### Step 2 — Compile originals and capture baseline

```bash
./compile.sh    # produces *.exe for originals
./execute.sh    # produces *.output.txt for originals
```

`execute.sh` auto-skips `fdtd-apml` at LARGE_DATASET (4.3 GB allocation > RAM).

### Step 3 — Apply a loop transformation

```bash
./weave-transpiler.sh <TRANSFORM>
```

Valid `TRANSFORM` values:

| TRANSFORM | What it does | Legality guard |
|---|---|---|
| `tilingGeneric` | Loop tiling, tile size 32 | `canTile()` — rejects triangular bounds |
| `unrollGeneric` | Innermost loop unrolling ×4 | none needed (always safe) |
| `fusionGeneric` | Loop fusion | `_canFusePair()` — rejects anti-dep pairs |
| `fissionGeneric` | Loop fission | `canFission()` — rejects scalar threading + WAR deps |
| `interchangeGeneric` | Loop interchange | `canInterchange()` — rejects triangular inner bounds |

Output goes to `woven_code/` inside each benchmark's directory. Running a second transform
overwrites the same `woven_code/` directories; rename between runs to preserve both:

```bash
./weave-transpiler.sh tilingGeneric
find . -type d -name woven_code -exec sh -c \
    'mv "$1" "$(dirname "$1")/woven_code_tiling"' _ {} \;
./weave-transpiler.sh fusionGeneric
```

### Step 4 — Compile and execute transformed versions

```bash
./compile.sh    # compiles both *.preproc.f90 (original) and woven_code/*.f90
./execute.sh    # runs both; writes woven_code/*.output.txt
```

### Step 5 — Compare and save results

```bash
RESULT_DIR="experiments/<transform>-<params>-<dataset>"
mkdir -p "$RESULT_DIR"
./compare.sh | tee "$RESULT_DIR/results.txt"
```

`compare.sh` output columns: Benchmark | Status | Transform? | Result | Orig Time | Speedup

- **Transform? = YES** — legality guard passed, transform was applied
- **Transform? = NO** — legality guard blocked the transform (output is a copy of original)
- **Result = MATCH** — transformed output matches original (bit-exact after stripping timer)
- **Result = MISMATCH** — numerical divergence; indicates a legality bug in the transform

### Step 6 — Write analysis

```bash
# Suggested layout
experiments/<transform>-<params>-<dataset>/
  results.txt    # raw compare.sh output
  analysis.md    # interpretation: speedups, regressions, why
```

---

## 5. Running All 5 Transforms (Automated)

`run-iteration4.sh` runs all 5 transforms sequentially and saves results to
`experiments/<transform>-large-dataset/results.txt` and a combined summary to
`experiments/issues/iteration-4/results-summary.txt`.

Use nohup for runs that take hours (LARGE_DATASET O(n³) benchmarks: 90–260 s each):

```bash
nohup ./run-iteration4.sh > experiments/issues/iteration-4/nohup.log 2>&1 &
tail -f experiments/issues/iteration-4/nohup.log
```

Total wall time at LARGE_DATASET: ~4 hours.

---

## 6. Single-Benchmark Debugging

To test one benchmark without running the full suite:

```bash
export NVM_DIR="$HOME/.nvm" && . "$NVM_DIR/nvm.sh" && nvm use 22
cd ../fortran-transpiler/Fortran-JS

npx metafor classic api/examples/tilingGeneric.js \
    -p ../../polybench-metafor/linear-algebra/kernels/3mm/3mm.preproc.f90 \
    -o ../../polybench-metafor/linear-algebra/kernels/3mm/

# Transformed file appears at:
# linear-algebra/kernels/3mm/woven_code/3mm.f90
```

Then compile and run manually:
```bash
cd ../../polybench-metafor
flang-22 -O3 -fopenmp linear-algebra/kernels/3mm/3mm.preproc.f90 \
    utilities/fpolybench.o -I utilities/ \
    -o linear-algebra/kernels/3mm/3mm.exe
./linear-algebra/kernels/3mm/3mm.exe
```

---

## 7. Known Pitfalls (Lessons from Iterations 1–4)

### `-DPOLYBENCH_TIME` must be in both `preproc.sh` and `compile.sh`

Timer macros (`polybench_start`, `polybench_stop`, `polybench_print_instruments`) are cpp
macros that expand at `preproc.sh` time. If `-DPOLYBENCH_TIME` is missing from `preproc.sh`,
the `.preproc.f90` files contain no timer calls and all benchmarks produce 0-byte output.

Diagnosis: `grep "timer" <benchmark>.preproc.f90` — must show `call polybench_timer_start()`.

### `tee -a` accumulates across runs

If a results file already exists and you use `tee -a`, the new results are appended after
the old ones, creating two tables in one file. Use plain `tee` (no `-a`) when capturing
results for a specific experiment directory.

### Stale output files after switching datasets

After switching from SMALL_DATASET to LARGE_DATASET, old `*.output.txt` files may linger
(especially for blacklisted benchmarks like `fdtd-apml` whose `execute.sh` skip leaves
the old file in place). `compare.sh` will find both files and compare them → MISMATCH.

Clean before switching:
```bash
find . -name "*.output.txt" -delete
```

### `woven_code/` from a previous transform is reused

`compile.sh` compiles every `*.preproc.f90` it finds, including inside `woven_code/`.
If you forget to run `weave-transpiler.sh` before `compile.sh`, the previous transform's
output is compiled and compared instead of the new one. Always weave → compile → execute
in that order.

### `interchangeGeneric` is legal but not always profitable

`canInterchange()` rejects structurally unsound interchange (triangular bounds). However,
interchange can be numerically correct but cache-hostile: in Fortran column-major storage,
interchanging the j-inner (stride-1) with i-inner (stride-N) on a large `A(j,i)` array
causes a cache miss on every element. At LARGE_DATASET (n=2000, 32 MB arrays) this
degrades to 0.06–0.08x. The transform still produces MATCH — the slowdown is not a
correctness issue.

### `moduleName` case sensitivity

`weave-transpiler.sh` generic scripts match `$jp.moduleName.startsWith('kernel_')`.
If the Fortran parser uppercases identifiers, this predicate silently skips all subroutines
and every benchmark shows Transform? = NO. Test with one benchmark first; add `.toLowerCase()`
to the predicate if needed.

---

## 8. Future Experiment Ideas

| Idea | Script to write | Expected gain |
|---|---|---|
| Tiling with tile size 64 | `tilingGeneric64.ts` (`LoopTilingPass(64)`) | Better L2 reuse for gemm/symm/3mm |
| Tiling + unrolling combined | compose passes in sequence | Vectorizer-friendly innermost loop |
| Interchange profitability filter | skip if innermost index == array first dim | Prevent 0.06x regressions in fdtd-2d/adi |
| MEDIUM_DATASET timing sweep | change `PARGS` to `-DMEDIUM_DATASET` | Intermediate cache-size sensitivity data |
| OpenMP parallelization (metafor-omp) | `weave.sh` (already exists) | Thread-level speedup on multi-core |
| Fusion of non-adjacent loops | extend `_canFusePair()` to look past scalars | Fuse more than 8/30 benchmarks |
| Tile size sweep (16, 32, 64, 128) | parametric script + outer loop in run script | Find optimal tile size per benchmark class |

---

## 9. Experiment Log (Cross-reference)

Full iteration history and per-experiment analysis in `experiments/issues/`:

| Iteration | Scope | Key finding |
|---|---|---|
| [iteration-1](issues/iteration-1/) | All 5 transforms, SMALL_DATASET | Baseline: 30/30 unroll; 21–28/30 others — identified mismatches |
| [iteration-2](issues/iteration-2/) | Fix fusion + interchange legality | `_canFusePair()` + `canInterchange()` added; 30/30 fusion + interchange |
| [iteration-3](issues/iteration-3/) | Fix tiling + fission legality | `canTile()` `searchFromInclusive` bug fixed + `canFission()` added; 30/30 all 5 |
| [iteration-4](issues/iteration-4/) | All 5 transforms, LARGE_DATASET | 29/30 each (fdtd-apml OOM); mvt 6.68x (tiling), jacobi-2d 1.59x (fusion) |
