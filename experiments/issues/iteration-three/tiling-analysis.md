# Iteration 3: Loop Tiling

## Status: RESOLVED — 30/30 MATCH

| Parameter | Value |
|---|---|
| Transform | `tilingGeneric.ts` → `LoopTilingPass(32)` |
| Dataset | SMALL_DATASET |
| Date | 2026-06-13 |
| Transpiler commit | `278dad3` |

`canTile()` in `src-api/code/LoopTiling.ts` was extended with two legality checks
mirroring `canInterchange()`, using word-boundary regex (`\b`) to avoid false
positives from dimension names like `ni` containing the variable name `i`.

---

## Issue 1: `reg_detect` — Triangular inner bound

### Pattern

The inner loop's lower bound depends on the outer loop variable. Tiling the outer
pair `(j, i)` discards that dependency: the tile replaces the inner start with the
tile-strip origin `ii`, but the original constraint `i >= j` is no longer enforced.

### Original code (scop, simplified to one nest)

```fortran
do j = 1, maxgrid
  do i = j, maxgrid        ! triangular: i starts at j, not 1
    do cnt = 1, length
      diff(cnt, i, j) = sumTang(i, j)
    end do
  end do
end do
```

### After tiling (actual transpiler output)

```fortran
DO jj = 1, maxgrid, 32
DO ii = j, maxgrid, 32     ! BUG 1: `j` is the inner tile variable — not yet defined here
DO j = jj, MIN(jj + 32 - 1, maxgrid)
DO i = ii, MIN(ii + 32 - 1, maxgrid)   ! BUG 2: should start at MAX(ii, j), not ii
DO cnt = 1, length
  diff(cnt, i, j) = sumtang(i, j)
END DO
END DO
END DO
END DO
END DO
```

Two bugs introduced simultaneously:

1. `DO ii = j, maxgrid, 32` — The strip-mine start for the inner tile uses `j`, which
   is the *same variable name* that the inner tile loop `DO j = jj, ...` defines later.
   At the point where `DO ii` is evaluated, `j` is an uninitialized or out-of-scope
   integer (whatever it holds from before the scop), not the current outer iteration.

2. `DO i = ii, MIN(ii+31, maxgrid)` — Even if `ii` were correctly derived, the inner
   tile starts at `ii` rather than `MAX(ii, j)`, so it visits elements where `i < j`,
   which the original loop excluded.

### Legality check needed

> Reject tiling of `(outer, inner)` if the lower or upper bound of the inner loop
> contains the outer loop variable name (triangular / data-dependent bounds).

---

## Issue 2: `trmm` — Nested loop in body references outer variable

### Pattern

A third loop nested in the body has a bound that depends on the outer tiled variable.
Tiling reorders `(i, j)` tile pairs, so `j` values from a later tile (larger `jj`) can
be processed before the matching `i` values are ready — producing reads of
partially-accumulated array elements.

### Original code (full scop)

```fortran
do i = 2, ni
  do j = 1, ni
    do k = 1, i - 1          ! k-bound references outer variable i
      b(j, i) = b(j, i) + alpha * a(k, i) * b(k, j)
    end do                    ! reads b(k, j): needs (i=j, j=k) to have run first
  end do
end do
```

`b(k, j)` at row `k`, column `j` is *written* at iteration `(i=j, j=k)`, i.e. when
the outer loop reaches `i = j`. So for any read at `(i, j, k)` with `k < i`, the
value `b(k, j)` is valid only after outer iteration `i = j` has completed.

### After tiling (actual transpiler output)

```fortran
DO ii = 2, ni, 32
DO jj = 1, ni, 32
DO i = ii, MIN(ii + 32 - 1, ni)
DO j = jj, MIN(jj + 32 - 1, ni)
DO k = 1, i - 1
  b(j, i) = b(j, i) + (alpha * a(k, i) * b(k, j))
END DO
END DO
END DO
END DO
END DO
```

### Concrete violation (tile size = 32, ni ≥ 64)

| Tile | `(ii=2, jj=33)` |
|---|---|
| Writes | `b(j, i)` for `j=33..64`, `i=2..32` (column `i`, row `j`) |
| Reads | `b(k, j)` for `j=33..64`, `k=1..31` |

`b(k, j)` at column `j=33..64` is written at original iteration `(i=j, j=k)`.
Since `j` is in `33..64`, those writes happen in tile `(ii=33..64, jj=k)` — which
the tiled loop processes **after** tile `(ii=2, jj=33)`. So the read in tile
`(ii=2, jj=33)` observes uninitialized values.

In the original sequential order this can never happen: `i=j` (33..64) always comes
after the current `i` (2..32), so by the time we read `b(k, j)`, `i` has not yet
reached `j` — meaning those writes haven't happened either. The result is that the
original algorithm reads the *initial* `b(k, j)` (the input), which is correct for a
triangular BLAS-3 update. Tiling destroys this by mixing j-ranges across i-stripes.

### Legality check needed

> Reject tiling of `(outer, inner)` if any descendant loop inside the body has a
> bound expression that contains the outer loop variable name.

---

## Resolution

Both checks mirror what `canInterchange()` already enforces in `LoopInterchange.ts`.
`canTile()` in `src-api/code/LoopTiling.ts` was extended with the same two tests,
using word-boundary regex (`\b`) instead of plain `.includes()` to avoid false
positives where a dimension variable like `ni` contains the loop variable name `i`
as a substring:

```typescript
function containsVar(code: string, varName: string): boolean {
  return new RegExp(`\\b${varName}\\b`).test(code);
}

export function canTile(outer: DoStatement, inner: DoStatement): boolean {
  const oc = outer.control, ic = inner.control;
  if (!(oc instanceof RangeLoopControl && ic instanceof RangeLoopControl)) return false;
  if (oc.step !== undefined || ic.step !== undefined) return false;

  const outerVar = oc.var.name;

  // Check 1: triangular inner bounds — inner bound references outer variable
  if (containsVar(ic.lower.code, outerVar) || containsVar(ic.upper.code, outerVar)) return false;

  // Check 2: nested DO inside inner body uses outer variable in its bounds
  for (const nested of Query.searchFrom(inner.body, DoStatement)) {
    const nc = nested.control;
    if (!(nc instanceof RangeLoopControl)) continue;
    if (containsVar(nc.lower.code, outerVar) || containsVar(nc.upper.code, outerVar)) return false;
  }

  return true;
}
```

### Actual tiled pairs after fix

| Benchmark | Blocked pair | Tiled instead | Why tiled pair is safe |
|---|---|---|---|
| `reg_detect` | `(j, i)` — triangular (Check 1) | `(i, cnt)` inside the j-loop | outer tile loop inherits `j` as lower bound; `i >= j` preserved |
| `trmm` | `(i, j)` — `do k = 1, i-1` in body (Check 2) | `(j, k)` inside the i-loop | for fixed `i`, k-tile upper bound is `MIN(kk+31, i-1)`, correctly capped |

## Result

| Category | Count | Benchmarks |
|---|---|---|
| MATCH | 30 | all |
| MISMATCH | 0 | — |

Tiled benchmarks (21): same set as iteration 2 (21 YES), now including `reg_detect`
and `trmm` via alternative safe pairs, and still including `syrk` (word-boundary
fix avoids the `\bni\b` false positive that blocked it under plain `.includes()`).

## Raw results

See `tiling-results.txt` in this folder.
