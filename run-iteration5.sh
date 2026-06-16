#!/bin/bash
# run-iteration5.sh — Iteration-5: setup correctness check (SMALL_DATASET + DUMP_ARRAYS)
#
# Purpose: verify that all 5 loop transforms produce 30/30 MATCH on a fresh
# machine. Runs under POLYBENCH_DUMP_ARRAYS so compare.sh diffs actual array
# values, not just empty timing output.
#
# Results go to: experiments/issues/iteration-5/

POLYBENCH_ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$POLYBENCH_ROOT"

ITER_DIR="$POLYBENCH_ROOT/experiments/issues/iteration-5"
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
check "node 22"                   bash -c 'node --version | grep -q "^v22\."'
check "fortran-transpiler built"  test -f "$TRANSPILER_JS/code/index.js"
check "java-binaries present"     test -f "$TRANSPILER_JS/java-binaries/bin/FortranWeaver"

if [ "$ERRORS" -gt 0 ]; then
    log ""
    log "ABORT: $ERRORS check(s) failed. Fix the issues above before running."
    exit 1
fi
log "All setup checks passed."
log ""

# ── 2. Clean stale woven_code directories ────────────────────────────────────
log "Removing stale woven_code/ directories..."
find . -type d -name "woven_code" -exec rm -rf {} + 2>/dev/null || true
log "Done."
log ""

# ── 2. Patch scripts for SMALL_DATASET + POLYBENCH_DUMP_ARRAYS ───────────────
log "Patching preproc.sh + compile.sh for SMALL_DATASET / POLYBENCH_DUMP_ARRAYS..."

cp "$POLYBENCH_ROOT/preproc.sh" "$POLYBENCH_ROOT/preproc.sh.bak"
cp "$POLYBENCH_ROOT/compile.sh" "$POLYBENCH_ROOT/compile.sh.bak"

# Restore on exit regardless of success or failure
trap 'mv "$POLYBENCH_ROOT/preproc.sh.bak" "$POLYBENCH_ROOT/preproc.sh"
      mv "$POLYBENCH_ROOT/compile.sh.bak"  "$POLYBENCH_ROOT/compile.sh"
      log "Restored preproc.sh and compile.sh."' EXIT

sed -i \
    -e 's/-DLARGE_DATASET/-DSMALL_DATASET/g' \
    -e 's/-DPOLYBENCH_TIME/-DPOLYBENCH_DUMP_ARRAYS/g' \
    "$POLYBENCH_ROOT/preproc.sh" "$POLYBENCH_ROOT/compile.sh"

log "Done. Current PARGS:"
grep 'PARGS=' "$POLYBENCH_ROOT/preproc.sh" | head -1 | tee -a "$LOG"
grep 'PARGS=' "$POLYBENCH_ROOT/compile.sh" | head -1 | tee -a "$LOG"
log ""

# ── 3. Preprocess and baseline ────────────────────────────────────────────────
log "=== Preprocessing (SMALL_DATASET) ==="
"$POLYBENCH_ROOT/preproc.sh" 2>&1 | tee -a "$LOG"

log ""
log "=== Compiling originals ==="
"$POLYBENCH_ROOT/compile.sh" 2>&1 | tee -a "$LOG"

log ""
log "=== Executing originals ==="
"$POLYBENCH_ROOT/execute.sh" 2>&1 | tee -a "$LOG"

# ── 4. Run all 5 transforms ───────────────────────────────────────────────────
TRANSFORMS="tilingGeneric unrollGeneric fusionGeneric fissionGeneric interchangeGeneric"

for TRANSFORM in $TRANSFORMS; do
    log ""
    log "============================================================"
    log "Transform: $TRANSFORM  |  started: $(date)"
    log "============================================================"

    "$POLYBENCH_ROOT/weave-transpiler.sh" "$TRANSFORM" 2>&1 | tee -a "$LOG"

    log "--- compile ---"
    "$POLYBENCH_ROOT/compile.sh" 2>&1 | tee -a "$LOG"

    log "--- execute ---"
    "$POLYBENCH_ROOT/execute.sh" 2>&1 | tee -a "$LOG"

    log "--- compare ---"
    RESULT_FILE="$ITER_DIR/${TRANSFORM}-results.txt"
    "$POLYBENCH_ROOT/compare.sh" 2>&1 | tee "$RESULT_FILE"

    echo ""               >> "$SUMMARY"
    echo "### $TRANSFORM" >> "$SUMMARY"
    cat "$RESULT_FILE"    >> "$SUMMARY"

    log "Finished $TRANSFORM: $(date)"
done

# ── 5. Final summary ──────────────────────────────────────────────────────────
log ""
log "=== Summary ==="
for TRANSFORM in $TRANSFORMS; do
    RESULT_FILE="$ITER_DIR/${TRANSFORM}-results.txt"
    LINE=$(grep "^Final Results:" "$RESULT_FILE" 2>/dev/null || echo "(no results)")
    log "  $TRANSFORM: $LINE"
done
log ""
log "Combined results : $SUMMARY"
log "Full log         : $LOG"
log "Done: $(date)"
