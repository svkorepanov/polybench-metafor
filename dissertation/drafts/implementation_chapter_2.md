# Implementation — Bullet-Point Draft

> **Scope**: Implementation chapter covering the five loop transformations, iterative
> correctness engineering (issues iterations 1–3), and infrastructure bugs found and fixed.
> Correctness data: `experiments/issues/` iterations 1–3 (SMALL_DATASET, 128×128).
> Status: **draft scaffold** — expand each bullet into prose.

---

## Chapter 6 — Implementation

### 6.1 Architecture Overview

- The framework is a four-stage pipeline: **Flang-22 → `flang-dumper` plugin → JSON → Java AST → LARA weaver → Fortran-JS transformation scripts**.
- The `flang-dumper` plugin was extended iteratively to expose nodes required by loop transformations: loop controls (`RangeLoopControl`), array subscripts, scalar variables, and expression trees — none of these were fully available in the initial dumper.
- The Fortran-JS layer exposes AST nodes as TypeScript join points; transformation logic lives entirely in `.ts` scripts, allowing users to write new transforms without touching the Java layer.
- A clear pipeline separation (parsing / AST / weaving / scripting) allowed bugs to be localized to a single layer: most correctness failures were in the scripting or emitter layer, not in the parser.

### 6.2 Five Loop Transformations

- **Loop Interchange** (`LoopInterchange.ts`) — swaps the outer and inner `DO` headers of a 2-deep perfect nest; body is unchanged; no pass class (implemented as manual AST surgery).
- **Loop Fusion** (`LoopFusion.ts` via `LoopFusionPass`) — merges consecutive loops with identical bounds; checks bounds equality (`sameScope`) before merging.
- **Loop Fission** (`LoopFission.ts` via `LoopFissionPass`) — splits a loop whose body contains ≥2 statements into one loop per statement; uses `canFission()` to guard each split.
- **Loop Tiling** (`LoopTiling.ts` via `LoopTilingPass(32)`) — introduces two outer strip-mine loops and two inner tile loops around a 2-deep nest; tile size fixed at 32.
- **Loop Unrolling** (`LoopUnroll.ts` via `LoopUnrollPass(4)`) — unrolls the innermost simple `DO` loop by factor 4; generates a main loop (step 4) and a cleanup loop for the remainder.
- All generic scripts (`tilingGeneric.ts`, etc.) target subroutines whose name starts with `kernel_` via `Query.search(Subroutine, $jp => $jp.moduleName.startsWith('kernel_'))`.

### 6.3 Iterative Correctness Engineering (Issues Iterations 1–3)

#### Iteration 1 — First pass (2026-06-12): baseline failure analysis

