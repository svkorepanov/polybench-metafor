# Interchange Legality Analysis — Identifying Transformable Loops

Loop interchange swaps the outer and inner loop of a 2-deep perfect nest,
keeping the body unchanged. It is only correct when the inner loop's bounds
do not reference the outer variable, and when no data dependency in the body
relies on the outer-first execution order. Two distinct patterns cause failures
in PolyBench.

---

## Check 1 — Triangular inner bound references outer variable

### What goes wrong

The inner loop's lower or upper bound is an expression involving the outer loop
variable. After interchange, that expression is literally copied into the new
outer loop's bound — but the variable it references is now the inner variable,
which is out of scope at the outer bound position. The runtime reads garbage from
the stack, producing wrong output or a segfault.

### Example A: garbage bound (`reg_detect`)

```fortran
! Original:
do j = 1, maxgrid
  do i = j, maxgrid   ! inner lower bound = j (outer variable)
    do cnt = 1, length
      diff(cnt, i, j) = sumTang(i, j)
    end do
  end do
end do

! After interchange (wrong):
do i = j, maxgrid     ! j is undefined here — reads garbage from stack
  do j = 1, maxgrid
    do cnt = 1, length
      diff(cnt, i, j) = sumTang(i, j)
    end do
  end do
end do
```

The outer loop now has `i = j, maxgrid` where `j` is no longer a defined variable
at that scope. The loop runs an undefined number of times with wrong bounds.
Result: wrong output; "1516× speedup" artifact (the corrupted loop terminates
almost instantly with meaningless work done).

### Example B: segfault (`covariance`)

```fortran
! Original:
do j1 = 1, m
  do j2 = j1, m    ! inner lower bound = j1 (outer variable)
    symmat(j2, j1) = 0.0D0
    do i = 1, n
      symmat(j2, j1) = symmat(j2, j1) + dat(j1, i) * dat(j2, i)
    end do
    symmat(j1, j2) = symmat(j2, j1)
  end do
end do

! After interchange (wrong):
do j2 = j1, m     ! j1 is undefined — garbage value used as lower bound
  do j1 = 1, m
    ...
  end do
end do
```

`j1` is uninitialized when used as `j2`'s lower bound. The garbage value causes
an out-of-bounds array access inside the loop body, producing a segfault.

### AST signal

The inner loop control string (`ic.code`) contains the name of the outer loop
variable. This is a direct syntactic check — no data flow analysis required.

### Detection rule

> Let `v_outer` = the outer loop variable name, `ic` = the inner loop control.
> If `ic.lower.code` or `ic.upper.code` contains the string `v_outer`
> → **Reject interchange.**

---

## Check 2 — Outer variable appears in a nested loop bound inside the body

### What goes wrong

The outer and inner loop bounds are rectangular (neither references the other
variable). However, the body contains a third nested loop whose bounds use the
outer variable. After interchange, this nested loop still compiles correctly
because it now uses what was the outer variable (now inner), but the change in
evaluation order causes previously-unmodified array values to be read as already-
modified, producing wrong results.

### Example (`trmm`)

```fortran
! Original — (i outer, j inner):
do i = 2, ni           ! outer — rectangular bound, no ref to j
  do j = 1, ni         ! inner — rectangular bound, no ref to i
    do k = 1, i - 1    ! k-loop bound uses outer variable i
      b(j, i) = b(j, i) + alpha * a(k, i) * b(k, j)
    end do             ! writes b(j,i), reads b(k,j)
  end do
end do

! After interchange — (j outer, i inner):
do j = 1, ni           ! outer (was inner)
  do i = 2, ni         ! inner (was outer)
    do k = 1, i - 1    ! still syntactically valid: i is now inner
      b(j, i) = b(j, i) + alpha * a(k, i) * b(k, j)
    end do
  end do
end do
```

This compiles and runs without error. The result is numerically wrong.

**Why**: in the original, at outer iteration `i=2`, the k-loop reads `b(k=1, j)`
for every j. At that point `b(1, j)` has its INITIAL value — no outer iteration
has modified it yet (outer iterations start at i=2, and `b(j, i)` is written to
position `(j, 2)`, not `(1, j)`).

