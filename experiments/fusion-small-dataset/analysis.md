# Experiment: Loop Fusion — SMALL_DATASET

## Setup

| Parameter | Value |
|---|---|
| Transform | `fusionGeneric.ts` → `LoopFusionPass()` |
| Dataset | `SMALL_DATASET` (128×128 for most kernels) |
| Compiler | `flang-22 -O3 -fopenmp` |
| Platform | Linux 6.17.0, x86_64 |
| Date | 2026-06-12 |
| Branch | `fix/emitter-paren-binop` (also contains NullPointerException fix for LoopFusionPass) |

## How to reproduce

```bash
# From polybench-metafor/
./preproc.sh
./compile.sh && ./execute.sh          # baseline (or restore from experiments/baseline-small-dataset/)
./weave-transpiler.sh fusionGeneric   # transform
./compile.sh && ./execute.sh          # woven
./compare.sh
```

## Results summary

| Category | Count | Benchmarks |
|---|---|---|
| MATCH — correct output | 27 | all except the three below |
| MISMATCH — dependency violation | 3 | `gemver`, `doitgen`, `atax` |

## Mismatch summary

| Benchmark | Fused loops | Dependency type | What goes wrong |
|---|---|---|---|
| `atax` | Two inner `do j = 1, ny` loops (accumulate `tmp` + use `tmp`) | Flow dep: `y(j)` reads partial `tmp(i)` — only first `j` contributions accumulated | Wrong `y` vector |
| `doitgen` | Two outer `do p = 1, np` loops (compute `sumA` + write-back `a`) | WAR across iterations: `a(p)` written before later `s`-loops finish reading `a(s)` for `s < p` | Wrong matrix-vector product |
| `gemver` | Four outer `do i = 1, n` loops (update `A`, compute `x`, add `z`, compute `w`) | Flow dep ×2: `A` partially updated when `x` reads its row; `x` partially computed when `w` reads all elements | Wrong `x` and `w` vectors |

## Correctness analysis

Loop fusion merges consecutive loops with identical bounds into a single loop,
moving all body statements into one combined body. This is semantically correct
**only if** no statement in the merged body reads a value that the preceding
statement is still accumulating across iterations. `LoopFusionPass` checks only
that loop bounds match (`sameScope`) — it does not check for flow dependencies
between the loops being fused.

### `atax` — partial reduction exposed by inner-loop fusion

```fortran
! Original (correct):
do i = 1, nx
  tmp(i) = 0.0D0
  do j = 1, ny
    tmp(i) = tmp(i) + (a(j, i) * x(j))  ! Loop A: accumulate tmp(i) over ALL j
  end do
  do j = 1, ny
    y(j) = y(j) + a(j, i) * tmp(i)      ! Loop B: use FINAL tmp(i)
  end do
end do

! After fusion (wrong):
do i = 1, nx
  tmp(i) = 0.0D0
  do j = 1, ny
    tmp(i) = tmp(i) + (a(j, i) * x(j))  ! accumulate...
    y(j) = y(j) + a(j, i) * tmp(i)      ! ...but tmp(i) is partial — only j contributions seen so far
  end do
end do
```

`LoopFusionPass` finds the two inner `do j = 1, ny` loops with matching bounds
and fuses them. In the fused loop, `y(j)` is updated using `tmp(i)` after only
the first `j` contributions have been added. The correct `tmp(i)` requires all
`j = 1..ny` contributions before `y(j)` can use it.

**Root cause**: flow dependency — Loop B's input (`tmp(i)`) is produced by the
full execution of Loop A. Fusion makes Loop B read a partial value.

### `doitgen` — overwritten input array during computation

```fortran
! Original (correct):
do p = 1, np
  sumA(p, q, r) = 0.0D0
  do s = 1, np
    sumA(p, q, r) = sumA(p, q, r) + (a(s, q, r) * cFour(p, s))  ! reads a(s) for all s
  end do
end do
do p = 1, np
  a(p, q, r) = sumA(p, q, r)   ! write-back AFTER all sumA values computed
end do

! After fusion (wrong):
do p = 1, np
  sumA(p, q, r) = 0.0D0
  do s = 1, np
    sumA(p, q, r) = sumA(p, q, r) + (a(s, q, r) * cFour(p, s))  ! reads a(s) — already corrupted for s < p
  end do
  a(p, q, r) = sumA(p, q, r)   ! write-back overwrites a(p) immediately
end do
```

