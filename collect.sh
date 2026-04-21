#!/bin/bash

# 1. Define the destination folder in the root
DEST_DIR="all_transformed_code"
mkdir -p "$DEST_DIR"

count=0

echo "Collecting transformed files into /$DEST_DIR..."
echo "------------------------------------------------"

# 2. Find only the .f90 files inside woven_code directories
while read -r src_file; do
    # src_file example: ./linear-algebra/kernels/3mm/woven_code/3mm.preproc.f90
    
    # Get the filename (e.g., 3mm.preproc.f90)
    file_name=$(basename "$src_file")
    
    # Copy to the destination
    cp "$abs_src" "$DEST_DIR/$file_name" 2>/dev/null || cp "$src_file" "$DEST_DIR/$file_name"
    
    if [ $? -eq 0 ]; then
        echo "  [+] Copied: $file_name"
        ((count++))
    else
        echo "  [!] Failed: $file_name"
    fi

done < <(find . -path "*/woven_code/*.preproc.f90")

echo "------------------------------------------------"
echo "Done! Gathered $count files into the '$DEST_DIR' directory."