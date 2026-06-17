#!/bin/bash
# run-iteration7b.sh — OMP tile Phase 2, starting from committed *.omp-tile.preproc.f90 files
#
# Skips preprocessing and pragma insertion entirely — uses the committed
# *.omp-tile.preproc.f90 files (SMALL_DATASET, all outermost scop loops annotated).
#
# Copies each *.omp-tile.preproc.f90 into woven_code/ so compare.sh can find it,
# then compiles both originals and woven versions, executes, and compares.
#
# Dataset: SMALL_DATASET + POLYBENCH_DUMP_ARRAYS (baked into the tile files already).
# Compile: flang-22 -fopenmp -fopenmp-version=51 (required for !$omp tile).
#
# Run: nohup ./run-iteration7b.sh > experiments/issues/iteration-7/nohup7b.log 2>&1 &

POLYBENCH_ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$POLYBENCH_ROOT"

ITER_DIR="$POLYBENCH_ROOT/experiments/issues/iteration-7"
RESULT_FILE="$ITER_DIR/omp-tile-v2-results.txt"
LOG="$ITER_DIR/run7b.log"
UTILITIES_DIR="$POLYBENCH_ROOT/utilities"

mkdir -p "$ITER_DIR"
> "$LOG"

log() { echo "$*" | tee -a "$LOG"; }

FC="flang-22"
CC="clang-22"
FFLAGS="-O3 -fopenmp -fopenmp-version=51 -Wno-ignored-directive -L/usr/lib/llvm-20/lib"
CFLAGS="-O3 -fopenmp -I/usr/lib/gcc/x86_64-linux-gnu/15/include"
PARGS="-DSMALL_DATASET -DPOLYBENCH_DUMP_ARRAYS"

log "=== run-iteration7b: OMP tile Phase 2 ==="
log "Source   : *.omp-tile.preproc.f90 (committed, SMALL_DATASET)"
log "Flags    : $FFLAGS $PARGS"
log "Started  : $(date)"
log ""

# ── 1. Compile fpolybench.c with POLYBENCH_DUMP_ARRAYS ────────────────────────
log "Compiling fpolybench.c..."
if ! $CC $CFLAGS $PARGS \
        -c "$UTILITIES_DIR/fpolybench.c" -I "$UTILITIES_DIR" \
        -o "$UTILITIES_DIR/fpolybench.o" 2>&1 | tee -a "$LOG"; then
    log "ABORT: fpolybench.c failed to compile."
    exit 1
fi
log "Done."
log ""

# ── 2. Clean stale woven_code dirs ────────────────────────────────────────────
log "Removing stale woven_code/ directories..."
find . -type d -name "woven_code" -exec rm -rf {} + 2>/dev/null || true
log "Done."
log ""

# ── 3. Per-benchmark: compile + execute original and omp-tile woven version ───
log "=== Compiling and executing (30 benchmarks) ==="

ok_orig=0; ok_woven=0; total=0

while IFS= read -r tile_file; do
    abs_tile="$(realpath "$tile_file")"
    bench_dir="$(dirname "$abs_tile")"
    name="$(basename "$abs_tile" .omp-tile.preproc.f90)"

    orig_f90="$bench_dir/${name}.preproc.f90"
    orig_exe="$bench_dir/${name}.exe"
    orig_out="$bench_dir/${name}.output.txt"

    woven_dir="$bench_dir/woven_code"
    woven_f90="$woven_dir/${name}.preproc.f90"
    woven_exe="$woven_dir/${name}.exe"
    woven_out="$woven_dir/${name}.output.txt"

    mkdir -p "$woven_dir"
    cp "$abs_tile" "$woven_f90"
    echo "YES" > "$woven_dir/.transform-status"

    # Compile original
    orig_ok=false
    if $FC $FFLAGS $PARGS \
            "$orig_f90" "$UTILITIES_DIR/fpolybench.o" -I "$UTILITIES_DIR" \
            -o "$orig_exe" 2>>"$LOG"; then
        orig_ok=true
        ((ok_orig++))
    else
        log "  [FAIL] $name — original compile failed"
    fi

    # Compile woven (omp-tile)
    woven_ok=false
    if $FC $FFLAGS $PARGS \
            "$woven_f90" "$UTILITIES_DIR/fpolybench.o" -I "$UTILITIES_DIR" \
            -o "$woven_exe" 2>>"$LOG"; then
        woven_ok=true
        ((ok_woven++))
    else
        log "  [FAIL] $name — omp-tile compile failed"
    fi

    # Execute
    $orig_ok  && "$orig_exe"   > "$orig_out"   2>&1
    $woven_ok && "$woven_exe"  > "$woven_out"  2>&1

    log "  [$([ "$orig_ok" = true ] && echo "OK  " || echo "FAIL")/$([ "$woven_ok" = true ] && echo "OK  " || echo "FAIL")]  $name"
    ((total++))

done < <(find . -path "*/woven_code" -prune \
              -o -name "*.omp-tile.preproc.f90" -print | sort)

log ""
log "Compiled: originals $ok_orig/$total, omp-tile $ok_woven/$total"
log ""

# ── 4. Compare ────────────────────────────────────────────────────────────────
log "=== compare.sh ==="
"$POLYBENCH_ROOT/compare.sh" 2>&1 | tee "$RESULT_FILE"

log ""
log "Results : $RESULT_FILE"
log "Log     : $LOG"
log "Done    : $(date)"