In the fused loop, iteration p=1 sets `a(1, q, r) = sumA(1, q, r)` (the new
value). When iteration p=2 runs its inner s-loop, it reads `a(s=1, q, r)` —
now the new value, not the original. In the original code, ALL `sumA` values
are computed from the unmodified `a` before any write-back occurs.

**Root cause**: WAR (write-after-read) dependency — the write-back loop
overwrites elements of `a` that the computation loop still needs to read
in subsequent iterations.

### `gemver` — two dependency violations from fusing 4 consecutive loops

The `gemver` kernel has four sequential loops over `i = 1, n`:

```
Loop 1:  a(j,i) += u1(i)*v1(j) + u2(i)*v2(j)   for all j  → updates A column i
Loop 2:  x(i)   += beta * a(i,j) * y(j)          for all j  → reads A ROW i (all columns)
Loop 3:  x(i)   += z(i)                                       → finalizes x(i)
Loop 4:  w(i)   += alpha * a(j,i) * x(j)         for all j  → reads x(j) for all j
```

After fusion into a single `do i = 1, n` loop:

**Violation 1** (Loops 1→2): In iteration `i=k`, Loop 1 updates column k of A
(`a(j,k)` for all j). Loop 2 reads row k of A (`a(k,j)` for all j = a(k,1)..a(k,n)).
Columns 1..k-1 of A have already been updated in prior iterations; columns k+1..n
have not yet been updated. The original code requires ALL of A to be updated before
Loop 2 starts. The fused loop reads partially-updated A.

**Violation 2** (Loops 2/3→4): Loop 4 in iteration `i=k` reads `x(j)` for all j.
In the fused loop, `x(j)` for `j > k` hasn't been computed yet (those iterations
haven't run). The original code requires `x` to be fully computed before Loop 4
starts. The fused loop uses a partially-computed `x`.

**Root cause**: both violations are flow dependencies — a later loop reads a
result that requires the prior loop to run to completion before any element is
consumed. Fusion interleaves production and consumption across iterations.

## Transform? column

Like fission, fusion produces loops with the same 2-argument `DO var = lo, hi`
form — no step argument, no OMP directives. The `Transform?=NO` column does not
mean fusion was unapplied; it means the current detection heuristics (OMP
directives or 3-argument DO statements) do not cover fusion. A correct detection
would compare the number of consecutive same-bound DO loops between the original
and woven files.

## Cross-transform mismatch overview

See [`../issues/cross-transform-mismatches.md`](../issues/cross-transform-mismatches.md) for the full table of all 15 failures across fission, fusion, and interchange, including pattern summary.

## Comparison with fission

| | Fission | Fusion |
|---|---|---|
| MATCH | 21/30 | **27/30** |
| Mismatches | 9 | 3 |
| Failure pattern | Loop-carried deps across iterations | Flow deps requiring full prior loop completion |

Fusion is safer than fission in this benchmark suite: fission splits loops and
exposes cross-iteration read-after-write dependencies; fusion merges loops and
exposes intra-iteration read-before-fully-written dependencies. There are fewer
benchmarks where the latter pattern appears because most PolyBench kernels either
have independent loops (where fusion is fine) or loops with clear accumulation
patterns where the write-back is kept separate by design.

## Current limitation of LoopFusionPass

`LoopFusionPass` checks only that consecutive do-loops share the same bounds
(`sameScope`). It does not check whether fusing those loops would expose a
dependency. A sound legality check would need to verify that for each pair of
loops being fused, no value produced by the first loop's complete execution is
consumed by the second loop within the same outer iteration.

## Next experiments

1. **Fusion at LARGE_DATASET** — for the 27 correct benchmarks, measure
   cache-locality speedup from fused loops operating on shared arrays.
2. **Fission → Fusion round-trip** — apply fission then fusion and verify
   idempotency (should recover original structure for independent-body loops).
3. **Legality check for fusion** — add dependency analysis to `LoopFusionPass`
   to avoid the 3 mismatches.