- **Fission: 21/30 MATCH** — 9 failures all traced to loop-carried dependencies: `gramschmidt` (scalar `nrm` threading across iterations), `trisolv` / `cholesky` / `lu` / `ludcmp` (forward-substitution updates destroyed), `adi` / `fdtd-2d` / `fdtd-apml` (intra-timestep coupling between sub-loops).
- **Fusion: 27/30 MATCH** — 3 failures: `atax` (partial reduction `tmp(i)` consumed mid-accumulation), `doitgen` (write-back `a(p) = sumA(p)` overwrites values needed by the next outer iteration's inner loop), `gemver` (transposed subscript cross-iteration: `A(j,i)` written, `A(i,j)` read, column vs. row mismatch).
- **Interchange: 27/30 MATCH** — 3 failures: `reg_detect` (inner bound `do i = j, maxgrid` — after swap `j` is undefined, garbage loop bound), `covariance` (same triangular pattern, `j1` becomes undefined → segfault), `trmm` (rectangular bounds but body has `do k = 1, i-1` — interchange reverses a read-before-write into write-before-read on `b(k,j)`).
- **Tiling: 28/30 MATCH** — same 2 structural patterns as interchange: `reg_detect` (triangular inner bound) and `trmm` (nested `k`-loop in body with outer-variable bound).
- **Unrolling: 30/30 MATCH** (after emitter fix; see §6.4).
- Root-cause taxonomy from iteration 1: **producer–consumer split** (fission), **incomplete-producer merge** (fusion), **undefined bound variable** (interchange/tiling Check 1), **evaluation-order violation** (interchange/tiling Check 2).

#### Iteration 2 — Legality guards for interchange and fusion (2026-06-12)

- **Interchange fixed: 30/30** — implemented `canInterchange()` with two syntactic checks on `RangeLoopControl.lower.code` / `.upper.code`:
  - *Check 1*: Reject if inner loop bound contains the outer variable name (triangular bounds). Catches `reg_detect`, `covariance`.
  - *Check 2*: Reject if any descendant `DoStatement` inside the inner body has a bound containing the outer variable name. Catches `trmm`.
  - No data-flow analysis required; both checks are pure string searches on bound expressions exposed as `.code` by the LARA join point.
- **Fusion fixed: 30/30** — implemented `_canFusePair()` with three dependency-pattern checks:
  - *Check A* (reduction not complete): write inside a nested loop at subscript `X(outer_var_only)` → read in next loop → reject.
  - *Check B* (transposed subscript): write `X(w, v)` in loop A, read `X(v, w)` in loop B where `v` is the fusion variable → reject.
  - *Check C* (write-back before read): `X` written at outer level (depth 1) in loop B while read inside nested loop (depth > 1) in loop A → reject.
- **Tiling: still 28/30** (not re-run; same root cause as interchange identified but fix deferred).
- **Fission: still 21/30** (not re-run; loop-carried dependency analysis more complex than syntactic checks).

#### Iteration 3 — Tiling and fission resolved (2026-06-13)

- **Tiling fixed: 30/30** — extended `canTile()` with the same two checks as `canInterchange()`, but using **word-boundary regex** (`\bvarName\b`) instead of `.includes()` to avoid false positives:
  - Example false positive without `\b`: `syrk` has dimension `ni`, and the outer loop variable `i` would match inside `ni` under plain `.includes()`, incorrectly blocking a safe tiling.
  - After fix, `reg_detect` tiles the inner `(i, cnt)` pair (safe: outer `j` preserved, `i >= j` constraint survives), and `trmm` tiles the `(j, k)` pair inside the fixed `i`-loop (safe: `k`-bound `1..i-1` stays constant for fixed `i`).
- **Fission fixed: 30/30** — two changes:
  1. **Root bug fix**: `canFission()` helpers called `Query.searchFrom(stmt, AssignmentStatement)` which searches only *children* of `stmt`. When `stmt` itself is an `AssignmentStatement` (direct body statement, not a nested loop), the search returned nothing and all checks silently passed. Fix: switch to `Query.searchFromInclusive` in all three helpers (`stmtArrayWrites`, `stmtArrayReads`, `stmtScalarWrites`).
  2. *Check 1 — Scalar threading*: if any scalar written in statement S_i appears (word-boundary regex) in any later S_j → reject split. Catches `gramschmidt` (`nrm`), `cholesky` (`x`), `symm` accumulator, `ludcmp` (`w`).
  3. *Check 2 — Array write-before-read*: if later statement S_j writes array X and earlier S_i reads X → reject split. Catches `trisolv`, `lu`, `ludcmp`, `adi`, `fdtd-2d`, `fdtd-apml`.
  4. **Safe fission in `symm`**: the *inner* `k`-loop body has two genuinely independent statements; `canFission()` approves the k-split. The enclosing j-loop is then correctly blocked (Check 1: scalar `acc` written in S1, read inside k-loop2).

#### End state: 30/30 MATCH on all five transforms at SMALL_DATASET

| Transform | Iter 1 | Iter 2 | Iter 3 | Fix |
|---|---|---|---|---|
| Unrolling | 30/30 | — | — | Emitter fix (§6.4) |
| Interchange | 27/30 | **30/30** | — | `canInterchange()` Check 1 + 2 |
| Fusion | 27/30 | **30/30** | — | `_canFusePair()` Check A + B + C |
| Tiling | 28/30 | 28/30 | **30/30** | `canTile()` Check 1 + 2 + `\b` regex |
| Fission | 21/30 | 21/30 | **30/30** | `searchFromInclusive` bug + Check 1 + 2 |

### 6.4 Infrastructure Bugs Found and Fixed

- **`NamedConstantDef` AST node unimplemented**: `atax` and `bicg` contain `PARAMETER` declarations; `flang-dumper` emits a `NamedConstantDef` node that the Java parser hard-crashes on (`RuntimeException: Could not find derived key`). Affects 2/30 benchmarks for any transform. Fix requires adding the node to `FlangName` enum and `Nodes.java` (Java layer only). In the current evaluation, these benchmarks fall back to the unmodified source and show MATCH because the original code is compared against itself.
- **Emitter does not parenthesize compound right-hand operands of subtraction**: `Subtract(A, BinaryOp(B, C))` emits as `A - B op C` instead of `A - (B op C)`. This broke unrolling cleanup-loop bounds for `dynprog` (`lo = i+1`), `lu` (`lo = k+1`), and `adi` (induction variable in body). Fixed in branch `fix/emitter-paren-binop` before the main experiment runs.
- **`compare.sh` transform detection heuristic**: detects a transform by matching 3-argument `DO var = lo, hi, step` statements; this labels unrolled code as `Transform?=TILED` because the main unroll loop has step 4. A dedicated `UNROLLED` detection path would require a separate pattern (e.g. matching step-4 without an enclosing tile-stride loop) or a metadata sidecar file written by the transform.
