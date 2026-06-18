#!/bin/bash
# run-blind-tile.sh — Blind !$omp tile sizes(32,32) on every outermost scop loop.
#
# No legality check. No size adaptation. sizes(32,32) on everything, always.
# Documents which benchmarks compile, execute correctly, crash, or produce wrong output.
#
# Dataset : SMALL_DATASET + POLYBENCH_DUMP_ARRAYS
# Compiler: flang-22 -fopenmp -fopenmp-version=51

POLYBENCH_ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$POLYBENCH_ROOT"

ITER_DIR="$POLYBENCH_ROOT/experiments/issues/iteration-7"
RESULT_FILE="$ITER_DIR/blind-tile-results.txt"
LOG="$ITER_DIR/blind-tile.log"
UTILITIES_DIR="$POLYBENCH_ROOT/utilities"

mkdir -p "$ITER_DIR"
> "$LOG"
> "$RESULT_FILE"

FC="flang-22"
CC="clang-22"
FFLAGS="-O3 -fopenmp -fopenmp-version=51 -Wno-ignored-directive -L/usr/lib/llvm-20/lib"
CFLAGS="-O3 -fopenmp -I/usr/lib/gcc/x86_64-linux-gnu/15/include"
PARGS="-DSMALL_DATASET -DPOLYBENCH_DUMP_ARRAYS"

log() { echo "$*" | tee -a "$LOG"; }

# Perl: insert !$omp tile sizes(32,32) before EVERY outermost DO in scop. No checks.
PERL_BLIND='
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
        push @out, "${ind}!\$omp tile sizes(32,32)";
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

log "=== Blind !$omp tile sizes(32,32) experiment ==="
log "Rule: sizes(32,32) before EVERY outermost scop DO — no legality check"
log "Flags: $FFLAGS $PARGS"
log "Started: $(date)"
log ""

# ── Compile fpolybench.c ───────────────────────────────────────────────────────
log "Compiling fpolybench.c..."
$CC $CFLAGS $PARGS -c "$UTILITIES_DIR/fpolybench.c" -I "$UTILITIES_DIR" \
    -o "$UTILITIES_DIR/fpolybench.o" 2>>"$LOG" || { log "ABORT: fpolybench.c failed"; exit 1; }
log "Done."
log ""

# ── Clean stale woven dirs ─────────────────────────────────────────────────────
find . -type d -name "woven_code" -exec rm -rf {} + 2>/dev/null || true

# ── Results table header ───────────────────────────────────────────────────────
printf "%-18s | %-8s | %-8s | %-10s | %s\n" \
    "Benchmark" "Compile" "Execute" "Compare" "Notes" | tee -a "$RESULT_FILE"
printf "%s\n" "$(printf '─%.0s' {1..80})" | tee -a "$RESULT_FILE"

# ── Per-benchmark loop ─────────────────────────────────────────────────────────
while IFS= read -r src; do
    abs_src="$(realpath "$src")"
    bench_dir="$(dirname "$abs_src")"
    name="$(basename "$abs_src" .preproc.f90)"

    orig_exe="$bench_dir/${name}.exe"
    orig_out="$bench_dir/${name}.output.txt"
    woven_dir="$bench_dir/woven_code"
    woven_src="$woven_dir/${name}.preproc.f90"
    woven_exe="$woven_dir/${name}.exe"
    woven_out="$woven_dir/${name}.output.txt"

    mkdir -p "$woven_dir"
    echo "YES" > "$woven_dir/.transform-status"

    # Generate blind-tiled source
    perl -e "$PERL_BLIND" < "$abs_src" > "$woven_src"

    # Compile original (for baseline output)
    $FC $FFLAGS $PARGS "$abs_src" "$UTILITIES_DIR/fpolybench.o" \
        -I "$UTILITIES_DIR" -o "$orig_exe" 2>>"$LOG"

    # Execute original
    [ -f "$orig_exe" ] && "$orig_exe" > "$orig_out" 2>&1

    # Compile woven — capture stderr
    compile_err="$woven_dir/.compile.err"
    compile_status="OK"
    compile_note=""
    if ! $FC $FFLAGS $PARGS "$woven_src" "$UTILITIES_DIR/fpolybench.o" \
            -I "$UTILITIES_DIR" -o "$woven_exe" 2>"$compile_err"; then
        compile_status="FAIL"
        # Extract first meaningful error
        compile_note=$(grep "error:" "$compile_err" | grep -v "^warning" | head -1 \
                       | sed 's|.*error: ||' | cut -c1-55)
    fi

    # Execute woven
    exec_status="N/A"
    if [ "$compile_status" = "OK" ]; then
        set +e
        timeout 30 "$woven_exe" > "$woven_out" 2>&1
        ec=$?
        set -e
        if   [ $ec -eq 124 ]; then exec_status="TIMEOUT"
        elif [ $ec -eq 139 ] || [ $ec -eq 134 ]; then exec_status="CRASH"
        elif [ $ec -ne 0 ];  then exec_status="ERROR($ec)"
        else exec_status="OK"
        fi
    fi

    # Compare
    compare_status="N/A"
    if [ "$exec_status" = "OK" ] && [ -f "$orig_out" ] && [ -f "$woven_out" ]; then
        strip_timer() { perl -0777 -pe 's/\s*[\d.eE+-]+\s*$/\n/' "$1"; }
        if diff -q <(strip_timer "$orig_out") <(strip_timer "$woven_out") &>/dev/null; then
            compare_status="MATCH"
        else
            compare_status="MISMATCH"
        fi
    fi

    printf "%-18s | %-8s | %-8s | %-10s | %s\n" \
        "$name" "$compile_status" "$exec_status" "$compare_status" "$compile_note" \
        | tee -a "$RESULT_FILE"
    log "  $name: compile=$compile_status exec=$exec_status compare=$compare_status"

done < <(find . -path "*/woven_code" -prune \
              -o -name "*.omp-tile.preproc.f90" -prune \
              -o -name "*.omp-unroll.preproc.f90" -prune \
              -o -type f -name "*.preproc.f90" -print | sort)

printf "%s\n" "$(printf '─%.0s' {1..80})" | tee -a "$RESULT_FILE"

# ── Summary counts ─────────────────────────────────────────────────────────────
compile_ok=$(grep -c "| OK " "$RESULT_FILE" || true)
compile_fail=$(grep -c "| FAIL " "$RESULT_FILE" || true)
match=$(grep -c "| MATCH " "$RESULT_FILE" || true)
mismatch=$(grep -c "| MISMATCH " "$RESULT_FILE" || true)
crash=$(grep -c "| CRASH " "$RESULT_FILE" || true)

{
echo ""
echo "Compile OK   : $compile_ok / 30"
echo "Compile FAIL : $compile_fail / 30"
echo "MATCH        : $match"
echo "MISMATCH     : $mismatch"
echo "CRASH        : $crash"
} | tee -a "$RESULT_FILE" | tee -a "$LOG"

log ""
log "Results : $RESULT_FILE"
log "Log     : $LOG"
log "Done    : $(date)"
