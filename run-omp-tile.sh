#!/bin/bash

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
UTILITIES_DIR="$ROOT_DIR/utilities"
FC="flang-22"
CC="clang-22"
PARGS="-I $UTILITIES_DIR -DLARGE_DATASET -DPOLYBENCH_TIME"
FFLAGS="-O3 -fopenmp -fopenmp-version=51 -Wno-ignored-directive -L/usr/lib/llvm-20/lib"
WFLAGS="-O3 -fopenmp -Wno-ignored-directive -L/usr/lib/llvm-20/lib"
CFLAGS="-O3 -fopenmp -I/usr/lib/gcc/x86_64-linux-gnu/15/include"
BLACKLIST="fdtd-apml"

cd "$ROOT_DIR"

get_timer() {
    grep -oE '[-+]?[0-9]*\.?[0-9]+([eE][-+]?[0-9]+)?' "$1" 2>/dev/null | tail -n 1
}

# ── C utilities ─────────────────────────────────────────────────────────────
echo "=== Compiling C utilities ==="
$CC -c -DLARGE_DATASET -DPOLYBENCH_TIME $CFLAGS \
    "$UTILITIES_DIR/fpolybench.c" -I "$UTILITIES_DIR" \
    -o "$UTILITIES_DIR/fpolybench.o"

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
    exe="${f%.F90}.exe"
    bench=$(basename "$(dirname "$f")")
    echo "  $bench"
    $FC $FFLAGS "$preproc" "$UTILITIES_DIR/fpolybench.o" -I "$UTILITIES_DIR" -o "$exe" \
        || echo "  [!] compile failed: $bench"
done < <(find . -name "*.omp-tile.F90" | sort)

# ── OMP-TILE: execute ────────────────────────────────────────────────────────
echo "=== Executing .omp-tile ==="
while IFS= read -r f; do
    exe="${f%.F90}.exe"
    dir=$(dirname "$f")
    base=$(basename "${f%.F90}")
    bench=$(basename "$dir")
    output="$dir/$base.output.txt"
    if echo "$BLACKLIST" | grep -qw "$bench"; then
        echo "  Skipping (OOM): $bench"; continue
    fi
    echo "  $bench"
    "./$exe" > "$output" 2>&1 || echo "  [!] runtime error: $bench"
done < <(find . -name "*.omp-tile.F90" | sort)

# ── WOVEN_CODE: compile ──────────────────────────────────────────────────────
echo "=== Compiling woven_code (tilingGeneric) ==="
while IFS= read -r woven_dir; do
    bench=$(basename "$(dirname "$woven_dir")")
    preproc="$woven_dir/$bench.preproc.f90"
    exe="$woven_dir/$bench.exe"
    echo "  $bench"
    $FC $WFLAGS "$preproc" "$UTILITIES_DIR/fpolybench.o" -I "$UTILITIES_DIR" -o "$exe" \
        || echo "  [!] compile failed: $bench (woven)"
done < <(find . -type d -name "woven_code" | sort)

# ── WOVEN_CODE: execute ──────────────────────────────────────────────────────
echo "=== Executing woven_code (tilingGeneric) ==="
while IFS= read -r woven_dir; do
    bench=$(basename "$(dirname "$woven_dir")")
    exe="$woven_dir/$bench.exe"
    output="$woven_dir/$bench.output.txt"
    if echo "$BLACKLIST" | grep -qw "$bench"; then
        echo "  Skipping (OOM): $bench"; continue
    fi
    echo "  $bench"
    "./$exe" > "$output" 2>&1 || echo "  [!] runtime error: $bench (woven)"
done < <(find . -type d -name "woven_code" | sort)

# ── Comparison table ─────────────────────────────────────────────────────────
echo ""
echo "=== tilingGeneric (transpiler) vs omp-tile (manual) ==="
printf "%-18s | %-12s | %-12s | %-13s | %-13s | %-14s\n" \
    "Benchmark" "Orig Time" "Woven Time" "Woven Spdup" "OMP-Tile Time" "OMP-Tile Spdup"
echo "--------------------------------------------------------------------------------------------"

while IFS= read -r f; do
    dir=$(dirname "$f")
    bench=$(basename "$dir")
    base=$(basename "${f%.F90}")

    t_orig=$(get_timer    "$dir/$bench.output.txt")
    t_woven=$(get_timer   "$dir/woven_code/$bench.output.txt")
    t_omptile=$(get_timer "$dir/$base.output.txt")

    [[ -z "$t_orig" ]]    && t_orig="-"
    [[ -z "$t_woven" ]]   && t_woven="-"
    [[ -z "$t_omptile" ]] && t_omptile="crash/skip"

    if [[ "$t_orig" != "-" && "$t_woven" != "-" ]]; then
        spd_woven=$(awk "BEGIN {printf \"%.2fx\", $t_orig / $t_woven}")
    else
        spd_woven="-"
    fi

    if [[ "$t_orig" != "-" && "$t_omptile" != "crash/skip" && "$t_omptile" != "-" ]]; then
        spd_omptile=$(awk "BEGIN {printf \"%.2fx\", $t_orig / $t_omptile}")
    else
        spd_omptile="-"
    fi

    printf "%-18s | %-12s | %-12s | %-13s | %-13s | %-14s\n" \
        "$bench" "$t_orig" "$t_woven" "$spd_woven" "$t_omptile" "$spd_omptile"

done < <(find . -name "*.omp-tile.F90" | sort)

echo "============================================================================================"
