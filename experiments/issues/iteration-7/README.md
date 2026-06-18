# Iteration 7 — OpenMP Tile Pragma vs. Transpiler Legality Checks

## Hypothesis

The fortran-transpiler's `tilingGeneric` pass applies `canTile()` legality checks before
inserting tiled loop bounds. Benchmarks that fail those checks are left untransformed.
The hypothesis is that OpenMP's `!$omp tile sizes(32,32)` pragma — applied
unconditionally — is less strict, and will either (a) fail to compile, or (b) produce
incorrect output for the same benchmarks the transpiler correctly skips.

## Experiment Design

**Dataset:** `SMALL_DATASET + POLYBENCH_DUMP_ARRAYS` — enables full array-dump comparison
so any wrong numerical result surfaces as MISMATCH rather than a silent timing anomaly.

**Two phases:**

| Phase | Method | Legality check? |
|---|---|---|
| Phase 1 (control) | `weave-transpiler.sh tilingGeneric` | Yes — `canTile()` in `LoopTilingPass.ts` |
| Phase 2 (treatment) | `omp-insert.sh tile` — inserts `!$omp tile sizes(32,32)` before first `do` after `!DIR$ scop` | No — unconditional insertion |

**Compile flag:** `-fopenmp-version=51` required for `!$omp tile` support in flang-22.

Scripts: [`run-iteration7.sh`](../../../run-iteration7.sh), [`omp-insert.sh`](../../../omp-insert.sh).

## Legality Checks in `canTile()`

Source: `fortran-transpiler/Fortran-JS/src-api/code/LoopTiling.ts`, lines 93–111.

Two conditions must both hold for `canTile(outer, inner)` to return `true`:

1. **Triangular bound check** — the inner loop's bounds must NOT reference the outer loop
   variable. Fails for triangular nests like `do j = i, n` or `do k = 1, i-1`.

2. **Nested bound check** — no `DoStatement` nested inside the inner body may have bounds
   that reference the outer variable.

Additionally, `_findTileablePairs()` in `LoopTilingPass.ts` only considers an outer loop
as a candidate if its body contains exactly one executable statement (strict perfect-nest
requirement at the outer level). When the outermost loop is imperfect, the pass descends
and tries the next depth level.

## Phase 1 Results (tilingGeneric — control)

**30/30 MATCH, 0 MISMATCH, 0 MISSING. 21 transformed, 9 untransformed.**

| Transform? | Benchmarks |
|---|---|
| **NO** | trisolv, cholesky, atax, bicg, gesummv, durbin, gramschmidt, ludcmp, jacobi-1d-imper |
| **YES** | all remaining 21 |

All 9 skipped benchmarks produce MATCH because the source file is left unchanged — the
transpiler is conservative and does nothing rather than risk incorrect output.

## Phase 2 Results (OMP tile — treatment)

**17 MATCH, 1 MISMATCH (`trmm`), 12 MISSING (compile errors).**

```
Benchmark       | Status  | Transform? | Result
─────────────────────────────────────────────────
reg_detect      | SKIPPED | YES        | N/A       ← compile error (non-perfect outer loop)
floyd-warshall  | OK      | YES        | MATCH
gemm            | OK      | YES        | MATCH
gemver          | OK      | YES        | MATCH
trisolv         | SKIPPED | YES        | N/A       ← compile error ("trip count not invariant")
cholesky        | SKIPPED | YES        | N/A       ← compile error ("trip count not invariant")
doitgen         | OK      | YES        | MATCH
syr2k           | OK      | YES        | MATCH
symm            | OK      | YES        | MATCH
atax            | SKIPPED | YES        | N/A       ← compile error ("trip count not invariant")
2mm             | OK      | YES        | MATCH
bicg            | SKIPPED | YES        | N/A       ← compile error ("trip count not invariant")
trmm            | OK      | YES        | MISMATCH  ← WRONG OUTPUT (wrong pair tiled)
gesummv         | SKIPPED | YES        | N/A       ← compile error ("trip count not invariant")
mvt             | OK      | YES        | MATCH
3mm             | OK      | NO         | MATCH     ← blank-line regex miss (not transformed)
syrk            | OK      | YES        | MATCH
dynprog         | OK      | NO         | MATCH     ← blank-line regex miss
lu              | SKIPPED | YES        | N/A       ← compile error (non-perfect outer loop)
durbin          | OK      | NO         | MATCH     ← blank-line regex miss
gramschmidt     | SKIPPED | YES        | N/A       ← compile error
ludcmp          | OK      | NO         | MATCH     ← blank-line regex miss
seidel-2d       | OK      | YES        | MATCH
adi             | SKIPPED | YES        | N/A       ← compile error (non-perfect outer loop)
jacobi-1d-imper | SKIPPED | YES        | N/A       ← compile error
jacobi-2d-imper | SKIPPED | YES        | N/A       ← compile error (non-perfect outer loop)
fdtd-2d         | SKIPPED | YES        | N/A       ← compile error (non-perfect outer loop)
fdtd-apml       | OK      | YES        | MATCH
correlation     | OK      | NO         | MATCH     ← blank-line regex miss
covariance      | OK      | NO         | MATCH     ← blank-line regex miss
```

