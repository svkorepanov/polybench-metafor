#!/bin/bash

# Get the absolute path of the directory where this script is located
# (Assuming you run this from the root of the project)
ROOT_DIR=$(pwd)
UTILITIES_DIR="$ROOT_DIR/utilities"
PREPROCESS_SCRIPT="$UTILITIES_DIR/create_pped_version.sh"

# Set your flags with the absolute path to utilities
PARGS="-I $UTILITIES_DIR -DSMALL_DATASET -DPOLYBENCH_DUMP_ARRAYS"

if [ ! -f "utilities/benchmark_list" ]; then
    echo "Error: Run this script from the root of the PolyBench folder."
    exit 1
fi

for i in $(cat utilities/benchmark_list); do
    echo "Processing $i..."
    # Call the preprocessor script
    bash "$PREPROCESS_SCRIPT" "$i" "$PARGS"
done