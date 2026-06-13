# Iteration 3: Loop Fission — SMALL_DATASET

## Status: RESOLVED — 30/30 MATCH

| Parameter | Value |
|---|---|
| Transform | `fissionGeneric.ts` → `LoopFissionPass()` |
| Dataset | SMALL_DATASET |
| Date | 2026-06-13 |
| Transpiler commit | TBD (this iteration) |

## Result

| Category | Count | Benchmarks |
|---|---|---|
| FISSIONED + MATCH | 10 | 2mm, 3mm, atax, bicg, correlation, doitgen, dynprog, gesummv, reg_detect, symm |
| SKIPPED + MATCH | 20 | all others |
| MISMATCH | 0 | — |

Previously 9 benchmarks were MISMATCH (adi, cholesky, fdtd-2d, fdtd-apml, gramschmidt,
lu, ludcmp, symm, trisolv). All are now MATCH.

## Root bug fixed

The original helper functions (`stmtArrayWrites`, `stmtArrayReads`, `stmtScalarWrites`)
used `Query.searchFrom(stmt, AssignmentStatement)` — which searches only the **children**
of `stmt`, not `stmt` itself. When a body statement is a direct `AssignmentStatement`
(not a nested loop), `searchFrom` found nothing and the helpers returned empty sets,
letting all checks pass silently.

Fix: use `Query.searchFromInclusive(stmt, AssignmentStatement)` in all three helpers.
This includes the node itself in the search, so direct assignment statements are found.

## The two checks in `canFission`

### Check 1 — Scalar temporary threading

Catches: **`gramschmidt`** (`nrm`), **`cholesky`** (`x`), **`symm`** inner acc-init,
**`ludcmp`** (`w`)

A scalar variable is written in one statement and consumed in a later one. After fission,
all iterations of the "producer" loop complete before any iteration of the "consumer"
loop begins — the scalar holds only the producer's last-iteration value, so every
consumer iteration reads the wrong value.

**Example — `gramschmidt` outer `k`-loop (3 stmts):**

```fortran
! Original — nrm is computed fresh each k-iteration:
do k = 1, nj
  nrm = 0.0D0                           ! S1: init
  do i = 1, ni
    nrm = nrm + a(k, i) * a(k, i)       ! S2: accumulate
  end do
  r(k, k) = sqrt(nrm)                   ! S3: consume ← depends on S1+S2
end do

! After fission (WRONG):
do k = 1, nj; nrm = 0.0D0; end do           ! loop 1
do k = 1, nj; do i; nrm = nrm + ...; end; end ! loop 2 — nrm ends at k=nj value
do k = 1, nj; r(k,k) = sqrt(nrm); end do   ! loop 3 — every k reads same stale nrm
```

Detection: S1 writes scalar `nrm`; word-boundary regex finds `nrm` in S2's and S3's
code → reject.

---

### Check 2 — Later stmt writes array that earlier stmt reads

Catches: **`trisolv`**, **`lu`**, **`ludcmp`**, **`adi`**, **`fdtd-2d`**, **`fdtd-apml`**

After fission, the "earlier" loop runs for ALL iterations before the "later" loop runs
for ANY iteration. If the earlier stmt reads array `X` and the later stmt writes `X`,
the earlier loop at iteration `i+1` reads the stale value that the later loop at
iteration `i` should have updated.

**Example — `fdtd-2d` outer `t`-loop (4 sub-loop stmts):**

```fortran
! Original — each sub-step feeds the next within the same t:
do t = 1, tmax
  do j = 1, ny; ey(j, 1) = fict(t); end do                     ! S1: boundary
  do i = 2, nx; do j; ey(j,i) -= 0.5*(hz(j,i)-hz(j-1,i)); end; end  ! S2: reads hz
  do i; do j = 2, ny; ex(j,i) -= 0.5*(hz(j,i)-hz(j,i-1)); end; end  ! S3: reads hz
  do i; do j; hz(j,i) -= 0.7*(ex(j+1,i)+ey(j,i+1)-...); end; end    ! S4: writes hz
end do

! After fission (WRONG):
do t; [S1]; end do   ! loop 1
do t; [S2]; end do   ! loop 2 — at t=2 reads hz(t=1), but loop 4 hasn't run yet
do t; [S3]; end do   ! loop 3
do t; [S4]; end do   ! loop 4 — hz written here, too late for loops 2-3
```

Detection: S4 (index 3) writes `hz`; S2 (index 1) reads `hz` → reject.

**Example — `trisolv` outer `i`-loop (3 stmts):**

```fortran
! Original — forward substitution; x(j<i) already finalised by the time i reads it:
do i = 1, n
  x(i) = c(i)                              ! S1: init
  do j = 1, i-1; x(i) -= a(j,i)*x(j); end do  ! S2: reads x(j), j<i
  x(i) = x(i) / a(i, i)                   ! S3: writes x(i) ← x(1) finalised here
end do

! After fission (WRONG):
do i; x(i) = c(i); end do                    ! loop 1
do i; do j=1,i-1; x(i)-=a(j,i)*x(j); end; end ! loop 2 — x(1) still = c(1),
                                               !   should be c(1)/a(1,1) from loop 3
do i; x(i) = x(i)/a(i,i); end do            ! loop 3 — too late
```

Detection: S3 (index 2) writes `x`; S2 (index 1) reads `x` → reject.

## symm: safe k-loop fission

`symm` shows FISSIONED despite being a previously-failing benchmark. The fission
happens at the **inner k-loop** (not the j-loop that was causing failures):

```fortran
! k-loop body — 2 independent statements:
do k = 1, j - 1
  c(j, k) = c(j, k) + alpha * a(i, k) * b(j, i)   ! S_c: writes c(j,k)
  acc = acc + b(j, k) * a(i, k)                    ! S_acc: writes acc
end do
```

Neither statement depends on the other: S_acc doesn't read `c`, and S_c doesn't
read `acc`. Both checks pass, so the k-loop is safely split. The surrounding j-loop
is then checked with 4 body stmts (S1=`acc=0`, k-loop1, k-loop2, S3=`c(j,i)=...`)
and correctly **blocked** by Check 1: S1 writes scalar `acc` which appears in
k-loop2's code.

## Raw results

See `fission-results.txt` in this folder.