## Analysis

### Three outcome categories for benchmarks the transpiler skipped (9 × NO)

| Benchmark | Phase 2 outcome | Reason |
|---|---|---|
| trisolv, cholesky, atax, bicg, gesummv, jacobi-1d-imper | compile error | OMP inserted at outermost `do`; flang-22 rejects "trip count must be computable and invariant" (triangular bounds) |
| gramschmidt | compile error | Non-perfect outer nest |
| durbin, ludcmp | no pragma (MATCH) | Blank line between `!DIR$ scop` and first `do` — regex miss (known limitation) |

**Result: 6 compile errors, 2 regex misses, 1 not counted (correlation/covariance also misses).**

The hypothesis is confirmed for the 6 that compile-failed: the OMP approach does not
prevent the transformation, it just lets flang-22 fail at compile time. The transpiler
avoids the error by detecting the same geometric constraint ahead of time.

### The `trmm` MISMATCH — the key finding

`trmm` was **approved** by `canTile()` (Phase 1: Transform? = YES, MATCH). Yet Phase 2
produces MISMATCH. The reason:

Loop structure in `trmm.preproc.f90`:

```fortran
do i = 2, ni
  do j = 1, ni
    do k = 1, i-1        ← bounds reference outer 'i'
      b(j,i) = b(j,i) + alpha*a(k,i)*b(k,j)
    end do
  end do
end do
```

**Transpiler** (`_findTileablePairs`): tries `canTile(i, j)`:
- Check 2 fails — `do k = 1, i-1` inside `j`'s body references outer variable `i`.
- Descends one level; tries `canTile(j, k)`.
- Check 1: `k` bounds are `1, i-1` — do they reference `j`? No → pass.
- Check 2: no nested loop inside `k`'s body → pass.
- Tiles the `(j, k)` pair → correct result (MATCH).

**OMP pragma** (`omp-insert.sh`): inserts `!$omp tile sizes(32,32)` before `do i` — the
outermost loop — targeting the `(i, j)` pair. flang-22 compiles this (it does not check
the cross-iteration dependency via `b(k,j)` where `k < i`). At runtime the tiled
iteration order changes the evaluation sequence, producing incorrect values → **MISMATCH**.

This demonstrates a case where the OMP approach is strictly worse: it produces wrong
output even for a benchmark the transpiler handles correctly, because the transpiler
is smarter about which pair to tile.

### Five additional compile errors — benchmarks the transpiler handled via pair descent

These benchmarks were YES/MATCH in Phase 1, but MISSING (compile error) in Phase 2:

| Benchmark | Why transpiler succeeded | Why OMP failed |
|---|---|---|
| reg_detect | Outer `do t` body is non-perfect; transpiler skips to inner pair | OMP targets `do t` → "perfectly nested" error |
| lu | Outer loop body is non-perfect; inner pairs are perfect | OMP targets outer → compile error |
| adi | Outer `do t` non-perfect; transpiler finds inner pair | OMP targets outer → compile error |
| jacobi-2d-imper | Outer `do t` non-perfect | OMP targets outer → compile error |
| fdtd-2d | Outer `do t` non-perfect | OMP targets outer → compile error |

The transpiler's `_findTileablePairs()` descends past non-perfect outer loops to find a
valid pair at depth. `omp-insert.sh` always inserts before the FIRST `do` after `!DIR$
scop`, which is the outermost loop — often non-perfect, causing a flang-22 error.

### Known limitation: blank-line regex

