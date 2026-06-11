#!/bin/bash

echo "Running Suite..."
echo "------------------------------------------------"

# fdtd-apml OOM check: at LARGE_DATASET it allocates 4×513³ doubles (~4.3 GB),
# exceeding this machine's 3.8 GB RAM. At SMALL_DATASET it uses 64³ arrays (~2 MB)
# and runs fine. Detect the compiled size from the preprocessed source.
FDTD_DIM=$(grep -m1 "allocate(ex(" stencils/fdtd-apml/fdtd-apml.preproc.f90 2>/dev/null \
           | grep -oE "[0-9]+" | head -1)
BLACKLIST=""
[ "${FDTD_DIM:-0}" -ge 256 ] && BLACKLIST="fdtd-apml"

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