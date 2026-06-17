#!/bin/bash
# run-iteration7.sh — Iteration-7: OpenMP pragma vs fortran-transpiler legality checks
#
# Hypothesis: OpenMP loop-transformation pragmas (!$omp tile) are applied without the
# legality checks that the fortran-transpiler's LoopTilingPass enforces. Benchmarks
# that the transpiler correctly SKIPs will either fail to compile or produce MISMATCH
# when the pragma is inserted blindly.
#
# Dataset: SMALL_DATASET + POLYBENCH_DUMP_ARRAYS (full array dump so MISMATCH is visible)
#
# Three phases:
#   Phase 1 (control):   tilingGeneric with canTile() legality check  → expect 30/30 MATCH
#   Phase 2 (treatment): !$omp tile sizes(32,32) no legality check    → expect some MISSING/MISMATCH
#   Phase 3 (negative):  !$omp unroll factor(4)  (if flang-22 supports it)
#
# Run: nohup ./run-iteration7.sh > experiments/issues/iteration-7/nohup.log 2>&1 &

POLYBENCH_ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$POLYBENCH_ROOT"

ITER_DIR="$POLYBENCH_ROOT/experiments/issues/iteration-7"
SUMMARY="$ITER_DIR/results-summary.txt"
LOG="$ITER_DIR/run.log"
TRANSPILER_JS="$POLYBENCH_ROOT/../fortran-transpiler/Fortran-JS"

mkdir -p "$ITER_DIR"
> "$SUMMARY"
> "$LOG"

log() { echo "$*" | tee -a "$LOG"; }

# ── 1. Setup check ────────────────────────────────────────────────────────────
log "=== Setup check: $(date) ==="

ERRORS=0
check() {
    local label="$1"; shift
    if "$@" &>/dev/null; then
        log "  [OK]   $label"
    else
        log "  [FAIL] $label — command: $*"
        ERRORS=$((ERRORS + 1))
    fi
}

check "flang-22 installed"        flang-22 --version
check "clang-22 installed"        clang-22 --version
check "java 21+ installed"        bash -c 'java -version 2>&1 | grep -qE "version \"(2[1-9]|[3-9][0-9])\."'
check "node 22 installed"         bash -c 'node --version | grep -q "^v22\."'
check "fortran-transpiler built"  test -f "$TRANSPILER_JS/code/index.js"
check "java-binaries present"     test -f "$TRANSPILER_JS/java-binaries/bin/FortranWeaver"

if [ "$ERRORS" -gt 0 ]; then
    log "ABORT: $ERRORS check(s) failed."
    exit 1
fi
log "All setup checks passed."
log ""

# ── 2. Check !$omp tile support ───────────────────────────────────────────────
log "=== Checking flang-22 !$omp tile support ==="
cat > /tmp/omp_tile_check.f90 << 'EOF'
subroutine omp_tile_check(n, a)
  integer :: n, i, j
  double precision, dimension(n,n) :: a
  !$omp tile sizes(4,4)
  do i = 1, n
    do j = 1, n
      a(j,i) = 0.0
    end do
  end do
end subroutine
EOF

if flang-22 -O0 -fopenmp -fopenmp-version=51 -c /tmp/omp_tile_check.f90 -o /tmp/omp_tile_check.o &>/dev/null; then
    OMP_TILE_SUPPORTED=true
    log "  !$omp tile: SUPPORTED (flang-22 -fopenmp-version=51)"
else
    OMP_TILE_SUPPORTED=false
    log "  !$omp tile: UNSUPPORTED — Phase 2 will be skipped"
fi

OMP_UNROLL_SUPPORTED=false
log "  !$omp unroll: not supported by this flang-22 version — Phase 3 skipped"
log ""

# ── 3. Patch preproc.sh + compile.sh ─────────────────────────────────────────
log "Patching preproc.sh + compile.sh for SMALL_DATASET + POLYBENCH_DUMP_ARRAYS..."

cp "$POLYBENCH_ROOT/preproc.sh"  "$POLYBENCH_ROOT/preproc.sh.bak7"
cp "$POLYBENCH_ROOT/compile.sh"  "$POLYBENCH_ROOT/compile.sh.bak7"

trap 'mv "$POLYBENCH_ROOT/preproc.sh.bak7"  "$POLYBENCH_ROOT/preproc.sh"
      mv "$POLYBENCH_ROOT/compile.sh.bak7"   "$POLYBENCH_ROOT/compile.sh"
      log "Restored preproc.sh and compile.sh."' EXIT

# preproc.sh: LARGE_DATASET → SMALL_DATASET, POLYBENCH_TIME → POLYBENCH_DUMP_ARRAYS
sed -i \
    -e 's/-DLARGE_DATASET/-DSMALL_DATASET/g' \
    -e 's/-DPOLYBENCH_TIME/-DPOLYBENCH_DUMP_ARRAYS/g' \
    "$POLYBENCH_ROOT/preproc.sh"

# compile.sh: LARGE_DATASET → SMALL_DATASET, POLYBENCH_TIME → POLYBENCH_DUMP_ARRAYS
# Also add -fopenmp-version=51 so that !$omp tile is parsed when it appears
sed -i \
    -e 's/-DLARGE_DATASET/-DSMALL_DATASET/g' \
    -e 's/-DPOLYBENCH_TIME/-DPOLYBENCH_DUMP_ARRAYS/g' \
    -e 's/-fopenmp -Wno-ignored-directive/-fopenmp -fopenmp-version=51 -Wno-ignored-directive/g' \
    "$POLYBENCH_ROOT/compile.sh"

