#!/bin/bash
# Experiment: does fission → tiling improve tiling success rate vs tiling alone?
# All results saved to experiments/issues/iteration-8/

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
UTILITIES_DIR="$ROOT_DIR/utilities"
EXP_DIR="$ROOT_DIR/experiments/issues/iteration-8"
FC="flang-22"
CC="clang-22"
PARGS="-I $UTILITIES_DIR -DSMALL_DATASET -DPOLYBENCH_DUMP_ARRAYS"
WFLAGS="-O3 -fopenmp -Wno-ignored-directive -L/usr/lib/llvm-20/lib"
CFLAGS="-O3 -fopenmp -I/usr/lib/gcc/x86_64-linux-gnu/15/include"
BLACKLIST="fdtd-apml"

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh" && nvm use 22

TRANSPILER_ROOT="$(cd "$ROOT_DIR/../fortran-transpiler/Fortran-JS" && pwd)"
TILING_SCRIPT="api/examples/tilingGeneric.js"
FISSION_TILING_SCRIPT="api/examples/fissionTilingGeneric.js"

cd "$ROOT_DIR"
mkdir -p "$EXP_DIR"

# ── C utilities (small dataset) ───────────────────────────────────────────────
echo "=== Compiling C utilities (SMALL_DATASET) ==="
$CC -c -DSMALL_DATASET -DPOLYBENCH_DUMP_ARRAYS $CFLAGS \
    "$UTILITIES_DIR/fpolybench.c" -I "$UTILITIES_DIR" \
    -o "$UTILITIES_DIR/fpolybench_small.o"

# ── Preprocess all originals ──────────────────────────────────────────────────
echo "=== Preprocessing originals (SMALL_DATASET + DUMP_ARRAYS) ==="
while IFS= read -r bench_path; do
    bench_dir=$(dirname "$bench_path")
    bench=$(basename "$bench_dir")
    echo "  $bench"
    bash "$UTILITIES_DIR/create_pped_version.sh" "$bench_path" "$PARGS" \
        || echo "  [!] preprocess failed: $bench"
done < "$UTILITIES_DIR/benchmark_list"

# ── Compile & execute originals → reference dumps ─────────────────────────────
echo "=== Compiling originals ==="
while IFS= read -r bench_path; do
    bench_dir=$(dirname "$bench_path")
    bench=$(basename "$bench_dir")
    preproc="$bench_dir/$bench.preproc.f90"
    exe="$bench_dir/$bench.orig.small.exe"
    echo "  $bench"
    $FC $WFLAGS "$preproc" "$UTILITIES_DIR/fpolybench_small.o" -I "$UTILITIES_DIR" \
        -o "$exe" 2>/dev/null || echo "  [!] compile failed: $bench"
done < "$UTILITIES_DIR/benchmark_list"

echo "=== Executing originals ==="
while IFS= read -r bench_path; do
    bench_dir=$(dirname "$bench_path")
    bench=$(basename "$bench_dir")
    exe="$bench_dir/$bench.orig.small.exe"
    dump="$bench_dir/$bench.orig.dump.txt"
    if echo "$BLACKLIST" | grep -qw "$bench"; then echo "  Skipping: $bench"; continue; fi
    echo "  $bench"
    "./$exe" > "$dump" 2>&1 || echo "  [!] runtime error: $bench"
done < "$UTILITIES_DIR/benchmark_list"

# ─────────────────────────────────────────────────────────────────────────────
# PASS A: tilingGeneric (baseline)
# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "=== PASS A: tilingGeneric (baseline) ==="

declare -A tiling_status

while IFS= read -r bench_path; do
    bench_dir=$(dirname "$bench_path")
    bench=$(basename "$bench_dir")
    abs_dir=$(realpath "$bench_dir")
    abs_preproc="$abs_dir/$bench.preproc.f90"
    echo "  $bench"
    out=$(cd "$TRANSPILER_ROOT" && npx metafor classic "$TILING_SCRIPT" \
        -p "$abs_preproc" -o "$abs_dir" 2>&1)
    if echo "$out" | grep -q "TILED"; then
        tiling_status[$bench]="TILED"
    else
        tiling_status[$bench]="SKIPPED"
    fi
done < "$UTILITIES_DIR/benchmark_list"

