#!/bin/bash

# Summary counters
matches=0
mismatches=0
missing=0
parallel_count=0

echo "Output Comparison: Original vs. Woven (Metafor)"
echo "--------------------------------------------------------------------------------"
printf "%-15s | %-12s | %-10s | %-10s\n" "Benchmark" "Status" "Parallel?" "Result"
echo "--------------------------------------------------------------------------------"

# Fix: Use process substitution to keep variables in the current shell
while read -r woven_dir; do
    # Get the parent directory (e.g., .../3mm)
    parent_dir=$(dirname "$woven_dir")
    
    # Get the benchmark name (e.g., 3mm)
    bench_name=$(basename "$parent_dir")
    
    # Define the files to check
    orig_file="$parent_dir/$bench_name.output.txt"
    woven_file="$woven_dir/$bench_name.output.txt"
    
    # Check for parallelization in ANY source file within the woven directory
    # We search for !$OMP (case-insensitive)
    if grep -riq "!\$OMP" "$woven_dir"; then
        omp_status="YES"
        ((parallel_count++))
    else
        omp_status="NO"
    fi
    
    # 1. Check if both files exist
    if [[ ! -f "$orig_file" || ! -f "$woven_file" ]]; then
        printf "%-15s | %-12s | %-10s | %-10s\n" "$bench_name" "SKIPPED" "$omp_status" "N/A"
        ((missing++))
        continue
    fi
    
    # 2. Compare the files
    if diff -q "$orig_file" "$woven_file" > /dev/null; then
        res_msg="MATCH"
        ((matches++))
    else
        res_msg="MISMATCH"
        ((mismatches++))
    fi

    printf "%-15s | %-12s | %-10s | %-10s\n" "$bench_name" "OK" "$omp_status" "$res_msg"

done < <(find . -type d -name "woven_code")

echo "--------------------------------------------------------------------------------"
echo "Final Results: $matches Matches, $mismatches Mismatches, $missing Missing."
echo "Total Parallelized: $parallel_count"