After interchange, `j=1` runs all its inner `i` values first. During `(j=1, i=3)`,
the body writes `b(j=1, i=3)` = `b[1][3]` after reading `b(k=1,j=1)` and
`b(k=2,j=1)`. When `j=3` later runs at `i=2`, the k-loop reads `b(k=1, j=3)` =
`b[1][3]` — but this was already modified during `j=1`'s iteration. In the
original, the same read at `(i=2, j=3)` saw the INITIAL `b[1][3]` because i=3
hadn't run yet.

```
Original read/write timeline for b[1][3]:
  (i=2, j=3, k=1): READ  b[1][3]  ← initial value
  (i=3, j=1, k=1): WRITE b[1][3]  ← modified later

After interchange:
  (j=1, i=3, k=1): WRITE b[1][3]  ← modified first
  (j=3, i=2, k=1): READ  b[1][3]  ← reads modified value — WRONG
```

The interchange reversed a read-before-write into a write-before-read.

### AST signal

- The outer and inner loop bounds are **rectangular** (no triangular reference
  to each other — Check 1 does not apply).
- The loop **body contains a nested DO loop** whose bound expression includes
  the outer loop variable name (e.g., `do k = 1, i - 1` where `i` is the outer
  variable being moved to inner position).
- The body **writes** an array at subscript `(inner_var, outer_var)` and
  **reads** the same array at subscript `(k_var, inner_var)` — the write's
  first subscript matches the read's second subscript, creating a cross-iteration
  aliasing pattern whose correctness depends on outer-first evaluation order.

### Detection rule

> Let `v_outer` = outer loop variable, `v_inner` = inner loop variable.
> If the body contains a nested DO loop with a bound expression that includes
> `v_outer` (i.e., the nested loop is triangular relative to the original outer)
> → **Reject interchange.**
>
> Alternatively (more precise): if the body writes `X(v_inner, v_outer)` and
> reads `X(*, v_inner)` where the same array is accessed with subscript roles
> swapped between write and read, and the body also has a triangular sub-loop
> on `v_outer` → **Reject interchange.**

---

## Summary

| Check | Pattern | Benchmarks | Key signal |
|---|---|---|---|
| 1 | Triangular inner bound — outer var in `ic.lower` or `ic.upper` | `reg_detect`, `covariance` | `ic.code` contains `v_outer` name |
| 2 | Body contains nested loop with outer-var bound | `trmm` | Descendant `DoStatement` whose bound expression contains `v_outer` |

---

## How to detect in the AST

Both checks need only:

1. **Outer variable name** — `(outer.control as RangeLoopControl).var.name`

2. **Inner control expressions** — `(inner.control as RangeLoopControl).lower.code`
   and `.upper.code`; check if either string contains the outer variable name.
   This covers **Check 1** with a single `includes()` call.

3. **Nested loop bounds scan** — `Query.searchFrom(inner.body, DoStatement)`;
   for each found loop, inspect its `.control.lower.code` and `.control.upper.code`
   for the outer variable name. A match means the body has a triangular sub-loop
   that depends on the outer variable's value — **Check 2**.

No subscript analysis or dependence solver is required. Both checks are purely
syntactic: look for a variable name in bound expression strings. The LARA AST
exposes these as `.code` strings on `RangeLoopControl` nodes.

### Minimal implementation sketch

```typescript
function canInterchange(outer: DoStatement, inner: DoStatement): boolean {
  const outerVar = (outer.control as RangeLoopControl).var.name;
  const ic = inner.control as RangeLoopControl;

  // Check 1: triangular inner bounds
  if (ic.lower.code.includes(outerVar) || ic.upper.code.includes(outerVar)) {
    return false;
  }

  // Check 2: nested loop inside body uses outer variable in its bounds
  for (const nested of Query.searchFrom(inner.body, DoStatement)) {
    const nc = nested.control as RangeLoopControl;
    if (nc.lower.code.includes(outerVar) || nc.upper.code.includes(outerVar)) {
      return false;
    }
  }

  return true;
}
```
