#!/bin/bash
# omp-insert.sh — Insert OpenMP loop-transformation pragmas into all benchmarks
#
# Produces two output files alongside each .preproc.f90:
#   ${name}.omp-tile.preproc.f90   — !$omp tile sizes(32,32) before first do in scop
#   ${name}.omp-unroll.preproc.f90 — !$omp unroll factor(4)  before first do in scop
#
# No legality check is performed — pragmas are inserted unconditionally.
# Compile tile variant with:  flang-22 -fopenmp -fopenmp-version=51
#
# WARNING: flang-22 does not support !$omp unroll as of 2026-06.

ok_tile=0; ok_unroll=0; total=0

echo "OMP pragma insertion"
echo "Pragma (tile)  : !$omp tile sizes(32,32)"
echo "Pragma (unroll): !$omp unroll factor(4)"
echo "Output         : alongside each .preproc.f90 (not in woven_code/)"
echo "------------------------------------------------"

while IFS= read -r bench_file; do
    abs_bench="$(realpath "$bench_file")"
    bench_dir="$(dirname "$abs_bench")"
    name="$(basename "$abs_bench" .preproc.f90)"

    tile_file="$bench_dir/${name}.omp-tile.preproc.f90"
    unroll_file="$bench_dir/${name}.omp-unroll.preproc.f90"

    # Insert pragma before the FIRST `do` after !DIR$ scop, skipping any
    # intervening lines (blank, comment, or executable).
    # Group 1: scop line + newline
    # Group 2: zero or more lines that do NOT start the next `do` (negative lookahead)
    # Group 3: indentation of the `do` line
    # Group 4: `do` keyword + following char
    # \$ in replacement = literal $ (not a Perl variable sigil).
    perl -0777 -pe \
        's/(!DIR\$\s*scop[^\n]*\n)((?:(?![ \t]*do[ \t]).*\n)*)([ \t]*)(do[ \t])/\1\2\3!\$omp tile sizes(32,32)\n\3\4/i' \
        "$abs_bench" > "$tile_file"

    perl -0777 -pe \
        's/(!DIR\$\s*scop[^\n]*\n)((?:(?![ \t]*do[ \t]).*\n)*)([ \t]*)(do[ \t])/\1\2\3!\$omp unroll factor(4)\n\3\4/i' \
        "$abs_bench" > "$unroll_file"

    tile_ok=false; unroll_ok=false
    grep -q '!\$omp tile'   "$tile_file"   && tile_ok=true   && ((ok_tile++))
    grep -q '!\$omp unroll' "$unroll_file" && unroll_ok=true && ((ok_unroll++))

    tile_tag="$( $tile_ok   && echo "TILE" || echo "SKIP")"
    unroll_tag="$($unroll_ok && echo "UNROLL" || echo "SKIP")"
    printf "  [%-6s / %-6s]  %s\n" "$tile_tag" "$unroll_tag" "$name"

    ((total++))

done < <(find . -path "*/woven_code" -prune \
              -o -name "*.omp-tile.preproc.f90"   -prune \
              -o -name "*.omp-unroll.preproc.f90" -prune \
              -o -type f -name "*.preproc.f90" -print)

echo "------------------------------------------------"
echo "Done. tile: $ok_tile/$total inserted | unroll: $ok_unroll/$total inserted."
