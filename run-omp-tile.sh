#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
UTILITIES_DIR="$ROOT_DIR/utilities"
PREPROCESS_SCRIPT="$UTILITIES_DIR/create_pped_version.sh"
FC="flang-22"
CC="clang-22"
PARGS="-I $UTILITIES_DIR -DLARGE_DATASET -DPOLYBENCH_TIME"
FFLAGS="-O3 -fopenmp -fopenmp-version=51 -Wno-ignored-directive -L/usr/lib/llvm-20/lib"
CFLAGS="-O3 -fopenmp -I/usr/lib/gcc/x86_64-linux-gnu/15/include"

cd "$ROOT_DIR"

echo "=== Preprocessing .omp-tile.F90 files ==="
while IFS= read -r f; do
    echo "  $f"
    bash "$PREPROCESS_SCRIPT" "$f" "$PARGS"
done < <(find . -name "*.omp-tile.F90" | sort)

echo "=== Compiling C utilities ==="
$CC -c -DLARGE_DATASET -DPOLYBENCH_TIME $CFLAGS \
    "$UTILITIES_DIR/fpolybench.c" -I "$UTILITIES_DIR" \
    -o "$UTILITIES_DIR/fpolybench.o"

echo "=== Compiling .omp-tile benchmarks ==="
while IFS= read -r f; do
    preproc="${f%.F90}.preproc.f90"
    exe="${f%.F90}.exe"
    echo "  Building: $exe"
    $FC $FFLAGS "$preproc" "$UTILITIES_DIR/fpolybench.o" -I "$UTILITIES_DIR" -o "$exe"
done < <(find . -name "*.omp-tile.F90" | sort)

echo "=== Executing .omp-tile benchmarks ==="
while IFS= read -r f; do
    exe="${f%.F90}.exe"
    dir=$(dirname "$exe")
    base=$(basename "$exe" .exe)
    output="$dir/$base.output.txt"
    echo "  Running: $base"
    "./$exe" > "$output" 2>&1
done < <(find . -name "*.omp-tile.F90" | sort)

echo "=== Done ==="
