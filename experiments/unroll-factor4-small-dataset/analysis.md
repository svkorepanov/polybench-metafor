# Experiment: Loop Unrolling — factor=4 — SMALL_DATASET

## Setup

| Parameter | Value |
|---|---|
| Transform | `unrollGeneric.ts` → `LoopUnrollPass(4)` |
| Dataset | `SMALL_DATASET` (128×128 for most kernels) |
| Compiler | `flang-22 -O3 -fopenmp` |
| Platform | Linux 6.17.0, x86_64 |
| Date | 2026-06-05 |

## How to reproduce

```bash
find . -type d -name woven_code -exec rm -rf {} +   # clear previous transform
./weave-transpiler.sh unrollGeneric
./compile.sh && ./execute.sh
./compare.sh
```

## Results summary

| Category | Count | Benchmarks |
|---|---|---|
| MATCH — correct output | 8 | floyd-warshall, trisolv, dynprog, gramschmidt, seidel-2d, jacobi-1d-imper, jacobi-2d-imper, correlation |
| MISMATCH — incorrect output | 20 | all others |
| Skipped — parser error | 2 | atax, bicg (same `NamedConstantDef` bug as tiling experiment) |

This is a major regression vs tiling (26 correct vs 8 correct).

## Root cause: cleanup loop emitter bug

`LoopUnrollPass` replaces each `DO k = lo, hi` with two loops:

```fortran
! main loop (steps by factor)
DO k = lo, hi - (factor-1), factor
  body(k); body(k+1); body(k+2); body(k+3)   ! 4 copies
END DO

! cleanup loop (handles remainder)
DO k = lo + ((hi - lo + 1) / factor) * factor, hi
  body(k)
END DO
```

The cleanup lower bound formula `lo + ((hi - lo + 1) / factor) * factor` is
mathematically correct: when `factor` exactly divides the trip count, integer
division makes `((hi - lo + 1) / factor) * factor == hi - lo + 1`, giving
`lo + (hi - lo + 1) = hi + 1 > hi`, so the cleanup loop is empty.

**The bug**: the Fortran code emitter does not parenthesize sub-expressions of
compound binary operators. The AST for the formula is emitted as flat text:

```fortran
DO k = 1 + nk - 1 + 1 / 4 * 4, nk   ! generated (WRONG)
```

Fortran evaluates `*` and `/` before `+` and `-`, so:
- `1 / 4 = 0` (integer division)
- `0 * 4 = 0`
- `1 + nk - 1 + 0 = nk`

The cleanup loop always starts at `nk`, not `nk + 1`, so **when `factor`
exactly divides the trip count it runs one extra iteration** — re-executing
the last body statement once more.

The correct Fortran should be:
```fortran
DO k = 1 + ((nk - 1 + 1) / 4) * 4, nk   ! needs parentheses
! or equivalently:
DO k = (nk / 4) * 4 + 1, nk
```

The bug is in the Fortran AST serializer in `fortran-transpiler`
(`FortranJoinPoints` / code emitter) — it does not add parentheses when a
`+` or `-` node appears as the operand of a `/` or `*`.

## Why some benchmarks still MATCH

The extra cleanup iteration is only harmful for **accumulation** loop bodies.

| Loop body type | Effect of re-executing last iter | Result |
|---|---|---|
| Accumulation: `C += A(k) * B(k)` | Adds extra term → wrong sum | **MISMATCH** |
| Assignment: `B(j) = f(A(j))` | Overwrites with same value → idempotent | **MATCH** |

Matching benchmarks all have assignment/stencil inner loops:
- `jacobi-2d-imper`, `jacobi-1d-imper`, `seidel-2d` — stencil point updates
- `floyd-warshall` — min/comparison, not accumulation
- `gramschmidt` — orthogonalization, inner loop is an assignment
- `correlation` — normalization, assignment-style body

Mismatching benchmarks have accumulation inner loops:
- `gemm`, `3mm`, `2mm`, `syr2k`, `symm`, etc. — all matrix multiplications
  of the form `C(i,j) += alpha * A(i,k) * B(k,j)`

## Speedup

Speedups are in the 0.93–0.99× range — a slight slowdown. At SMALL_DATASET
with `-O3`, `flang-22` already auto-unrolls innermost loops. The explicit
4× unroll plus the extra cleanup overhead results in marginally slower code.
Real benefit of unrolling would show in `-O2` or with loop-carried accumulations
where the compiler fails to vectorize.

## Comparison with tiling experiment

| Metric | Tiling (tile=32) | Unrolling (factor=4) |
|---|---|---|
| Correct benchmarks | 26/28 | 8/28 |
| Root cause of failures | Illegal transform (triangular bounds) | Emitter bug (missing parentheses) |
| Fixable? | Yes — add legality check | Yes — fix AST serializer |

Tiling was substantially more reliable because it only fails on structurally
non-rectangular loops. Unrolling fails for any benchmark whose innermost loop
is an accumulation — the majority of PolyBench/Fortran kernels.

## How to fix the bug

The fix is in the Fortran code emitter inside `fortran-transpiler`. Binary
operator nodes that are children of `/` or `*` must be wrapped in parentheses
when serialized to text. Specifically, the cleanup lower bound should emit:

```fortran
DO k = (1) + (((nk) - (1) + 1) / 4) * 4, nk
```

An alternative workaround without touching the emitter: rewrite the cleanup
lower bound as `(hi / factor) * factor + lo`, which evaluates correctly under
Fortran's standard precedence rules:

```typescript
// lo + (hi / factor) * factor   →  correct without needing parens
const cleanupLower = FortranJoinPoints.binaryOperatorAdd(
  ctrl.lower.deepCopy(),
  FortranJoinPoints.binaryOperatorMultiply(
    FortranJoinPoints.binaryOperatorDivide(
      ctrl.upper.deepCopy(),
      FortranJoinPoints.intLiteral(factor)
    ),
    FortranJoinPoints.intLiteral(factor)
  )
);
```

For `lo=1, hi=128, factor=4`: `1 + (128/4)*4 = 1 + 32*4 = 129` → empty cleanup.
For `lo=1, hi=127, factor=4`: `1 + (127/4)*4 = 1 + 31*4 = 125` → covers 125,126,127.

(This works for `lo=1`; a fully general fix should use `lo + ((hi - lo + 1) / factor) * factor`
with the emitter fixed to parenthesize.)

## Next experiments

1. **Fix the emitter bug** and re-run unrolling — expect 26/28 correct results.
2. **fusionGeneric / fissionGeneric** — try structural transforms and see which
   benchmarks have fusible/fissable loop pairs.
3. **MEDIUM_DATASET unrolling** — larger problem size to see if unrolling
   actually helps throughput on memory-bound kernels even with the bug absent.
