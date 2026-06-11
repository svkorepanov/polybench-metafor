# Experiment: Loop Unrolling — factor=4 — SMALL_DATASET (after LoopUnroll.ts fix)

## Setup

| Parameter | Value |
|---|---|
| Transform | `unrollGeneric.ts` → `LoopUnrollPass(4)` |
| Dataset | `SMALL_DATASET` (128×128 for most kernels) |
| Compiler | `flang-22 -O3 -fopenmp` |
| Platform | Linux 6.17.0, x86_64 |
| Date | 2026-06-11 |

## How to reproduce

```bash
# preproc.sh / compile.sh: SMALL_DATASET + POLYBENCH_DUMP_ARRAYS
./preproc.sh
./compile.sh && ./execute.sh          # baseline
find . -type d -name woven_code -exec rm -rf {} +
./weave-transpiler.sh unrollGeneric
./compile.sh && ./execute.sh
./compare.sh
```

## Results summary

| Category | Count | Benchmarks |
|---|---|---|
| MATCH — correct output | 24 | (all except the 3 below) |
| MISMATCH — incorrect output | 3 | `dynprog`, `lu`, `adi` |
| Not transformed — parser error | 2 | `atax`, `bicg` |
| Blacklisted (OOM at LARGE_DATASET) | 1 | `fdtd-apml` (not relevant here, still runs fine at SMALL) |

This is the result with the fixed `LoopUnroll.ts` (cleanup loop lower bound
rewritten as `hi+1 - MOD(hi-lo+1, factor)`), up from 8/28 with the original
broken formula.

---

## Fortran-transpiler limitations identified

All failures trace to **the Fortran AST emitter not parenthesizing compound
sub-expressions when they appear as the right operand of a subtraction**. The
root invariant that fails: `Subtract(A, BinaryOp(B, C))` is emitted as
`A - B op C` rather than `A - (B op C)`.

This single emitter gap causes three distinct failure modes:

---

### Limitation 1 — Parser: `NamedConstantDef` AST node unimplemented

**Affected benchmarks:** `atax`, `bicg`

**Trigger:** Any benchmark containing a `PARAMETER` declaration:
```fortran
real, parameter :: alpha = 1.0, beta = 1.0
```

**Error:**
```
java.lang.RuntimeException: Could not find derived key for id ...-NamedConstantDef
  at StmtProcessors.parameterStmt(StmtProcessors.java:379)
```

**What it is:** Flang's AST represents named constants (the rhs of a `PARAMETER`
statement) as `NamedConstantDef` nodes. The Java parser in
`fortran-transpiler/FortranAst` has no entry for this node type — it is missing
from `FlangName` enum and has no processor in `Nodes.java`. The parser hard-crashes
before the LARA script even starts.

**Fix location:** `FortranAst/src/.../parser/` — add `NamedConstantDef` to
`FlangName`, implement a processor in `Nodes.java`, and add the mapping in
`FlangToClass`. The fix is entirely in the Java layer; no TypeScript changes needed.

**Impact:** 2/30 benchmarks unprocessable regardless of transform.

---

### Limitation 2 — Emitter: compound lower bound in cleanup loop (dynprog, lu)

**Affected benchmarks:** `dynprog`, `lu`

**Trigger:** Innermost loop has a compound lower bound — a variable expression
rather than a literal:
- `dynprog`: `DO k = i + 1, j - 1` (lo = `i+1`)
- `lu`:      `DO j = k + 1, n`     (lo = `k+1`)

**How it breaks:** The cleanup loop lower bound formula in `LoopUnroll.ts` is:

```typescript
// hi + 1 - MOD(hi - lo + 1, factor)
const tripCount = Subtract(upper, lower) + 1   // = hi - lo + 1
```

When `lower` is a compound node like `Add(k, 1)`, the subtraction
`Subtract(upper, lower)` emits **without parentheses around `lower`**:

| | Expression | Emitted Fortran | Fortran value |
|---|---|---|---|
| Intended | `(n) - (k+1) + 1` | needs parens | `n - k` |
| Actual | `Subtract(n, Add(k,1)) + 1` | `n - k + 1 + 1` | `n - k + 2` |

The MOD argument is off by +2, so the cleanup loop starts at the wrong index
and either double-processes or skips 1–3 elements.

**Concrete example (`lu`, n=128, k=10):**
- Correct cleanup start: `n + 1 - MOD(n-k, 4)` = `129 - MOD(118, 4)` = `129 - 2` = `127`
- Actual:  `n + 1 - MOD(n-k+2, 4)` = `129 - MOD(120, 4)` = `129 - 0` = `129` → cleanup empty → iterations 127, 128 skipped