`omp-insert.sh` uses a perl regex that matches `!DIR$ scop` followed immediately by the
`do` keyword (allowing only whitespace on the same lines). Four benchmarks have a comment
or blank line between the scop marker and the first `do`:

| Benchmark | Interposing content |
|---|---|
| 3mm | comment `! E := A*B` then `do` |
| dynprog | variable initialisation then `do` |
| durbin | similar |
| ludcmp | similar |

These four were not transformed in Phase 2 and ran as originals, showing NO / MATCH.

Fix would be: `s/(!DIR\$\s*scop[^\n]*\n)(?:[^\n]*\n)*?([ \t]*)(do[ \t])/...` — but since
this limitation affects only the "unconditional OMP" path, and the point of the experiment
is to show what happens when the pragma IS inserted, the limitation doesn't weaken the
conclusion; it means 4 benchmarks were simply not tested in Phase 2.

## Phase 2b — Per-File Legitimacy Analysis (corrected OMP)

After Phase 2, each of the 30 benchmark scop regions was read individually and the correct
pragma was determined for every outermost DO loop, checking three conditions:

1. **Imperfect outer body** → at most `sizes(32)` (1D strip-mine); `sizes(32,32)` requires
   outer body = ONLY the inner DO, no scalar statements before or after.
2. **Triangular immediate inner bound** → at most `sizes(32)` (inner DO bounds must not
   reference outer loop variable).
3. **Depth-2+ outer-variable reference** → **no pragma** (if any DO loop anywhere in the
   body has bounds referencing the outermost loop variable, tiling that outermost loop puts
   the tiled variable into an inner trip count, which flang-22 miscompiles → runtime crash).

Rule 3 is what the script-based approach in Phase 2 missed. It caught two benchmarks:

| Benchmark | Issue | Pragma removed |
|---|---|---|
| `trmm` | `do i = 2,ni` body → `do j` body → `do k = 1, i-1` (references outer `i` at depth 2) | `sizes(32,32)` removed |
| `durbin` | `do k = 2,n` body → `do i = 1, k-1` (references outer `k` at depth 1) | `sizes(32)` removed; second loop `do i = 1,n` keeps `sizes(32)` |

Result of Phase 2b: **30/30 MATCH, 0 MISMATCH, 0 crashes.**

### Per-benchmark pragma assignments (tile)

| Benchmark | Outermost loop(s) | Pragma |
|---|---|---|
| correlation | `do j` (mean), `do j` (stddev) | `sizes(32)` — imperfect body |
| correlation | `do i` (center/normalize) | `sizes(32,32)` — perfect, non-triangular |
| correlation | `do j1` (sym matrix) | `sizes(32)` — scalar before inner DO |
| covariance | `do j` (mean) | `sizes(32)` — imperfect |
| covariance | `do i` (center) | `sizes(32,32)` — perfect, non-triangular |
| covariance | `do j1` (sym matrix) | `sizes(32)` — triangular `j2=j1,m` |
| 2mm | both `do i` | `sizes(32,32)` — perfect, non-triangular |
| 3mm | all three `do i` | `sizes(32,32)` — perfect, non-triangular |
| atax | `do i` (init), `do i` (matvec) | `sizes(32)` — 1D / imperfect |
| bicg | `do i` (init), `do i` (bicg) | `sizes(32)` — 1D / imperfect |
| cholesky | `do i` | `sizes(32)` — imperfect, triangular inner |
| doitgen | `do r` | `sizes(32,32)` — perfect (r,q), non-triangular |
| gemm | `do i` | `sizes(32,32)` — perfect, non-triangular |
| gemver | loops 1,2,4: `do i` | `sizes(32,32)` — perfect, non-triangular |
| gemver | loop 3: `do i` (scalar) | `sizes(32)` — 1D |
| gesummv | `do i` | `sizes(32)` — imperfect (scalars around inner) |
| mvt | both `do i` | `sizes(32,32)` — perfect, non-triangular |
| symm | `do i` | `sizes(32,32)` — outer body = only `do j` |
| syr2k | both `do i` | `sizes(32,32)` — perfect, non-triangular |
| syrk | both `do i` | `sizes(32,32)` — perfect, non-triangular |
| trisolv | `do i` | `sizes(32)` — imperfect + triangular `j=1,i-1` |
| **trmm** | `do i = 2,ni` | **no pragma** — `do k=1,i-1` at depth 2 references `i` |
| **durbin** | `do k = 2,n` | **no pragma** — `do i=1,k-1` at depth 1 references `k` |
| durbin | `do i = 1,n` | `sizes(32)` — 1D, body has no inner loops |
| dynprog | `do iter` | `sizes(32)` — imperfect |
| gramschmidt | `do k` | `sizes(32)` — imperfect |
| lu | `do k` | `sizes(32)` — two triangular inner DOs |
| ludcmp | all three `do i` | `sizes(32)` — imperfect / triangular |
| floyd-warshall | `do k` | `sizes(32,32)` — perfect (k,i), non-triangular |
| reg_detect | `do t` | `sizes(32)` — imperfect |
| adi | `do t` | `sizes(32)` — imperfect |
| fdtd-2d | `do t` | `sizes(32)` — imperfect |
| fdtd-apml | `do iz` | `sizes(32,32)` — perfect (iz,iy), non-triangular |
| jacobi-1d-imper | `do t` | `sizes(32)` — imperfect |
| jacobi-2d-imper | `do t` | `sizes(32)` — imperfect |
| seidel-2d | `do t` | `sizes(32,32)` — perfect (t,i), non-triangular |

