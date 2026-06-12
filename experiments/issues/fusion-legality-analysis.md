# Fusion Legality Analysis — Identifying Transformable Loops

Loop fusion merges two consecutive loops with identical bounds into one.
It is only correct when no statement in the merged body reads a value that
the other loop is still producing. Three dependency patterns cause failures
in PolyBench. Each has a detectable AST signature.

---

## Check A — Reduction not yet complete

### What goes wrong

One loop accumulates a value into an array element over its entire iteration
range. The next loop reads that element. After fusion, the reader sees a
partial (incomplete) accumulation.

### Example (`atax`)

```fortran
! Fusion variable: j
do j = 1, n
  tmp(i) = tmp(i) + a(j,i) * x(j)   ! A: tmp(i) grows with every j
end do
do j = 1, n
  y(j) = y(j) + a(j,i) * tmp(i)     ! B: needs final tmp(i)
end do

! After fusion (wrong):
do j = 1, n
  tmp(i) = tmp(i) + a(j,i) * x(j)   ! partial after j=1
  y(j)   = y(j)   + a(j,i) * tmp(i) ! reads partial tmp(i) — wrong
end do
```

### AST signal

- `tmp` is written inside loop A's body as a running sum (the write is the
  LHS of an assignment of the form `x = x + expr`, i.e. a reduction).
- The subscript of `tmp` contains only the outer loop variable (the variable
  that is fixed across all j iterations), not the fusion variable j itself.
- `tmp` appears in loop B's read set.

### Detection rule

> Array X is written in loop A, read in loop B, AND the write happens inside
> a nested inner loop body (depth > 1 relative to the fusion loop), AND X's
> subscript contains only the outer-scope variable (not the fusion variable).
> → **Reject fusion.**

---

## Check B — Transposed subscript across outer iterations

### What goes wrong

Loop A writes an array at index `(inner, outer)` — filling one column per
outer iteration. Loop B reads the same array at index `(outer, inner)` —
reading one row per outer iteration. A row of the array spans many columns,
which are only written in future outer iterations that haven't run yet.

### Example (`gemver`)

```fortran
! Fusion variable: i
do i = 1, n
  do j = 1, n
    a(j, i) = a(j, i) + u1(i)*v1(j)  ! A: writes column i of a
  end do
end do
do i = 1, n
  do j = 1, n
    x(i) = x(i) + beta * a(i, j)     ! B: reads row i of a
  end do                              !    a(i,2), a(i,3)... not written yet
end do

! After fusion at i=3 (wrong):
do i = 1, n
  do j = 1, n; a(j,i) += ...         ! writes a(*,3) — column 3
  do j = 1, n; x(i) += ... a(i,j)   ! reads a(3,*) — row 3
end do                                ! a(3,1) and a(3,2) still have old values
```

### AST signal

- Array `a` appears in both loop A's write set and loop B's read set.
- In loop A, the write subscript is `a(inner_var, outer_var)` — inner loop
  variable in the first position, outer (fusion) variable in the second.
- In loop B, the read subscript is `a(outer_var, inner_var)` — positions are
  reversed relative to A's write.

### Detection rule

> Array X is written in loop A as `X(w, v)` and read in loop B as `X(v, w)`,
> where `v` is the fusion variable and `w` is an inner loop variable.
> → **Reject fusion.**

---

## Check C — Write-back before all reads are done

### What goes wrong

Loop A reads an array across its full range in an inner loop. Loop B writes
a new value back into the same array at the end of each outer iteration.
After fusion, the write in iteration `p=1` corrupts the array element that
loop A still needs to read in iteration `p=2`.

### Example (`doitgen`)

```fortran
! Fusion variable: p
do p = 1, np
  do s = 1, np
    sumA(p) = sumA(p) + a(s) * cFour(p,s)  ! A: reads a(s) for ALL s
  end do
end do
do p = 1, np
  a(p) = sumA(p)                            ! B: writes a(p) — one element per iter
end do

! After fusion (wrong):
do p = 1, np
  do s = 1, np
    sumA(p) = sumA(p) + a(s) * cFour(p,s)  ! reads a(s=1) at p=2 ...
  end do
  a(p) = sumA(p)                            ! ... but a(1) was overwritten at p=1
end do
```

### AST signal

- Array `a` is written directly in loop B's body (not inside a nested inner
  loop — a scalar write-back, one element per outer iteration).
- The same array is read inside a nested inner loop of loop A (the inner loop
  variable appears in the read subscript, so the read spans a range).
- The write subscript in B and the read subscript in A share the same index
  dimension (both indexed by `p`, the fusion variable).

### Detection rule

> Array X is written in loop B at the outer level (depth = 1, subscript = fusion
> variable only), AND read in loop A inside a nested loop (depth > 1, subscript
> spans the fusion variable range).
> → **Reject fusion.**

---

## Summary

| Check | Pattern | Benchmark | Key signal |
|---|---|---|---|
| A | Reduction result consumed too early | `atax` | Write inside inner loop, subscript = outer var only |
| B | Transposed array access across iterations | `gemver` | Write `X(w,v)` in A, read `X(v,w)` in B |
| C | Write-back before inner loop finishes reading | `doitgen` | Scalar write at outer level in B; ranged read in A's inner loop |

---

## How to detect in the AST

All three checks need only:

1. **Array write/read sets per loop** — traverse `loop.descendants`, find
   `AssignmentStatement` nodes; the LHS `.variable` is the write target, the
   RHS subexpressions are reads. `ArraySubscriptExpr.name` gives the array
   name; `.subscripts` gives the index expressions.

2. **Write depth** — count how many `DoStatement` ancestors separate the write
   site from the fusion loop. Depth 1 = written directly in the fusion loop
   body (Check C pattern). Depth > 1 = written inside a nested loop (Check A
   pattern).

3. **Subscript variable check** — compare the variable names appearing in
   subscript expressions against the fusion loop variable name and inner loop
   variable names. Pure outer-var subscript = Check A trigger. Reversed pair
   of (inner, outer) = Check B trigger.

No symbolic solver is needed. All three checks are syntactic pattern matches on
variable names and loop nesting depth, which the LARA AST exposes directly via
`AssignmentStatement`, `ArraySubscriptExpr`, and `DoStatement` join points.
