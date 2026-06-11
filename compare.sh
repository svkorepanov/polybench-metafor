#!/bin/bash

# Summary counters
matches=0
mismatches=0
missing=0
parallel_count=0

echo "Output Comparison: Original vs. Woven (Metafor)"
echo "--------------------------------------------------------------------------------------------"
printf "%-15s | %-10s | %-10s | %-10s | %-10s | %-8s\n" "Benchmark" "Status" "Transform?" "Result" "Orig Time" "Speedup"
echo "--------------------------------------------------------------------------------------------"

# Function to extract the last number in a file (handles scientific notation like 1.2e-05)
get_timer() {
    grep -oE '[-+]?[0-9]*\.?[0-9]+([eE][-+]?[0-9]+)?' "$1" | tail -n 1
}

# Function to strip the last number from the file for functional comparison.
# Handles both POLYBENCH_DUMP_ARRAYS (number preceded by whitespace) and
# POLYBENCH_TIME-only mode (bare number on its own line, no leading whitespace).
strip_timer() {
    perl -0777 -pe 's/\s*[\d.eE+-]+\s*$/\n/' "$1"
}

while read -r woven_dir; do
    parent_dir=$(dirname "$woven_dir")
    bench_name=$(basename "$parent_dir")
    
    orig_file="$parent_dir/$bench_name.output.txt"
    woven_file="$woven_dir/$bench_name.output.txt"
    
    if grep -riq "!\$OMP" "$woven_dir"; then
        transform_status="OMP"
        ((parallel_count++))
    elif grep -qiE "^\s+DO [a-zA-Z][a-zA-Z0-9]* = [^,]+,[^,]+,[^,]+$" "$woven_dir"/*.f90 2>/dev/null; then
        transform_status="TILED"
    else
        transform_status="NO"
    fi

    if [[ ! -f "$orig_file" || ! -f "$woven_file" ]]; then
        printf "%-15s | %-10s | %-10s | %-10s | %-10s | %-8s\n" "$bench_name" "SKIPPED" "$transform_status" "N/A" "-" "-"
        ((missing++))
        continue
    fi
    
    # 1. Extract the last number as the timer
    t_orig=$(get_timer "$orig_file")
    t_woven=$(get_timer "$woven_file")

    # 2. Calculate Speedup
    if [[ $t_orig =~ ^[0-9.eE+-]+$ && $t_woven =~ ^[0-9.eE+-]+$ ]]; then
        speedup=$(awk "BEGIN {if ($t_woven > 0) printf \"%.2fx\", $t_orig / $t_woven; else print \"0.00x\"}")
    else
        speedup="err"
    fi
    
    # 3. Compare files (stripping the last numeric field from both)
    # This handles files whether the timer is on a new line or just space-separated
    if diff -q <(strip_timer "$orig_file") <(strip_timer "$woven_file") > /dev/null; then
        res_msg="MATCH"
        ((matches++))
    else
        res_msg="MISMATCH"
        ((mismatches++))
    fi

    printf "%-15s | %-10s | %-10s | %-10s | %-10s | %-8s\n" "$bench_name" "OK" "$transform_status" "$res_msg" "$t_orig" "$speedup"

done < <(find . -type d -name "woven_code")

echo "--------------------------------------------------------------------------------------------"
echo "Final Results: $matches Matches (ignoring timer), $mismatches Mismatches, $missing Missing."
echo "Total Parallelized/Transformed: $parallel_count"