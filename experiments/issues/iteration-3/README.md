# Iteration 3 — Issue Analysis

Third pass: implements tiling legality checks and records the resolution with
concrete code examples showing what the transpiler produces and why each illegal
pair is blocked.

## Contents

| File | Transform | Result | State |
|---|---|---|---|
| `tiling-analysis.md` | Tiling | **30/30** | Resolved |
| `tiling-results.txt` | raw compare.sh output | — | — |
| `fission-analysis.md` | Fission | **30/30** | Resolved |
| `fission-results.txt` | raw compare.sh output | — | — |

## Progress since iteration 2

| Transform | Iter 2 | Iter 3 | Delta |
|---|---|---|---|
| Tiling | 28/30 | **30/30** | +2 (Check 1 + Check 2 in `canTile()`) |
| Fission | 21/30 | **30/30** | +9 (Check 1 scalar + Check 2 array read/write in `canFission()`) |
| Interchange | 30/30 | — | carried resolved |
| Unrolling | 30/30 | — | carried resolved |
| Fusion | 30/30 | — | carried resolved |

## Fix summaries

### Tiling

Extended `canTile()` in `src-api/code/LoopTiling.ts` with two checks (same patterns
as `canInterchange()`), using word-boundary regex to avoid false positives:

- **Check 1** — Triangular inner bound: reject if inner loop's lower or upper bound
  contains the outer loop variable as a whole word.
- **Check 2** — Nested loop in body references outer var: reject if any descendant
  loop inside the inner body has a bound containing the outer loop variable.

### Fission

Extended `canFission()` in `src-api/code/LoopFission.ts` with dependency analysis
and fixed a critical bug in the helper functions.

**Bug**: `Query.searchFrom(stmt, AssignmentStatement)` searches only the children of
`stmt`. When `stmt` itself is an `AssignmentStatement`, it finds nothing. Fixed by
switching to `Query.searchFromInclusive` in all three helper functions.

- **Check 1** — Scalar threading: reject if any scalar written in an earlier stmt
  appears (by word-boundary regex) in a later stmt's code.
- **Check 2** — Array write-before-read: reject if a later stmt writes any array
  that an earlier stmt reads.

## Open issues

None — all 5 transforms produce 30/30 MATCH.
