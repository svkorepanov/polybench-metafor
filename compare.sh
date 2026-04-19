#!/bin/bash

# Summary counters
matches=0
mismatches=0
missing=0

echo "Output Comparison: Original vs. Woven (Metafor)"
echo "------------------------------------------------"

# Find all woven_code directories
find . -type d -name "woven_code" | while read -r woven_dir; do
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
    # Note: If the files ONLY contain the execution time, they will always mismatch.
    # To ignore the timing line (if it starts with a number or 'time:'), 
    # you can use 'diff -I' or 'grep -v'
    if diff -q "$orig_file" "$woven_file" > /dev/null; then
        echo "MATCH"
        ((matches++))
    else
        echo "MISMATCH"
        ((mismatches++))
        # Optional: Uncomment the line below to see exactly what changed:
        # diff "$orig_file" "$woven_file" | head -n 5
    fi
done

echo "------------------------------------------------"
echo "Results: $matches Matches, $mismatches Mismatches, $missing Missing."