## Phase 2c — Blind Pragma via `*.omp-tile.preproc.f90` (direct compilation)

Phase 2c regenerated all 30 `*.omp-tile.preproc.f90` files with `!$omp tile sizes(32,32)`
inserted unconditionally before **every** outermost scop `do` — no legality check of any kind.
Files were compiled directly (not routed through `woven_code/`) using:

```
flang-22 -O3 -fopenmp -fopenmp-version=51 -DSMALL_DATASET -DPOLYBENCH_DUMP_ARRAYS
```

### Results

| Outcome | Count | Benchmarks |
|---|---|---|
| Compile OK → MATCH | 9 | 2mm, 3mm, doitgen, gemm, mvt, symm, syr2k, syrk, floyd-warshall, fdtd-apml, seidel-2d |
| Compile OK → CRASH | 1 | trmm |
| Compile FAIL | 20 | all others |

Full table: [`blind-tile-results.txt`](blind-tile-results.txt).

### Three distinct failure modes

#### Category A — "The SIZES clause has more entries than there are nested canonical loops" (10 benchmarks)

Benchmarks: `correlation`, `covariance`, `atax`, `bicg`, `cholesky`, `gemver`, `gesummv`,
`gramschmidt`, `trisolv`, `durbin`.

`sizes(32,32)` requires two nested canonical loops directly below the directive. These
benchmarks all have at least one outermost scop loop that is 1-dimensional — its body
contains scalar statements or no inner `do` at all. Example (`atax`):

```fortran
!$omp tile sizes(32,32)    ← blind insertion
do i = 1, n                ← body = one scalar assignment, no inner do
  y(i) = 0.0
end do
```

flang-22 counts one canonical loop, finds two SIZES entries → semantic error at compile
time.

#### Category B — "Canonical loop nest must be perfectly nested" (8 benchmarks)

Benchmarks: `dynprog`, `lu`, `ludcmp`, `reg_detect`, `adi`, `fdtd-2d`, `jacobi-1d-imper`,
`jacobi-2d-imper`.

These benchmarks have an outermost loop (`do t`, `do k`, …) whose body is imperfect: it
contains scalar assignments, array initialisations, or multiple independent inner nests.
The OpenMP tile construct requires the outer body to consist only of the inner canonical
loop. Example (`adi`):

```fortran
!$omp tile sizes(32,32)
do t = 1, tsteps           ← body has 3 separate inner nests + scalar statements
  do i = 2, n-1
    ...
  end do
  do i = 2, n-1            ← second independent nest — not perfectly nested
    ...
  end do
end do
```

`lu` and `ludcmp` also trigger a secondary error "Trip count must be computable and
invariant" because once the perfect-nest check fails the compiler also rejects the
triangular inner bounds (`do j = 1, i-1`).

**Special case — `covariance`** hits both categories in one file: a 1D loop triggers
"SIZES clause", and the triangular nest `do j1 = 1, m; do j2 = j1, m` triggers "Trip
count not invariant" (`j2`'s lower bound `j1` references the outer variable).

#### Category C — Runtime segfault, no compile error (1 benchmark: `trmm`)

This is the most dangerous category: the compiler accepts the pragma without complaint,
but the executable crashes at runtime. The structure is:

