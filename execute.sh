#!/bin/bash

echo "Running Small Dataset Suite..."
echo "------------------------------------------------"

count=0
find . -type f -name "*.exe" | while read -r exe_path; do
    dir_name=$(dirname "$exe_path")
    base_name=$(basename "$exe_path" .exe)
    output_file="$dir_name/$base_name.output.txt"
    
    echo "Processing: $base_name"
    
    # Simple execution without the stack limit hack
    "$exe_path" > "$output_file" 2>&1
    
    if [ $? -eq 0 ]; then
        ((count++))
    else
        echo "  [!] Error in $base_name"
    fi
done

echo "------------------------------------------------"
echo "Done. Captured $count benchmark results."