echo "=== Compiling tilingGeneric woven_code ==="
while IFS= read -r bench_path; do
    bench_dir=$(dirname "$bench_path")
    bench=$(basename "$bench_dir")
    woven_dir="$bench_dir/woven_code"
    preproc="$woven_dir/$bench.preproc.f90"
    exe="$woven_dir/$bench.tiling.small.exe"
    echo "  $bench"
    if [[ ! -f "$preproc" ]]; then echo "  [!] no woven preproc: $bench"; continue; fi
    $FC $WFLAGS "$preproc" "$UTILITIES_DIR/fpolybench_small.o" -I "$UTILITIES_DIR" \
        -o "$exe" 2>/dev/null || echo "  [!] compile failed: $bench (woven-tiling)"
done < "$UTILITIES_DIR/benchmark_list"

echo "=== Executing tilingGeneric woven_code ==="
declare -A tiling_correct

while IFS= read -r bench_path; do
    bench_dir=$(dirname "$bench_path")
    bench=$(basename "$bench_dir")
    woven_dir="$bench_dir/woven_code"
    exe="$woven_dir/$bench.tiling.small.exe"
    dump="$woven_dir/$bench.tiling.dump.txt"
    orig_dump="$bench_dir/$bench.orig.dump.txt"
    if echo "$BLACKLIST" | grep -qw "$bench"; then
        tiling_correct[$bench]="skipped"
        continue
    fi
    echo "  $bench"
    if [[ ! -f "$exe" ]]; then tiling_correct[$bench]="no-exe"; continue; fi
    "./$exe" > "$dump" 2>&1 || true
    if [[ ! -f "$orig_dump" ]]; then
        tiling_correct[$bench]="no-ref"
    elif diff -q "$orig_dump" "$dump" > /dev/null 2>&1; then
        tiling_correct[$bench]="MATCH"
    else
        tiling_correct[$bench]="MISMATCH"
    fi
done < "$UTILITIES_DIR/benchmark_list"

# Save tilingGeneric woven files so fissionTiling can overwrite woven_code/
while IFS= read -r bench_path; do
    bench_dir=$(dirname "$bench_path")
    bench=$(basename "$bench_dir")
    woven_dir="$bench_dir/woven_code"
    tiling_save_dir="$bench_dir/woven_code_tiling"
    if [[ -d "$woven_dir" ]]; then
        rm -rf "$tiling_save_dir"
        cp -r "$woven_dir" "$tiling_save_dir"
    fi
done < "$UTILITIES_DIR/benchmark_list"

# ─────────────────────────────────────────────────────────────────────────────
# PASS B: fissionTilingGeneric (pipeline)
# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "=== PASS B: fissionTilingGeneric (pipeline) ==="

# Re-preprocess (woven_code may have been overwritten; original preproc is fine)
declare -A fission_tiling_status

while IFS= read -r bench_path; do
    bench_dir=$(dirname "$bench_path")
    bench=$(basename "$bench_dir")
    abs_dir=$(realpath "$bench_dir")
    abs_preproc="$abs_dir/$bench.preproc.f90"
    echo "  $bench"
    out=$(cd "$TRANSPILER_ROOT" && npx metafor classic "$FISSION_TILING_SCRIPT" \
        -p "$abs_preproc" -o "$abs_dir" 2>&1)
    if echo "$out" | grep -q "FISSIONED+TILED"; then
        fission_tiling_status[$bench]="FISSIONED+TILED"
    elif echo "$out" | grep -q "TILED"; then
        fission_tiling_status[$bench]="TILED"
    elif echo "$out" | grep -q "FISSIONED only"; then
        fission_tiling_status[$bench]="FISSIONED_ONLY"
    else
        fission_tiling_status[$bench]="SKIPPED"
    fi
done < "$UTILITIES_DIR/benchmark_list"

echo "=== Compiling fissionTilingGeneric woven_code ==="
while IFS= read -r bench_path; do
    bench_dir=$(dirname "$bench_path")
    bench=$(basename "$bench_dir")
    woven_dir="$bench_dir/woven_code"
    preproc="$woven_dir/$bench.preproc.f90"
    exe="$woven_dir/$bench.fission_tiling.small.exe"
    echo "  $bench"
    if [[ ! -f "$preproc" ]]; then echo "  [!] no woven preproc: $bench"; continue; fi
    $FC $WFLAGS "$preproc" "$UTILITIES_DIR/fpolybench_small.o" -I "$UTILITIES_DIR" \
        -o "$exe" 2>/dev/null || echo "  [!] compile failed: $bench (woven-fission-tiling)"
done < "$UTILITIES_DIR/benchmark_list"

echo "=== Executing fissionTilingGeneric woven_code ==="
declare -A fission_tiling_correct

