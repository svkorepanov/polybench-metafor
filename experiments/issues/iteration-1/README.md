# Iteration 1 — Issue Analysis

First pass at identifying and documenting correctness failures across all five
loop transforms on SMALL_DATASET.

## Contents

| File | What it contains |
|---|---|
| `cross-transform-mismatches.md` | Full table of all 15 failures across fission (9), fusion (3), interchange (3); pattern summary |
| `fusion-legality-analysis.md` | Three AST-detectable patterns that make fusion illegal (Check A, B, C) with Fortran examples and detection rules |
| `interchange-legality-analysis.md` | Two AST-detectable patterns that make interchange illegal (Check 1, 2) with Fortran examples, timeline traces, and a `canInterchange()` sketch |

## Summary at end of iteration 1

| Transform | MATCH | MISMATCH | State |
|---|---|---|---|
| Unrolling | 30/30 | 0 | Resolved |
| Tiling | 28/30 | 2 | Open (`reg_detect`, `trmm`) |
| Fusion | 27/30 | 3 | Open (`gemver`, `doitgen`, `atax`) |
| Interchange | 27/30 | 3 | Open (`reg_detect`, `covariance`, `trmm`) |
| Fission | 21/30 | 9 | Open (9 solver/stencil benchmarks) |
