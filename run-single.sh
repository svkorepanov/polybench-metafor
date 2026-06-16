#!/bin/bash
# run-single.sh — run one benchmark with one transformation end-to-end
#
# Usage:
#   ./run-single.sh <benchmark> <transform> [SMALL_DATASET|LARGE_DATASET]
#
# Examples:
#   ./run-single.sh 3mm      tilingGeneric
#   ./run-single.sh jacobi-2d-imper fusionGeneric SMALL_DATASET
#   ./run-single.sh gemm     unrollGeneric LARGE_DATASET
#
# Transforms: tilingGeneric unrollGeneric fusionGeneric fissionGeneric interchangeGeneric

set -euo pipefail

BENCHMARK="${1:?Usage: $0 <benchmark> <transform> [SMALL_DATASET|LARGE_DATASET]}"
TRANSFORM="${2:?Usage: $0 <benchmark> <transform> [SMALL_DATASET|LARGE_DATASET]}"
DATASET="${3:-SMALL_DATASET}"

POLYBENCH_ROOT="$(cd "$(dirname "$0")" && pwd)"
UTILITIES_DIR="$POLYBENCH_ROOT/utilities"
TRANSPILER_JS="$POLYBENCH_ROOT/../fortran-transpiler/Fortran-JS"

# ── Flags ─────────────────────────────────────────────────────────────────────
if [ "$DATASET" = "SMALL_DATASET" ]; then
    PARGS="-DSMALL_DATASET -DPOLYBENCH_DUMP_ARRAYS"
else
    PARGS="-DLARGE_DATASET -DPOLYBENCH_TIME"
fi

# Detect machine-specific paths so the script works across different distros
GCC_INC=$(ls -d /usr/lib/gcc/x86_64-linux-gnu/*/include 2>/dev/null | sort -V | tail -1)
LLVM_LIB=$(ls -d /usr/lib/llvm-*/lib 2>/dev/null | sort -V | tail -1)

FFLAGS="-O3 -fopenmp -Wno-ignored-directive${LLVM_LIB:+ -L$LLVM_LIB}"
CFLAGS="-O3 -fopenmp${GCC_INC:+ -I$GCC_INC}"

# ── Locate benchmark ──────────────────────────────────────────────────────────
BENCH_SRC=$(find "$POLYBENCH_ROOT" \
    -path "*/woven_code" -prune -o \
    -name "${BENCHMARK}.F90" -print | head -1)

if [ -z "$BENCH_SRC" ]; then
    echo "Error: benchmark '${BENCHMARK}' not found under $POLYBENCH_ROOT"
    exit 1
fi

BENCH_DIR="$(dirname "$BENCH_SRC")"
PREPROC="$BENCH_DIR/${BENCHMARK}.preproc.f90"
ORIG_EXE="$BENCH_DIR/${BENCHMARK}.exe"
ORIG_OUT="$BENCH_DIR/${BENCHMARK}.output.txt"
WOVEN_F90="$BENCH_DIR/woven_code/${BENCHMARK}.f90"
WOVEN_EXE="$BENCH_DIR/woven_code/${BENCHMARK}.exe"
WOVEN_OUT="$BENCH_DIR/woven_code/${BENCHMARK}.output.txt"

echo "Benchmark  : $BENCHMARK"
echo "Transform  : $TRANSFORM"
echo "Dataset    : $DATASET"
echo "Source     : $BENCH_SRC"
echo "PARGS      : $PARGS"
echo ""

# ── 1. Preprocess ─────────────────────────────────────────────────────────────
echo "--- 1. Preprocess ---"
PREPROC_ARGS="-I $UTILITIES_DIR $PARGS"
bash "$UTILITIES_DIR/create_pped_version.sh" "$BENCH_SRC" "$PREPROC_ARGS"
echo "  → $PREPROC"
echo ""

# ── 2. Compile C utility (fpolybench.o) ───────────────────────────────────────
echo "--- 2. Compile fpolybench.c ---"
clang-22 $CFLAGS $PARGS \
    -c "$UTILITIES_DIR/fpolybench.c" -I "$UTILITIES_DIR" \
    -o "$UTILITIES_DIR/fpolybench.o"
echo "  → $UTILITIES_DIR/fpolybench.o"
echo ""

# ── 3. Compile original ───────────────────────────────────────────────────────
echo "--- 3. Compile original ---"
flang-22 $FFLAGS $PARGS \
    "$PREPROC" "$UTILITIES_DIR/fpolybench.o" -I "$UTILITIES_DIR" \
    -o "$ORIG_EXE"
echo "  → $ORIG_EXE"
echo ""

# ── 4. Execute original ───────────────────────────────────────────────────────
echo "--- 4. Execute original ---"
"$ORIG_EXE" > "$ORIG_OUT" 2>&1
echo "  → $ORIG_OUT ($(wc -l < "$ORIG_OUT") lines)"
echo ""

# ── 5. Apply transformation ───────────────────────────────────────────────────
echo "--- 5. Apply $TRANSFORM ---"
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
nvm use 22

cd "$TRANSPILER_JS"
npx metafor classic "api/examples/${TRANSFORM}.js" \
    -p "$PREPROC" -o "$BENCH_DIR"
cd "$POLYBENCH_ROOT"
echo "  → $WOVEN_F90"
echo ""

# ── 6. Compile woven ──────────────────────────────────────────────────────────
echo "--- 6. Compile woven ---"
flang-22 $FFLAGS $PARGS \
    "$WOVEN_F90" "$UTILITIES_DIR/fpolybench.o" -I "$UTILITIES_DIR" \
    -o "$WOVEN_EXE"
echo "  → $WOVEN_EXE"
echo ""

# ── 7. Execute woven ──────────────────────────────────────────────────────────
echo "--- 7. Execute woven ---"
"$WOVEN_EXE" > "$WOVEN_OUT" 2>&1
echo "  → $WOVEN_OUT ($(wc -l < "$WOVEN_OUT") lines)"
echo ""

# ── 8. Compare ────────────────────────────────────────────────────────────────
echo "--- 8. Compare ---"
strip_timer() {
    perl -0777 -pe 's/\s*[\d.eE+-]+\s*$/\n/' "$1"
}

if diff -q <(strip_timer "$ORIG_OUT") <(strip_timer "$WOVEN_OUT") > /dev/null; then
    echo "  Result : MATCH"
else
    echo "  Result : MISMATCH"
    echo "  Diff (first 30 lines):"
    diff <(strip_timer "$ORIG_OUT") <(strip_timer "$WOVEN_OUT") | head -30 || true
fi
