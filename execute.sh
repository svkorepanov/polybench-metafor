#!/bin/bash

echo "Running Suite..."
echo "------------------------------------------------"

count=0
# Fix: Move the find command to the bottom with process substitution
while read -r exe_path; do
    dir_name=$(dirname "$exe_path")
    base_name=$(basename "$exe_path" .exe)
    output_file="$dir_name/$base_name.output.txt"
    
    echo "Processing: $base_name"
    
    # Simple execution without the stack limit hack
    "$exe_path" > "$output_file" 2>&1
    
    if [ $? -eq 0 ]; then
        ((count++))
    else
        echo "   [!] Error in $base_name"
    fi
done < <(find . -type f -name "*.exe")

echo "------------------------------------------------"
echo "Done. Captured $count benchmark results."