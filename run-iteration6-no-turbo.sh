#!/bin/bash
# run-iteration6-no-turbo.sh — Iteration-6 re-run with turbo disabled + no blacklist
#
# Identical to run-iteration6.sh except:
#   1. Disables Intel turbo boost at startup (no_turbo=1)
#   2. Temporarily replaces execute.sh with a blacklist-free version so
#      fdtd-apml is executed even at LARGE_DATASET
#
# Results go to: experiments/issues/iteration-6-no-turbo/
#
# Run under nohup for overnight use:
#   nohup ./run-iteration6-no-turbo.sh > experiments/issues/iteration-6-no-turbo/nohup.log 2>&1 &

# ── 0. Disable turbo boost ────────────────────────────────────────────────────
echo 1 | sudo tee /sys/devices/system/cpu/intel_pstate/no_turbo

POLYBENCH_ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$POLYBENCH_ROOT"

ITER_DIR="$POLYBENCH_ROOT/experiments/issues/iteration-6-no-turbo"
SUMMARY="$ITER_DIR/results-summary.txt"
LOG="$ITER_DIR/run.log"
TRANSPILER_JS="$POLYBENCH_ROOT/../fortran-transpiler/Fortran-JS"

mkdir -p "$ITER_DIR"
> "$SUMMARY"
> "$LOG"

log() { echo "$*" | tee -a "$LOG"; }

# ── 1. Patch execute.sh: remove blacklist for the duration of this run ────────
cp execute.sh execute.sh.bak
trap 'mv execute.sh.bak execute.sh' EXIT INT TERM

cat > execute.sh << 'EXECUTE_EOF'
#!/bin/bash

echo "Running Suite..."
echo "------------------------------------------------"

count=0
while read -r exe_path; do
    dir_name=$(dirname "$exe_path")
    base_name=$(basename "$exe_path" .exe)
    output_file="$dir_name/$base_name.output.txt"

    echo "Processing: $base_name"

    "$exe_path" > "$output_file" 2>&1

    if [ $? -eq 0 ]; then
        ((count++))
    else
        echo "   [!] Error in $base_name"
    fi
done < <(find . -type f -name "*.exe")

echo "------------------------------------------------"
echo "Done. Captured $count benchmark results."
EXECUTE_EOF
chmod +x execute.sh

# ── 2. Setup check ────────────────────────────────────────────────────────────
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
    log ""
    log "ABORT: $ERRORS check(s) failed. Fix the issues above before running."
    exit 1
fi
log "All setup checks passed."
log ""

# ── 3. Verify dataset flags ───────────────────────────────────────────────────
log "Verifying LARGE_DATASET + POLYBENCH_TIME flags..."
grep 'PARGS=' "$POLYBENCH_ROOT/preproc.sh" | head -1 | tee -a "$LOG"
grep 'PARGS=' "$POLYBENCH_ROOT/compile.sh" | head -1 | tee -a "$LOG"

if ! grep -q 'LARGE_DATASET' "$POLYBENCH_ROOT/preproc.sh"; then
    log "ERROR: preproc.sh does not contain LARGE_DATASET. Check PARGS."
    exit 1
fi
if ! grep -q 'POLYBENCH_TIME' "$POLYBENCH_ROOT/compile.sh"; then
    log "ERROR: compile.sh does not contain POLYBENCH_TIME. Check PARGS."
    exit 1
fi
log "Flags OK."
log ""

# ── 4. Clean stale woven_code directories ────────────────────────────────────
log "Removing stale woven_code/ directories..."
find . -type d -name "woven_code" -exec rm -rf {} + 2>/dev/null || true
log "Done."
log ""

# ── 5. Preprocess and baseline ────────────────────────────────────────────────
log "=== Preprocessing (LARGE_DATASET) ==="
"$POLYBENCH_ROOT/preproc.sh" 2>&1 | tee -a "$LOG"

log ""
log "=== Compiling originals ==="
"$POLYBENCH_ROOT/compile.sh" 2>&1 | tee -a "$LOG"

log ""
log "=== Executing originals ==="
"$POLYBENCH_ROOT/execute.sh" 2>&1 | tee -a "$LOG"

# ── 6. Run all 5 transforms ───────────────────────────────────────────────────
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

# ── 7. Final summary ──────────────────────────────────────────────────────────
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
