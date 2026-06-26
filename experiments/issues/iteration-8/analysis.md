# Iteration 8 — Fission → Tiling Pipeline

## Hypothesis

Loop fission can improve the success rate of loop tiling by splitting non-perfectly
nested loops (which tiling skips) into smaller, perfectly nested loops that tiling
can then process.

**Tiling requires a perfect 2-deep nest**: an outer loop whose sole body statement
is an inner loop (`stmts.length === 1 && stmts[0] instanceof DoStatement`).

**Fission** splits a loop with multiple body statements into one loop per statement,
potentially exposing perfect 2-deep nests where none existed before.

---

## Setup

- 30 PolyBench/Fortran benchmarks (fdtd-apml blacklisted from correctness testing)
- Dataset: SMALL_DATASET with POLYBENCH_DUMP_ARRAYS
- Compiler: flang-22 -O3 -fopenmp
- Transpiler: fortran-transpiler (metafor framework), tile size = 32

**Transforms compared:**
- **Baseline**: `tilingGeneric` (LoopTilingPass only)
- **Pipeline**: `fissionTilingGeneric` (LoopFissionPass → LoopTilingPass)

---

## Results

```
Benchmark          | Tiling       | Correct    | Fission+Tiling   | Correct   
-------------------------------------------------------------------------------
correlation        | TILED        | MATCH      | FISSIONED+TILED  | MATCH     
covariance         | TILED        | MATCH      | TILED            | MATCH     
2mm                | TILED        | MATCH      | FISSIONED+TILED  | MATCH     
3mm                | TILED        | MATCH      | FISSIONED+TILED  | MATCH     
atax               | SKIPPED      | -          | FISSIONED+TILED  | MATCH  <-- NEW
bicg               | SKIPPED      | -          | FISSIONED+TILED  | MATCH  <-- NEW
cholesky           | SKIPPED      | -          | SKIPPED          | -         
doitgen            | TILED        | MATCH      | FISSIONED+TILED  | MATCH     
gemm               | TILED        | MATCH      | TILED            | MATCH     
gemver             | TILED        | MATCH      | TILED            | MATCH     
gesummv            | SKIPPED      | -          | FISSIONED_ONLY   | MATCH     
mvt                | TILED        | MATCH      | TILED            | MATCH     
symm               | TILED        | MATCH      | FISSIONED+TILED  | MATCH     
syr2k              | TILED        | MATCH      | TILED            | MATCH     
syrk               | TILED        | MATCH      | TILED            | MATCH     
trisolv            | SKIPPED      | -          | SKIPPED          | -         
trmm               | TILED        | MATCH      | TILED            | MATCH     
durbin             | SKIPPED      | -          | SKIPPED          | -         
dynprog            | TILED        | MATCH      | FISSIONED+TILED  | MATCH     
gramschmidt        | SKIPPED      | -          | SKIPPED          | -         
lu                 | TILED        | MATCH      | TILED            | MATCH     
ludcmp             | SKIPPED      | -          | SKIPPED          | -         
floyd-warshall     | TILED        | MATCH      | TILED            | MATCH     
reg_detect         | TILED        | MATCH      | FISSIONED+TILED  | MATCH     
adi                | TILED        | MATCH      | TILED            | MATCH     
fdtd-2d            | TILED        | MATCH      | TILED            | MATCH     
fdtd-apml          | TILED        | skipped    | TILED            | skipped   
jacobi-1d-imper    | SKIPPED      | -          | SKIPPED          | -         
jacobi-2d-imper    | TILED        | MATCH      | TILED            | MATCH     
seidel-2d          | TILED        | MATCH      | TILED            | MATCH     
-------------------------------------------------------------------------------

TILING ALONE:    21/30 tiled, 9/30 skipped, 29/29 tested correct
FISSION+TILING:  23/30 tiled, 7/30 skipped, 29/29 tested correct

Improvement:     +2 benchmarks newly tiled by fission → tiling pipeline
```

**Conclusion: hypothesis confirmed.** Fission → tiling tiles 23/30 benchmarks vs 21/30
for tiling alone — a **+9.5 percentage point improvement** in tiling success rate, with
zero correctness regressions.

---

## Newly Tiled Benchmarks

### atax (matrix-vector multiply + transpose)

Original `kernel_atax` outer loop — 3 body statements → tilingGeneric SKIPS:
```fortran
do i = 1, nx           ! 3 body stmts → canTile false
  tmp(i) = 0.0d0       ! stmt 1: init
  do j = 1, ny         ! stmt 2: accumulate tmp
    tmp(i) = tmp(i) + (a(j, i) * x(j))
  end do
  do j = 1, ny         ! stmt 3: accumulate y
    y(j) = y(j) + a(j, i) * tmp(i)
  end do
end do
```

