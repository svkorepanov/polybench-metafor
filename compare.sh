#!/bin/bash

# Summary counters
matches=0
mismatches=0
missing=0

echo "Output Comparison: Original vs. Woven (Metafor)"
echo "------------------------------------------------"

# Fix: Use process substitution to keep variables in the current shell
while read -r woven_dir; do
    # Get the parent directory (e.g., .../3mm)
    parent_dir=$(dirname "$woven_dir")
    
    # Get the benchmark name (e.g., 3mm)
    bench_name=$(basename "$parent_dir")
    
    # Define the two files to compare
    orig_file="$parent_dir/$bench_name.output.txt"
    woven_file="$woven_dir/$bench_name.output.txt"
    
    echo -n "Benchmark: $bench_name ... "
    
    # 1. Check if both files exist
    if [[ ! -f "$orig_file" || ! -f "$woven_file" ]]; then
        echo "SKIPPED (Missing output files)"
        ((missing++))
        continue
    fi
    
    # 2. Compare the files
    if diff -q "$orig_file" "$woven_file" > /dev/null; then
        echo "MATCH"
        ((matches++))
    else
        echo "MISMATCH"
        ((mismatches++))
        # Optional: diff "$orig_file" "$woven_file" | head -n 5
    fi
done < <(find . -type d -name "woven_code")

echo "------------------------------------------------"
echo "Results: $matches Matches, $mismatches Mismatches, $missing Missing."