while IFS= read -r bench_path; do
    bench_dir=$(dirname "$bench_path")
    bench=$(basename "$bench_dir")
    woven_dir="$bench_dir/woven_code"
    exe="$woven_dir/$bench.fission_tiling.small.exe"
    dump="$woven_dir/$bench.fission_tiling.dump.txt"
    orig_dump="$bench_dir/$bench.orig.dump.txt"
    if echo "$BLACKLIST" | grep -qw "$bench"; then
        fission_tiling_correct[$bench]="skipped"
        continue
    fi
    echo "  $bench"
    if [[ ! -f "$exe" ]]; then fission_tiling_correct[$bench]="no-exe"; continue; fi
    "./$exe" > "$dump" 2>&1 || true
    if [[ ! -f "$orig_dump" ]]; then
        fission_tiling_correct[$bench]="no-ref"
    elif diff -q "$orig_dump" "$dump" > /dev/null 2>&1; then
        fission_tiling_correct[$bench]="MATCH"
    else
        fission_tiling_correct[$bench]="MISMATCH"
    fi
done < "$UTILITIES_DIR/benchmark_list"

# ─────────────────────────────────────────────────────────────────────────────
# Results table (write directly to file and stdout; no subshell pipeline)
# ─────────────────────────────────────────────────────────────────────────────
RESULTS_FILE="$EXP_DIR/results-fission-tiling.txt"
: > "$RESULTS_FILE"

emit() { echo "$@" | tee -a "$RESULTS_FILE"; }
emitf() { printf "$@" | tee -a "$RESULTS_FILE"; }

emit "=== Experiment: fission → tiling pipeline vs tiling alone ==="
emit "Dataset: SMALL_DATASET (with POLYBENCH_DUMP_ARRAYS for correctness)"
emit "Compiler: flang-22 -O3 -fopenmp"
emit ""
emitf "%-18s | %-12s | %-10s | %-16s | %-10s\n" \
    "Benchmark" "Tiling" "Correct" "Fission+Tiling" "Correct"
emit "-------------------------------------------------------------------------------"

a_tiled=0; a_skipped=0; a_match=0; a_mismatch=0
b_tiled=0; b_skipped=0; b_match=0; b_mismatch=0; b_new=0

while IFS= read -r bench_path; do
    bench=$(basename "$(dirname "$bench_path")")
    ts="${tiling_status[$bench]:-?}"
    tc="${tiling_correct[$bench]:--}"
    fs="${fission_tiling_status[$bench]:-?}"
    fc="${fission_tiling_correct[$bench]:--}"

    # Tiling counts
    if [[ "$ts" == "TILED" ]]; then a_tiled=$((a_tiled+1)); else a_skipped=$((a_skipped+1)); fi
    if [[ "$tc" == "MATCH" ]]; then a_match=$((a_match+1)); fi
    if [[ "$tc" == "MISMATCH" ]]; then a_mismatch=$((a_mismatch+1)); fi

    # Fission+tiling counts
    if [[ "$fs" == "TILED" || "$fs" == "FISSIONED+TILED" ]]; then
        b_tiled=$((b_tiled+1))
        if [[ "$ts" == "SKIPPED" ]]; then b_new=$((b_new+1)); fi
    else
        b_skipped=$((b_skipped+1))
    fi
    if [[ "$fc" == "MATCH" ]]; then b_match=$((b_match+1)); fi
    if [[ "$fc" == "MISMATCH" ]]; then b_mismatch=$((b_mismatch+1)); fi

    # Mark newly tiled benchmarks
    new_marker=""
    if [[ ("$fs" == "TILED" || "$fs" == "FISSIONED+TILED") && "$ts" == "SKIPPED" ]]; then
        new_marker=" <-- NEW"
    fi

    emitf "%-18s | %-12s | %-10s | %-16s | %-10s\n" \
        "$bench" "$ts" "$tc" "$fs" "$fc$new_marker"

done < "$UTILITIES_DIR/benchmark_list"

emit "-------------------------------------------------------------------------------"
emit ""
emit "TILING ALONE:      $a_tiled/30 tiled, $a_skipped/30 skipped, $a_match correct, $a_mismatch incorrect"
emit "FISSION+TILING:    $b_tiled/30 tiled, $b_skipped/30 skipped, $b_match correct, $b_mismatch incorrect"
emit ""
emit "Improvement:       +$b_new benchmarks newly tiled by fission → tiling pipeline"

echo ""
echo "Results saved to: $RESULTS_FILE"