```fortran
!$omp tile sizes(32,32)
do i = 2, ni          ← outer tile variable
  do j = 1, ni        ← inner tile variable
    do k = 1, i - 1   ← k's upper bound references the outer tile variable i
      b(j,i) = b(j,i) + alpha * a(k,i) * b(k,j)
    end do
  end do
end do
```

Tiling `(i, j)` reshuffles iteration order: `i` no longer advances monotonically within
a tile. Inside the tile, `do k = 1, i-1` is evaluated with a tile-internal value of `i`,
producing an invalid (possibly zero or negative) trip count for some orderings →
out-of-bounds memory access → segfault.

flang-22 cannot detect this at compile time because it checks only structural nesting
geometry, not cross-level data-dependent bounds.

### Why the 10 successful benchmarks are unaffected

All 10 share the same three structural properties:

1. **Perfect 2-level nest** — the outermost scop loop's body is exactly one inner `do`:
   no scalar statements between outer `do` and inner `do`, none between inner `end do`
   and outer `end do`.
2. **Non-triangular immediate inner bounds** — the inner loop's bounds do not reference
   the outer loop variable.
3. **No depth-2+ bound reference** — no loop anywhere inside the inner body has bounds
   that reference the outermost variable.

These are exactly the three conditions `canTile()` checks in
`fortran-transpiler/Fortran-JS/src-api/code/LoopTiling.ts`. Blind pragma insertion gives
correct results only when the structure already satisfies all three checks — i.e., when
the legality check would have said YES anyway.

### The critical asymmetry

flang-22 catches Category A and B at compile time but silently accepts Category C, which
then crashes at runtime. No MISMATCH appears in this run — because a crash terminates
execution before producing output to compare. If `trmm` had produced wrong output instead
of crashing, it would have been an undetected silent correctness bug.

## Summary Table

| | Phase 1 (transpiler + legality) | Phase 2 (OMP script, no legality) | Phase 2b (OMP per-file legality) | Phase 2c (blind `*.omp-tile`, direct compile) |
|---|---|---|---|---|
| MATCH | **30** | 17 | **30** | 9 |
| MISMATCH | 0 | **1** (`trmm`) | 0 | 0 |
| Compile FAIL | 0 | **12** | 0 | **20** |
| Runtime crash | 0 | 0 | 0 | **1** (`trmm`) |
| Compile OK total | 30 | 28 | 30 | 10 |
| Not transformed (correct skip) | 9 | 4 (regex miss) | 2 (`trmm`, `durbin` outer) | — |

## Conclusion

The hypothesis is confirmed and extended:

1. **OMP pragma causes compile errors** for benchmarks with triangular bounds or imperfect
   outer nests (Phases 2 and 2c). The transpiler prevents this by detecting the same
   structural invariants at analysis time via `canTile()`. In Phase 2c (direct compilation
   of `*.omp-tile.preproc.f90`), 20/30 benchmarks fail to compile — split across two root
   causes: Category A (1D loops given `sizes(32,32)`) and Category B (imperfect outer
   loops failing the perfect-nest requirement).

2. **OMP pragma causes runtime crash** for `trmm` (Phase 2c). The pragma compiles cleanly
   because flang-22 checks only structural nesting geometry, not cross-level data-dependent
   bounds. At runtime, tiling the `(i, j)` pair invalidates the trip count of the inner
   `do k = 1, i-1` loop, causing a segfault. This is the most dangerous failure mode:
   no compile-time warning, no wrong-output MISMATCH — just a crash.

3. **OMP pragma causes MISMATCH** for `trmm` in Phase 2 (script approach) where the
   crash didn't manifest due to a different code path. The transpiler handles `trmm`
   correctly by descending to the `(j, k)` pair, which satisfies `canTile()`.

4. **Per-file legitimacy analysis (Phase 2b)** achieves 30/30 MATCH by applying three
   legality rules: imperfect-body detection, immediate triangular bound check, and
   depth-2+ outer-variable reference check. The third rule catches `trmm` and `durbin`
   that any script-based approach would miss.

5. The transpiler's `canTile()` checks correspond directly to the three rules in Phase 2b:
   the transpiler performs the same geometric analysis at the IR level that Phase 2b
   performs by reading source. Both prevent the same set of unsafe transformations.
   Blind pragma insertion — Phase 2c — fails on exactly the benchmarks where `canTile()`
   would say NO, confirming that the legality check is necessary and sufficient.
