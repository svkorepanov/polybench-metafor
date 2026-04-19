#!/bin/bash

# 1. Load NVM into this script session
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

# 2. Now you can use it
nvm use 22 || { echo "Failed to switch to Node 22"; exit 1; }

# --- Configuration ---
METAFOR_ROOT="$HOME/metafor-omp"
LARA_SCRIPT="scripts/analyse.js"
POLYBENCH_ROOT=$(pwd)

# Verify the Metafor directory exists
if [ ! -d "$METAFOR_ROOT" ]; then
    echo "Error: Metafor directory not found at $METAFOR_ROOT"
    exit 1
fi

echo "Starting Metafor Transpilation (Source-to-Source)..."
echo "Using script: $LARA_SCRIPT"
echo "------------------------------------------------"

# 1. Find all preprocessed Fortran files
find . -type f -name "*.preproc.f90" | while read -r bench_file; do
    
    # Get absolute paths (required because we change directories)
    abs_bench_path=$(realpath "$bench_file")
    bench_dir=$(dirname "$abs_bench_path")
    file_name=$(basename "$abs_bench_path")

    echo "Processing: $bench_file"

    # 2. Switch to metafor-omp directory to run the tool
    cd "$METAFOR_ROOT" || exit
    
    # Run metafor classic
    # -p: workspace (where the source is)
    # -o: output (same as source)
    npx metafor classic "$LARA_SCRIPT" \
        -p "$abs_bench_path" \
        -o "$bench_dir"

    # 3. Return to the original directory for the next iteration
    cd "$POLYBENCH_ROOT" || exit
    
    echo "  [✓] Transpilation step finished for $file_name"
    echo "------------------------------------------------"
done

echo "Suite processing complete."