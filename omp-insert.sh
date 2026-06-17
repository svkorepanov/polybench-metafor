#!/bin/bash
# omp-insert.sh — Insert OpenMP loop-transformation pragmas into all benchmarks
#
# Produces two output files alongside each .preproc.f90:
#   ${name}.omp-tile.preproc.f90   — !$omp tile sizes(32,32) before every outermost do in scop
#   ${name}.omp-unroll.preproc.f90 — !$omp unroll factor(4)  before every outermost do in scop
#
# "Outermost" means depth=0 relative to the !DIR$ scop / !DIR$ end scop region.
# No legality check is performed — pragmas are inserted unconditionally.
# Compile tile variant with:  flang-22 -fopenmp -fopenmp-version=51
#
# WARNING: flang-22 does not support !$omp unroll as of 2026-06.

ok_tile=0; ok_unroll=0; total=0

echo "OMP pragma insertion (all outermost do-loops in scop)"
echo "Pragma (tile)  : !$omp tile sizes(32,32)"
echo "Pragma (unroll): !$omp unroll factor(4)"
echo "Output         : alongside each .preproc.f90 (not in woven_code/)"
echo "------------------------------------------------"

# Perl script: insert $pragma before every outermost do in the scop region.
# Usage: perl insert_omp.pl <pragma> < input > output
PERL_SCRIPT='
use strict;
my $pragma = shift @ARGV;
local $/;
my $text = <>;
my @lines = split /\n/, $text, -1;
my @out;
my $in_scop = 0;
my $depth   = 0;
for my $line (@lines) {
    my $s = lc($line); $s =~ s/^\s+|\s+$//g;
    # Enter scop
    if ($s =~ /^!dir\$\s*scop\b/ && $s !~ /end/) { $in_scop = 1; $depth = 0; }
    # Insert pragma before every outermost do in scop
    if ($in_scop && $depth == 0 && $s =~ /^do\s/) {
        (my $indent = $line) =~ s/^(\s*).*/$1/;
        push @out, $indent . $pragma;
    }
    push @out, $line;
    # Track depth
    if ($in_scop) {
        $depth++ if $s =~ /^do\s/;
        $depth-- if $s =~ /^end\s*do\b/ || $s =~ /^enddo\b/;
    }
    # Exit scop
    if ($s =~ /^!dir\$\s*(end\s*scop|endscop)/) { $in_scop = 0; }
}
print join("\n", @out);
'

while IFS= read -r bench_file; do
    abs_bench="$(realpath "$bench_file")"
    bench_dir="$(dirname "$abs_bench")"
    name="$(basename "$abs_bench" .preproc.f90)"

    tile_file="$bench_dir/${name}.omp-tile.preproc.f90"
    unroll_file="$bench_dir/${name}.omp-unroll.preproc.f90"

    perl -e "$PERL_SCRIPT" -- '!$omp tile sizes(32,32)'   < "$abs_bench" > "$tile_file"
    perl -e "$PERL_SCRIPT" -- '!$omp unroll factor(4)'    < "$abs_bench" > "$unroll_file"

    tile_count=$(grep -c '!\$omp tile'   "$tile_file"   2>/dev/null || echo 0)
    unroll_count=$(grep -c '!\$omp unroll' "$unroll_file" 2>/dev/null || echo 0)

    [ "$tile_count"   -gt 0 ] && ((ok_tile++))
    [ "$unroll_count" -gt 0 ] && ((ok_unroll++))

    printf "  [tile:%-2s / unroll:%-2s]  %s\n" "$tile_count" "$unroll_count" "$name"
    ((total++))

done < <(find . -path "*/woven_code" -prune \
              -o -name "*.omp-tile.preproc.f90"   -prune \
              -o -name "*.omp-unroll.preproc.f90" -prune \
              -o -type f -name "*.preproc.f90" -print)

echo "------------------------------------------------"
echo "Done. tile: $ok_tile/$total inserted | unroll: $ok_unroll/$total inserted."
