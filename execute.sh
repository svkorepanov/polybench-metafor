#!/bin/bash

echo "Running Suite..."
echo "------------------------------------------------"

# Space-separated list of benchmark names to skip entirely.
# Add entries here when a benchmark exceeds available RAM at the current dataset size.
# fdtd-apml: allocates 4×513³ doubles (~4.3 GB) at LARGE_DATASET — exceeds 3.8 GB RAM.
BLACKLIST="fdtd-apml"

count=0
skipped=0
while read -r exe_path; do
    dir_name=$(dirname "$exe_path")
    base_name=$(basename "$exe_path" .exe)
    output_file="$dir_name/$base_name.output.txt"

    if echo "$BLACKLIST" | grep -qw "$base_name"; then
        echo "Skipping (blacklisted): $base_name"
        ((skipped++))
        continue
    fi

    echo "Processing: $base_name"

    "$exe_path" > "$output_file" 2>&1

    if [ $? -eq 0 ]; then
        ((count++))
    else
        echo "   [!] Error in $base_name"
    fi
done < <(find . -type f -name "*.exe")

echo "------------------------------------------------"
echo "Done. Captured $count benchmark results. Skipped (blacklisted): $skipped."