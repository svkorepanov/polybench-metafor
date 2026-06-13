# Iteration 2: Loop Fusion — SMALL_DATASET

## Status: RESOLVED — 30/30 MATCH

| Parameter | Value |
|---|---|
| Transform | `fusionGeneric.ts` → `LoopFusionPass` |
| Dataset | SMALL_DATASET |
| Date | 2026-06-12 |
| Transpiler commit | `5ec351c` |

## Changes since iteration 1

`LoopFusionPass` was updated in `5ec351c` to add `_canFusePair()` — three
syntactic dependency checks that split a fusion group at any consecutive
pair that fails legality. `loopWrites`/`loopReads` helpers collect array
accesses via `AssignmentStatement` + `ArraySubscriptExpr`; array names are
obtained via `expr.var.name` (not `expr.name`, which returns `""` in LARA).

| Check | What it catches |
|---|---|
| **A** | Write subscript contains no fusion variable → same element accumulated every iteration; other loop reads partial result |
| **B** | Write `X(inner, fv)` in A, read `X(fv, inner)` in B → transposed cross-iteration dependency |
| **C** | Write with `fv`-only subscript (one element per fusion iteration), read with inner-var subscript (spans full range) → forward/backward cross-iteration dependency |

Groups are **split** at illegal pairs, not rejected whole: for `gemver`'s
4-loop group `[A, B, C, D]`, pair `(A,B)` fails Check B and `(C,D)` fails
Check C, so only `[B, C]` is fused — which is legal and correct.

## Result

| Category | Count | Benchmarks |
|---|---|---|
| MATCH | 30 | all |
| MISMATCH | 0 | — |

Fused benchmarks (8): `reg_detect`, `gemver`, `syr2k`, `2mm`, `mvt`,
`syrk`, `jacobi-2d-imper`, `correlation`.

## Previously failing benchmarks — now resolved

| Benchmark | Pattern | Resolution |
|---|---|---|
| `atax` | Check A: `tmp(i)` written in A (subscript = outer var, no fv `j`) and read in B → partial accumulation | Pair `(A,B)` rejected by Check A |
| `doitgen` | Check C: B writes `a(p,q,r)` (fv `p` only), A reads `a(s,q,r)` (inner var `s` in same dim) | Pair `(A,B)` reversed Check C |
| `gemver` | Check B: A writes `a(j,i)`, B reads `a(i,j)` (transposed); Check C: C writes `x(i)`, D reads `x(j)` | Group split: `[B,C]` fused, `A` and `D` kept separate |

## Raw results

See `fusion-results.txt` in this folder.
