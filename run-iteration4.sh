#!/bin/bash
# run-iteration4.sh — Iteration-4: all 5 transforms at LARGE_DATASET
# Saves results to experiments/<transform>-large-dataset/results.txt
# and a combined summary to experiments/issues/iteration-4/results-summary.txt

POLYBENCH_ROOT="$(pwd)"
LOG="experiments/issues/iteration-4/run.log"
SUMMARY="experiments/issues/iteration-4/results-summary.txt"

mkdir -p experiments/issues/iteration-4

echo "Iteration-4 LARGE_DATASET run started: $(date)" | tee "$LOG"

declare -A RESULT_DIRS=(
    [tilingGeneric]="experiments/tiling-tile32-large-dataset"
    [unrollGeneric]="experiments/unroll-factor4-large-dataset"
    [fusionGeneric]="experiments/fusion-large-dataset"
    [fissionGeneric]="experiments/fission-large-dataset"
    [interchangeGeneric]="experiments/interchange-large-dataset"
)

> "$SUMMARY"

for TRANSFORM in tilingGeneric unrollGeneric fusionGeneric fissionGeneric interchangeGeneric; do
    RESULT_DIR="${RESULT_DIRS[$TRANSFORM]}"
    echo "" | tee -a "$LOG"
    echo "==============================" | tee -a "$LOG"
    echo "Transform: $TRANSFORM" | tee -a "$LOG"
    echo "Started:   $(date)" | tee -a "$LOG"
    echo "==============================" | tee -a "$LOG"

    # 1. Weave
    echo "--- weave-transpiler.sh $TRANSFORM ---" | tee -a "$LOG"
    ./weave-transpiler.sh "$TRANSFORM" 2>&1 | tee -a "$LOG"

    # 2. Compile (originals + woven)
    echo "--- compile.sh ---" | tee -a "$LOG"
    ./compile.sh 2>&1 | tee -a "$LOG"

    # 3. Execute (originals + woven)
    echo "--- execute.sh ---" | tee -a "$LOG"
    ./execute.sh 2>&1 | tee -a "$LOG"

    # 4. Compare and save
    echo "--- compare.sh ---" | tee -a "$LOG"
    ./compare.sh 2>&1 | tee "$RESULT_DIR/results.txt"
    cat "$RESULT_DIR/results.txt" | tee -a "$LOG"

    echo "" >> "$SUMMARY"
    echo "### $TRANSFORM" >> "$SUMMARY"
    cat "$RESULT_DIR/results.txt" >> "$SUMMARY"

    echo "Finished: $(date)" | tee -a "$LOG"
done

echo "" | tee -a "$LOG"
echo "All 5 transforms complete: $(date)" | tee -a "$LOG"
echo "See $SUMMARY for combined results."
