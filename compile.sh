#!/bin/bash

# 1. Configuration
FC="flang-22"
CC="clang-22" # Or 'clang'
OPTIMIZATION="-O3"
UTILITIES_DIR="$(pwd)/utilities"

# --- OPENMP FLAGS ---
# Add -fopenmp to both Fortran and C flags
FFLAGS="$OPTIMIZATION -fopenmp -Wno-ignored-directive -L/usr/lib/llvm-20/lib"
CFLAGS="-O3 -fopenmp -I/usr/lib/gcc/x86_64-linux-gnu/15/include"

# IMPORTANT: These must match the flags you used during preprocessing
# Especially -DPOLYBENCH_TIME
PARGS="-DSMALL_DATASET -DPOLYBENCH_DUMP_ARRAYS"

echo "Step 1: Compiling C utilities..."
$CC -c $PARGS $CFLAGS "$UTILITIES_DIR/fpolybench.c" -I "$UTILITIES_DIR" -o "$UTILITIES_DIR/fpolybench.o"

if [ $? -ne 0 ]; then
    echo "Error: Failed to compile fpolybench.c"
    exit 1
fi

echo "Step 2: Compiling benchmarks with $FC..."
echo "------------------------------------------------"

count=0
# Loop through the preprocessed files
while read -r bench_file; do
    exe_name="${bench_file%.preproc.f90}.exe"
    echo "Building: $exe_name"
    
    $FC $FFLAGS $OPTIMIZATION "$bench_file" "$UTILITIES_DIR/fpolybench.o" -I "$UTILITIES_DIR" -o "$exe_name"
    
    if [ $? -eq 0 ]; then
        ((count++))
    else
        echo "   [!] Failed to compile $bench_file"
    fi
done < <(find . -name "*.preproc.f90")

echo "------------------------------------------------"
echo "Done! Compiled $count benchmarks."