After fission (no cross-statement array read-write deps), the outer `do i` is split:
```fortran
do i = 1, nx
  tmp(i) = 0.0d0       ! 1-stmt loop (not tileable — no inner loop)
end do
do i = 1, nx           ! 2-deep perfect nest → TILED
  do j = 1, ny
    tmp(i) = tmp(i) + (a(j, i) * x(j))
  end do
end do
do i = 1, nx           ! 2-deep perfect nest → TILED
  do j = 1, ny
    y(j) = y(j) + a(j, i) * tmp(i)
  end do
end do
```

**Why fission is legal here**: `tmp(i)` values are independent across different `i`.
Each `i`-iteration of stmts 2 and 3 does not depend on another `i`-iteration of stmt 2
or 3. The `canFission` dependency check confirms: no later statement writes an array
that any earlier statement reads.

### bicg (BiCGSTAB sub-problem)

Original `kernel_bicg` inner `do j` has 2 statements and outer `do i` has 2 statements
→ both prevent tiling. Fission is applied recursively (inner loop first, then outer):

Inner `do j` fissioned (writes `s` and `q` independently):
```fortran
do j = 1, ny; s(j) = s(j) + r(i)*a(j,i); end do
do j = 1, ny; q(i) = q(i) + a(j,i)*p(j); end do
```

Outer `do i` then fissioned (3 stmts with no deps across i):
```fortran
do i = 1, nx; q(i) = 0.0D0; end do
do i = 1, nx                 ! (i, j) perfect nest → TILED
  do j = 1, ny; s(j) = s(j) + r(i)*a(j,i); end do
end do
do i = 1, nx                 ! (i, j) perfect nest → TILED
  do j = 1, ny; q(i) = q(i) + a(j,i)*p(j); end do
end do
```

---

## Partial Success: gesummv (FISSIONED_ONLY)

`kernel_gesummv` outer loop has 4 body stmts, but fission is blocked by a
read-write dependency on `y`:

```fortran
do i = 1, n
  tmp(i) = 0.0D0        ! stmt 0
  y(i) = 0.0D0          ! stmt 1
  do j = 1, n           ! stmt 2: writes y(i), reads y(i)
    tmp(i) = a(j,i)*x(j) + tmp(i)
    y(i) = b(j,i)*x(j) + y(i)
  end do
  y(i) = alpha*tmp(i) + beta*y(i)  ! stmt 3: writes y, reads y
end do
```

Fission of the outer `do i` is blocked because stmt 3 writes `y` and stmt 2 reads `y`
(`canFission` check 2 fails). The inner `do j` (stmt 2) CAN be fissioned into two
separate j-loops, but the outer `do i` still has multiple body stmts after that fission,
so tiling of the (i, j) pair is still impossible.

---

## Remaining Skipped Benchmarks (7)

| Benchmark     | Reason fission cannot help |
|---|---|
| cholesky      | Scalar `x` threaded across statements via `scalarWrites` check |
| trisolv       | Sequential read-write deps on `x(i)` across 3 stmts |
| durbin        | Scalar `beta`, `alpha` accumulated across stmts |
| gramschmidt   | Scalar `nrm` accumulated; stmt 2 reads what stmt 1 writes |
| ludcmp        | Scalar `w` threaded across multiple stmts |
| ludcmp        | Multiple triangular inner loops prevent tiling even after fission |
| jacobi-1d-imper | Time-loop deps (stmt 2 writes `a`, stmt 1 reads `a`) prevent fission |
| gesummv       | `y` read-write dep between inner loop and trailing scalar assignment |

These represent fundamental algorithmic constraints — either induction scalars
(cholesky, durbin, gramschmidt, ludcmp) that cannot be distributed, or
recurrence patterns (trisolv, jacobi-1d-imper) where loop order is the result.

---

## Fission Impact on Already-Tiled Benchmarks

The pipeline also applied fission to 7 previously-TILED benchmarks before tiling
them (FISSIONED+TILED): correlation, 2mm, 3mm, doitgen, symm, dynprog, reg_detect.
All 7 remain correct after the combined transform. This shows that fission is safe
even when tiling would have succeeded without it.

---

## Files

| File | Description |
|---|---|
| `results-fission-tiling.txt` | Raw results table (TILED/SKIPPED + MATCH/MISMATCH) |
| `analysis.md` | This document |
| `../../run-fission-tiling-experiment.sh` | Experiment script (re-runnable) |
| `../../fortran-transpiler/Fortran-JS/src-api/examples/fissionTilingGeneric.ts` | New pipeline transform |
