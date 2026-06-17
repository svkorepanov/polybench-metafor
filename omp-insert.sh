#!/bin/bash
# omp-insert.sh — Insert OpenMP loop-transformation pragmas into all benchmarks
#
# Produces two output files alongside each .preproc.f90:
#   ${name}.omp-tile.preproc.f90   — !$omp tile sizes(32,32) or sizes(32) before every outermost do
#                                     sizes(32,32) when the loop has an inner do; sizes(32) for 1D loops
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

# Perl script for TILING: insert !$omp tile sizes(32,32) before outermost dos
# that have at least one inner do (2-level nests), sizes(32) for 1D loops.
# Pass 1 scans ahead from each outermost do to check for an inner do.
PERL_TILE='
use strict;
local $/;
my @lines = split /\n/, <>, -1;

# Pass 1: record whether each outermost-do line index has a direct inner do
my (%has_inner);
my ($in_scop, $depth) = (0, 0);
for my $i (0..$#lines) {
    my $s = lc($lines[$i]); $s =~ s/^\s+|\s+$//g;
    if ($s =~ /^!dir\$\s*scop\b/ && $s !~ /end/) { $in_scop = 1; $depth = 0; }
    if ($in_scop && $depth == 0 && $s =~ /^do\b/) {
        # Determine if the outer loop body is a SINGLE inner do...end do block
        # (perfect 2-level nest) with invariant inner bounds (no triangular deps).
        # has_inner = true → sizes(32,32); false → sizes(32) (1D strip-mine).
        #
        # Extract outer loop variable to detect triangular inner bounds.
        my $outer_var = ($s =~ /^do\s+([a-z_][a-z0-9_]*)\s*=/) ? $1 : "";
        my $d = 1; my $constructs = 0; my $first_is_do = 0; my $triangular = 0;
        for my $j ($i+1..$#lines) {
            my $t = lc($lines[$j]); $t =~ s/^\s+|\s+$//g;
            next if $t eq "" || $t =~ /^!/;   # skip blanks and comments
            if ($d == 1) {
                # Check for outer end do BEFORE incrementing constructs.
                if ($t =~ /^end\s*do\b/ || $t =~ /^enddo\b/) { last; }
                $constructs++;
                if ($t =~ /^do\b/) {
                    $first_is_do = ($constructs == 1);
                    # Triangular check: inner do bounds must not reference outer var.
                    if ($constructs == 1 && $outer_var ne "") {
                        (my $range = $t) =~ s/^do\s+\w+\s*=//;
                        $triangular = 1 if $range =~ /\b\Q$outer_var\E\b/;
                    }
                    $d++;
                }
                # else: scalar stmt — constructs++ already counted it
            } elsif ($t =~ /^do\b/) { $d++; }
            elsif ($t =~ /^end\s*do\b/ || $t =~ /^enddo\b/) { $d--; }
        }
        $has_inner{$i} = ($constructs == 1 && $first_is_do && !$triangular);
    }
    if ($in_scop) {
        $depth++ if $s =~ /^do\b/;
        $depth-- if $s =~ /^end\s*do\b/ || $s =~ /^enddo\b/;
    }
    if ($s =~ /^!dir\$\s*(end\s*scop|endscop)/) { $in_scop = 0; }
}

# Pass 2: emit with pragmas
my @out; ($in_scop, $depth) = (0, 0);
for my $i (0..$#lines) {
    my $line = $lines[$i];
    my $s    = lc($line); $s =~ s/^\s+|\s+$//g;
    if ($s =~ /^!dir\$\s*scop\b/ && $s !~ /end/) { $in_scop = 1; $depth = 0; }
    if ($in_scop && $depth == 0 && $s =~ /^do\b/) {
        (my $ind = $line) =~ s/^(\s*).*/$1/;
        my $sizes = $has_inner{$i} ? "32,32" : "32";
        push @out, $ind . "!\$omp tile sizes($sizes)";
    }
    push @out, $line;
    if ($in_scop) {
        $depth++ if $s =~ /^do\b/;
        $depth-- if $s =~ /^end\s*do\b/ || $s =~ /^enddo\b/;
    }
    if ($s =~ /^!dir\$\s*(end\s*scop|endscop)/) { $in_scop = 0; }
}
print join("\n", @out);
'

# Perl script for UNROLLING: insert !$omp unroll factor(4) before every
# outermost do (depth works on any loop depth; no size disambiguation needed).
PERL_UNROLL='
use strict;
local $/;
my @lines = split /\n/, <>, -1;
my @out;
my ($in_scop, $depth) = (0, 0);
for my $line (@lines) {
    my $s = lc($line); $s =~ s/^\s+|\s+$//g;
    if ($s =~ /^!dir\$\s*scop\b/ && $s !~ /end/) { $in_scop = 1; $depth = 0; }
    if ($in_scop && $depth == 0 && $s =~ /^do\b/) {
        (my $ind = $line) =~ s/^(\s*).*/$1/;
        push @out, $ind . "!\$omp unroll factor(4)";
    }
    push @out, $line;
    if ($in_scop) {
        $depth++ if $s =~ /^do\b/;
        $depth-- if $s =~ /^end\s*do\b/ || $s =~ /^enddo\b/;
    }
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

    perl -e "$PERL_TILE"   < "$abs_bench" > "$tile_file"
    perl -e "$PERL_UNROLL" < "$abs_bench" > "$unroll_file"

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
