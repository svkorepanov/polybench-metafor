#!/bin/bash
# Runs all 5 generic loop transforms across the full benchmark suite.
# Each transform overwrites woven_code/ — rename dirs between runs to keep results separate.
#
# Example for multi-transform comparison:
#   ./run-all-transforms.sh
# Or individually:
#   ./weave-transpiler.sh tilingGeneric
#   find . -type d -name woven_code -exec sh -c 'mv "$1" "$(dirname "$1")/woven_code_tiling"' _ {} \;
#   ./weave-transpiler.sh unrollGeneric

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TRANSFORMS=(tilingGeneric unrollGeneric fusionGeneric fissionGeneric interchangeGeneric)

for transform in "${TRANSFORMS[@]}"; do
    echo "=============================="
    echo "Running transform: $transform"
    echo "=============================="
    bash "$SCRIPT_DIR/weave-transpiler.sh" "$transform"
    echo ""
done
