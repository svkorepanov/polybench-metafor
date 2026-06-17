#!/bin/bash
# omp-insert.sh — Insert OpenMP loop-transformation pragmas into all benchmarks
#
# Usage: ./omp-insert.sh [tile|unroll]
#
# For each .preproc.f90 found in the benchmark tree (excluding existing woven_code/
# directories), copies it to woven_code/${name}.preproc.f90 and inserts:
#   tile mode:   !$omp tile sizes(32,32)  before the first `do` in each !DIR$ scop region
#   unroll mode: !$omp unroll factor(4)   before the first innermost `do` in each scop
#
# No legality check is performed — the pragma is inserted unconditionally.
# Compile with:  flang-22 -fopenmp -fopenmp-version=51
#
# WARNING: flang-22 requires -fopenmp-version=51 for !$omp tile.
#          !$omp unroll is not supported in flang-22 as of 2026-06.

MODE="${1:-tile}"
if [[ "$MODE" != "tile" && "$MODE" != "unroll" ]]; then
    echo "Usage: $0 [tile|unroll]"
    exit 1
fi

if [[ "$MODE" == "tile" ]]; then
    PRAGMA="!\\$omp tile sizes(32,32)"
else
    PRAGMA="!\\$omp unroll factor(4)"
fi

echo "OMP pragma mode: $MODE"
echo "Pragma: $PRAGMA"
echo "------------------------------------------------"

ok=0; total=0

while IFS= read -r bench_file; do
    abs_bench="$(realpath "$bench_file")"
    bench_dir="$(dirname "$abs_bench")"
    name="$(basename "$abs_bench" .preproc.f90)"
    woven_dir="$bench_dir/woven_code"
    woven_file="$woven_dir/${name}.preproc.f90"

    mkdir -p "$woven_dir"

    if [[ "$MODE" == "tile" ]]; then
        # Insert !$omp tile sizes(32,32) immediately before the first `do` line
        # that follows a !DIR$ scop marker.
        # Capture the indentation of the `do` line and reuse it for the pragma.
        # Note: \$ in the Perl replacement is a literal $, not a variable sigil.
        perl -0777 -pe \
            's/(!DIR\$\s*scop[^\n]*\n)([ \t]*)(do[ \t])/\1\2!\$omp tile sizes(32,32)\n\2\3/i' \
            "$abs_bench" > "$woven_file"
    else
        # Insert !$omp unroll factor(4) before the first `do` in each scop.
        perl -0777 -pe \
            's/(!DIR\$\s*scop[^\n]*\n)([ \t]*)(do[ \t])/\1\2!\$omp unroll factor(4)\n\2\3/i' \
            "$abs_bench" > "$woven_file"
    fi

    # Check the pragma was actually inserted
    if grep -q '!\$omp' "$woven_file"; then
        echo "YES" > "$woven_dir/.transform-status"
        echo "  [INSERTED] $name"
        ((ok++))
    else
        echo "NO" > "$woven_dir/.transform-status"
        echo "  [SKIP]     $name — scop+do pattern not found"
    fi
    ((total++))

done < <(find . -path "*/woven_code" -prune -o -type f -name "*.preproc.f90" -print)

echo "------------------------------------------------"
echo "Done. OMP pragma inserted in $ok/$total benchmarks."