log "Done. Current PARGS:"
grep 'PARGS=' "$POLYBENCH_ROOT/preproc.sh" | head -1 | tee -a "$LOG"
grep 'PARGS=' "$POLYBENCH_ROOT/compile.sh" | head -1 | tee -a "$LOG"
log ""

# ── 4. Clean stale woven_code directories ────────────────────────────────────
log "Removing stale woven_code/ directories..."
find . -type d -name "woven_code" -exec rm -rf {} + 2>/dev/null || true
log "Done."
log ""

# ── 5. Preprocess and baseline ────────────────────────────────────────────────
log "=== Preprocessing (SMALL_DATASET + POLYBENCH_DUMP_ARRAYS) ==="
"$POLYBENCH_ROOT/preproc.sh" 2>&1 | tee -a "$LOG"

log ""
log "=== Compiling originals ==="
"$POLYBENCH_ROOT/compile.sh" 2>&1 | tee -a "$LOG"

log ""
log "=== Executing originals ==="
"$POLYBENCH_ROOT/execute.sh" 2>&1 | tee -a "$LOG"

# ── 6. Phase 1: tilingGeneric (control — with legality check) ─────────────────
log ""
log "============================================================"
log "Phase 1: tilingGeneric (control — canTile() legality check active)"
log "Started: $(date)"
log "============================================================"

find . -type d -name "woven_code" -exec rm -rf {} + 2>/dev/null || true

"$POLYBENCH_ROOT/weave-transpiler.sh" tilingGeneric 2>&1 | tee -a "$LOG"

log "--- compile ---"
"$POLYBENCH_ROOT/compile.sh" 2>&1 | tee -a "$LOG"

log "--- execute ---"
"$POLYBENCH_ROOT/execute.sh" 2>&1 | tee -a "$LOG"

log "--- compare ---"
RESULT_P1="$ITER_DIR/tiling-checked-results.txt"
"$POLYBENCH_ROOT/compare.sh" 2>&1 | tee "$RESULT_P1"

echo ""                     >> "$SUMMARY"
echo "### Phase 1: tilingGeneric (control — canTile() legality check)" >> "$SUMMARY"
cat "$RESULT_P1"            >> "$SUMMARY"

log "Phase 1 finished: $(date)"

# ── 7. Phase 2: !$omp tile (treatment — no legality check) ───────────────────
if [ "$OMP_TILE_SUPPORTED" = true ]; then
    log ""
    log "============================================================"
    log "Phase 2: !$omp tile sizes(32,32) — no legality check"
    log "Started: $(date)"
    log "============================================================"

    find . -type d -name "woven_code" -exec rm -rf {} + 2>/dev/null || true

    "$POLYBENCH_ROOT/omp-insert.sh" tile 2>&1 | tee -a "$LOG"

    log "--- compile (with -fopenmp-version=51) ---"
    "$POLYBENCH_ROOT/compile.sh" 2>&1 | tee -a "$LOG"

    log "--- execute ---"
    "$POLYBENCH_ROOT/execute.sh" 2>&1 | tee -a "$LOG"

    log "--- compare ---"
    RESULT_P2="$ITER_DIR/omp-tile-results.txt"
    "$POLYBENCH_ROOT/compare.sh" 2>&1 | tee "$RESULT_P2"

    echo ""                       >> "$SUMMARY"
    echo "### Phase 2: !$omp tile (treatment — no legality check)" >> "$SUMMARY"
    cat "$RESULT_P2"              >> "$SUMMARY"

    log "Phase 2 finished: $(date)"
else
    log "Phase 2 SKIPPED — !$omp tile not supported by flang-22"
    echo ""                                                              >> "$SUMMARY"
    echo "### Phase 2: SKIPPED — !$omp tile not supported by flang-22" >> "$SUMMARY"
fi

# ── 8. Final summary ──────────────────────────────────────────────────────────
log ""
log "=== Summary ==="
for label in "tiling-checked" "omp-tile"; do
    RFILE="$ITER_DIR/${label}-results.txt"
    if [ -f "$RFILE" ]; then
        LINE=$(grep "^Final Results:" "$RFILE" 2>/dev/null || echo "(no results)")
        log "  $label: $LINE"
    fi
done
log ""

if [ -f "$RESULT_P1" ]; then
    log "=== Hypothesis verification ==="
    log "Benchmarks SKIPPED by tilingGeneric (Transform? = NO in Phase 1):"
    grep "| NO " "$RESULT_P1" | awk '{print "  " $1}' | tee -a "$LOG"
    log ""
    if [ -f "${RESULT_P2:-}" ]; then
        log "Same benchmarks in omp-tile Phase 2 (MISSING = compile error, MISMATCH = wrong output):"
        while IFS= read -r bench; do
            # $bench may have trailing spaces from awk; strip them
            bench="${bench// /}"
            grep "^$bench " "$RESULT_P2" | awk '{printf "  %-15s | Result: %s\n", $1, $7}' | tee -a "$LOG"
        done < <(grep "| NO " "$RESULT_P1" | awk '{print $1}')
    fi
fi

log ""
log "Full log    : $LOG"
log "Summary     : $SUMMARY"
log "Done: $(date)"
