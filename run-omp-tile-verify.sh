#!/bin/bash

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
UTILITIES_DIR="$ROOT_DIR/utilities"
FC="flang-22"
CC="clang-22"
PARGS="-I $UTILITIES_DIR -DSMALL_DATASET -DPOLYBENCH_DUMP_ARRAYS"
FFLAGS="-O3 -fopenmp -fopenmp-version=51 -Wno-ignored-directive -L/usr/lib/llvm-20/lib"
WFLAGS="-O3 -fopenmp -Wno-ignored-directive -L/usr/lib/llvm-20/lib"
CFLAGS="-O3 -fopenmp -I/usr/lib/gcc/x86_64-linux-gnu/15/include"
BLACKLIST="fdtd-apml"

cd "$ROOT_DIR"

# ── C utilities ─────────────────────────────────────────────────────────────
echo "=== Compiling C utilities ==="
$CC -c -DSMALL_DATASET -DPOLYBENCH_DUMP_ARRAYS $CFLAGS \
    "$UTILITIES_DIR/fpolybench.c" -I "$UTILITIES_DIR" \
    -o "$UTILITIES_DIR/fpolybench_small.o"

# ── OMP-TILE: preprocess ─────────────────────────────────────────────────────
echo "=== Preprocessing .omp-tile.F90 ==="
while IFS= read -r f; do
    bench=$(basename "$(dirname "$f")")
    echo "  $bench"
    bash "$UTILITIES_DIR/create_pped_version.sh" "$f" "$PARGS"
done < <(find . -name "*.omp-tile.F90" | sort)

# ── OMP-TILE: compile ────────────────────────────────────────────────────────
echo "=== Compiling .omp-tile ==="
while IFS= read -r f; do
    preproc="${f%.F90}.preproc.f90"
    exe="${f%.F90}.small.exe"
    bench=$(basename "$(dirname "$f")")
    echo "  $bench"
    $FC $FFLAGS "$preproc" "$UTILITIES_DIR/fpolybench_small.o" -I "$UTILITIES_DIR" -o "$exe" \
        || echo "  [!] compile failed: $bench"
done < <(find . -name "*.omp-tile.F90" | sort)

# ── OMP-TILE: execute ────────────────────────────────────────────────────────
echo "=== Executing .omp-tile ==="
while IFS= read -r f; do
    exe="${f%.F90}.small.exe"
    dir=$(dirname "$f")
    base=$(basename "${f%.F90}")
    bench=$(basename "$dir")
    output="$dir/$base.dump.txt"
    if echo "$BLACKLIST" | grep -qw "$bench"; then
        echo "  Skipping (blacklist): $bench"; continue
    fi
    echo "  $bench"
    "./$exe" > "$output" 2>&1 || echo "  [!] runtime error: $bench"
done < <(find . -name "*.omp-tile.F90" | sort)

# ── ORIGINAL: preprocess ────────────────────────────────────────────────────
echo "=== Preprocessing original .F90 (for tilingGeneric) ==="
while IFS= read -r f; do
    bench_dir=$(dirname "$f")
    bench=$(basename "$bench_dir")
    orig_f90="$bench_dir/$bench.F90"
    echo "  $bench"
    bash "$UTILITIES_DIR/create_pped_version.sh" "$orig_f90" "$PARGS" \
        || echo "  [!] preprocess failed: $bench"
done < <(find . -name "*.omp-tile.F90" | sort)

# ── ORIGINAL: apply tilingGeneric ───────────────────────────────────────────
echo "=== Applying tilingGeneric (transpiler) ==="
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh" && nvm use 22
TRANSPILER_ROOT="$(cd "$ROOT_DIR/../fortran-transpiler/Fortran-JS" && pwd)"
TRANSFORM_SCRIPT="api/examples/tilingGeneric.js"

while IFS= read -r f; do
    bench_dir=$(dirname "$f")
    bench=$(basename "$bench_dir")
    abs_bench_dir=$(realpath "$bench_dir")
    abs_preproc="$abs_bench_dir/$bench.preproc.f90"
    echo "  $bench"
    (cd "$TRANSPILER_ROOT" && npx metafor classic "$TRANSFORM_SCRIPT" \
        -p "$abs_preproc" -o "$abs_bench_dir" 2>&1) \
        || echo "  [!] transpiler failed: $bench"
done < <(find . -name "*.omp-tile.F90" | sort)

# ── WOVEN_CODE: compile ──────────────────────────────────────────────────────
echo "=== Compiling woven_code (tilingGeneric) ==="
while IFS= read -r woven_dir; do
    bench=$(basename "$(dirname "$woven_dir")")
    preproc="$woven_dir/$bench.preproc.f90"
    exe="$woven_dir/$bench.small.exe"
    echo "  $bench"
    $FC $WFLAGS "$preproc" "$UTILITIES_DIR/fpolybench_small.o" -I "$UTILITIES_DIR" -o "$exe" \
        || echo "  [!] compile failed: $bench (woven)"
done < <(find . -type d -name "woven_code" | sort)

# ── WOVEN_CODE: execute ──────────────────────────────────────────────────────
echo "=== Executing woven_code (tilingGeneric) ==="
while IFS= read -r woven_dir; do
    bench=$(basename "$(dirname "$woven_dir")")
    exe="$woven_dir/$bench.small.exe"
    output="$woven_dir/$bench.dump.txt"
    if echo "$BLACKLIST" | grep -qw "$bench"; then
        echo "  Skipping (blacklist): $bench"; continue
    fi
    echo "  $bench"
    "./$exe" > "$output" 2>&1 || echo "  [!] runtime error: $bench (woven)"
done < <(find . -type d -name "woven_code" | sort)

# ── Array dump comparison ────────────────────────────────────────────────────
TABLE_OUT="$ROOT_DIR/results-omp-tile-verify.txt"

{
echo ""
echo "=== Array dump comparison: omp-tile (manual) vs tilingGeneric (transpiler) ==="
printf "%-18s | %-14s | %-14s\n" "Benchmark" "OMP-Tile dump" "Woven dump"
echo "------------------------------------------------------------"

matches=0; mismatches=0; missing=0

while IFS= read -r f; do
    dir=$(dirname "$f")
    bench=$(basename "$dir")
    base=$(basename "${f%.F90}")

    omptile_dump="$dir/$base.dump.txt"
    woven_dump="$dir/woven_code/$bench.dump.txt"

    if echo "$BLACKLIST" | grep -qw "$bench"; then
        printf "%-18s | %-14s | %-14s\n" "$bench" "skipped" "skipped"
        continue
    fi

    omptile_status="ok"
    woven_status="ok"
    [[ ! -f "$omptile_dump" ]] && omptile_status="missing"
    [[ ! -f "$woven_dump"   ]] && woven_status="missing"

    if [[ "$omptile_status" == "missing" || "$woven_status" == "missing" ]]; then
        printf "%-18s | %-14s | %-14s\n" "$bench" "$omptile_status" "$woven_status"
        ((missing++))
        continue
    fi

    if diff -q "$omptile_dump" "$woven_dump" > /dev/null 2>&1; then
        result="MATCH"
        ((matches++))
    else
        result="MISMATCH"
        ((mismatches++))
    fi

    printf "%-18s | %-14s | %-14s\n" "$bench" "$omptile_status" "$result"

done < <(find . -name "*.omp-tile.F90" | sort)

echo "============================================================"
echo "Results: $matches MATCH, $mismatches MISMATCH, $missing missing"
} | tee "$TABLE_OUT"

echo "Table saved to: $TABLE_OUT"
