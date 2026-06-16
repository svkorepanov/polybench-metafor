#!/bin/bash

# Load NVM if present; fall back to system node otherwise
export NVM_DIR="$HOME/.nvm"
if [ -s "$NVM_DIR/nvm.sh" ]; then
    . "$NVM_DIR/nvm.sh"
    nvm use 22 || { echo "Failed to switch to Node 22"; exit 1; }
fi

# --- Configuration ---
TRANSFORM="${1:-tilingGeneric}"
TRANSPILER_ROOT="$(cd "$(dirname "$0")/../fortran-transpiler/Fortran-JS" && pwd)"
SCRIPT="api/examples/${TRANSFORM}.js"
POLYBENCH_ROOT="$(pwd)"

# Validate setup
if [ ! -d "$TRANSPILER_ROOT" ]; then
    echo "Error: fortran-transpiler not found at $TRANSPILER_ROOT"
    exit 1
fi

if [ ! -f "$TRANSPILER_ROOT/$SCRIPT" ]; then
    echo "Error: transform script not found: $TRANSPILER_ROOT/$SCRIPT"
    echo "Available generic transforms:"
    ls "$TRANSPILER_ROOT/src-api/examples/"*Generic.ts 2>/dev/null | xargs -I{} basename {} .ts
    exit 1
fi

if [ ! -f "$TRANSPILER_ROOT/code/index.js" ]; then
    echo "Error: fortran-transpiler is not built."
    echo "Run:"
    echo "  cd $TRANSPILER_ROOT && npm install && npm run build"
    exit 1
fi

echo "Starting fortran-transpiler (transform: $TRANSFORM)"
echo "Transpiler root: $TRANSPILER_ROOT"
echo "------------------------------------------------"

ok=0; total=0
while IFS= read -r bench_file; do
    abs_bench=$(realpath "$bench_file")
    bench_dir=$(dirname "$abs_bench")
    file_name=$(basename "$abs_bench")

    echo "Processing: $bench_file"

    cd "$TRANSPILER_ROOT" || exit 1
    output=$(npx metafor classic "$SCRIPT" -p "$abs_bench" -o "$bench_dir" 2>&1)
    status=$?
    echo "$output"
    cd "$POLYBENCH_ROOT" || exit 1

    # Write a per-benchmark marker for compare.sh.
    # All generic scripts print "SKIPPED" when the legality check rejects all loops.
    # If the output contains no "SKIPPED" line the transform was applied.
    if echo "$output" | grep -qi "SKIPPED"; then
        echo "NO"  > "$bench_dir/woven_code/.transform-status"
    else
        echo "YES" > "$bench_dir/woven_code/.transform-status"
    fi

    ((total++))
    if [ $status -eq 0 ]; then
        ((ok++))
        echo "  [OK] $file_name"
    else
        echo "  [FAIL] $file_name (exit=$status)"
    fi
    echo "------------------------------------------------"
done < <(find . -path "*/woven_code" -prune -o -type f -name "*.preproc.f90" -print)

echo "Done. $ok/$total succeeded."