**Fix location:** The cleanup formula in `LoopUnroll.ts` is correct mathematically,
but `Subtract(hi, lo)` must parenthesize `lo` when `lo` is a binary expression.
The real fix is in the **Fortran AST emitter** (`FortranWeaver` / `FortranAst`) to
add parentheses when serializing a binary operator node that appears as the right
operand of a subtraction. Alternatively, `LoopUnroll.ts` could emit the bound as
a Fortran `MAX` intrinsic call to avoid the subtraction issue.

---

### Limitation 3 — Emitter: induction variable inside subtraction in loop body (adi)

**Affected benchmarks:** `adi`

**Trigger:** Loop body contains expressions where the induction variable appears
as the subtrahend (right-hand side of a minus), such as `n - i2` or `n - i2 - 1`.

**Relevant adi loop:**
```fortran
do i2 = 1, n - 2
  x(n - i2, i1) = (x(n - i2, i1) - x(n - i2 - 1, i1) * a(...)) / b(...)
end do
```

**How it breaks:** `substituteVar(stmt, "i2", offset)` replaces every DataRef
named `i2` with `Add(i2_ref, intLiteral(offset))`. When this substituted node
is used inside an existing `Subtract(n, i2_ref)`, it becomes
`Subtract(n, Add(i2_ref, offset))`.

The emitter serializes this **without parentheses** around the `Add`:

| | Expression | Emitted Fortran | Fortran value |
|---|---|---|---|
| Intended | `n - (i2 + 1)` | `n - (i2 + 1)` | `n - i2 - 1` |
| Actual | `Subtract(n, Add(i2, 1))` | `n - i2 + 1` | `n - i2 + 1` |

The **sign of the offset flips** — `+1` becomes `-(-1)` when the parens are
dropped from the subtrahend. This produces wildly incorrect array indices
(accessing `x(n-i2+1)` instead of `x(n-i2-1)`), corrupting the entire
computation. The output values differ by several orders of magnitude from the
reference.

**Fix location:** Again the **Fortran AST emitter** — when serializing
`Subtract(A, B)` where `B` is itself a binary expression node, wrap `B` in
parentheses: emit `A - (B)`. This is the same one-line fix that would also
resolve Limitation 2. The fix is in `FortranWeaver/src/` (Java layer).

**Impact:** Any benchmark whose innermost loop body contains the pattern
`expr - induction_var` is at risk. In PolyBench/Fortran this pattern appears
in backwards-sweep / reverse-index kernels (adi, and potentially others at
larger dataset sizes or with other transforms).

---

## Root cause summary

All three limitations share a common ancestor: **the Fortran AST-to-source
emitter does not add parentheses around binary expression sub-nodes when they
appear as the right operand of subtraction**.

The Fortran operator precedence rule `A - B + C = (A - B) + C` (left-to-right)
means that dropping parens around `B` when `B = (X + Y)` gives
`A - X + Y` instead of `A - (X+Y) = A - X - Y`. This sign-flip is the
underlying error in both Limitations 2 and 3.

**The single fix:** In the Fortran emitter, when generating `Subtract(lhs, rhs)`,
check if `rhs` is itself an `Add` or `Subtract` binary node, and if so emit
`{lhs} - ({rhs})`.

Once that fix is applied, `LoopUnroll.ts`'s formula `hi+1 - MOD(hi-lo+1, factor)`
will emit correctly for all loop bounds (including compound `lo` like `k+1`), and
`substituteVar` will correctly handle induction variables embedded in subtraction
expressions. Combined with fixing `NamedConstantDef` in the Java parser, the
expected outcome is **28/30 correct** (only `atax`/`bicg` would remain until the
parser fix, and all other benchmarks would pass).

## Final results after parenExpr fix (branch `fix/emitter-paren-binop`)

| State | Correct | Mismatch | Notes |
|---|---|---|---|
| Original buggy `LoopUnroll.ts` | 8/28 | 20 | Cleanup re-executes last iter on all accum. loops |
| After `LoopUnroll.ts` MOD fix | 24/28 | 3 (dynprog, lu, adi) | Emitter parens bug on compound bounds + reverse-index bodies |
| After parenExpr fix | **30/30** | **0** | All benchmarks correct and transformable |

The `fix/emitter-paren-binop` branch (based on `origin/staging`) achieves 30/30 because:
1. **parenExpr(ctrl.lower)** in tripCount fixes dynprog + lu — `n - (k+1) + 1` instead of `n - k + 2`
2. **parenExpr(Add(ref, offset))** in `substituteVar` fixes adi — `x(n - (i2+1))` instead of `x(n - i2 + 1)`
3. **Staging PR #48** (`parameter-attr`) fixed `NamedConstantDef` parser crash — atax + bicg now transformable
4. **fdtd-apml** is no longer unconditionally blacklisted — `execute.sh` now detects
   the compiled array size and only blacklists it when ≥ 256 (LARGE_DATASET)
