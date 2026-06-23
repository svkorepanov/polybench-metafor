# 6. Implementation

This chapter describes the implementation of the source-to-source compilation approach developed in this dissertation. The goal of the implementation is to parse Fortran source code, represent it in a form that can be inspected and modified, apply selected loop transformations, and generate Fortran code again from the modified representation.

The implementation was designed around a conservative rule: a transformation is applied only when the required conditions can be checked with sufficient confidence. If a loop does not satisfy the conditions, or if the available information is not enough to prove that the transformation is safe, the original code is preserved. This decision is important because loop transformations can easily change the order in which values are read and written. Even a syntactically valid transformation may produce wrong results if data dependencies are not respected.

The implemented transformations are loop interchange, loop fusion, loop fission, loop unrolling, and loop tiling. All of them are applied at the source-code level through the Abstract Syntax Tree (AST). The compiler does not generate machine code. Instead, it rewrites Fortran code into another Fortran program that should be semantically equivalent to the original one, while exposing a loop structure that may be more suitable for later compilation and optimization.

## 6.1 Architecture Overview

The implementation is integrated into the METAFOR framework. METAFOR uses the LARA framework internally, which provides support for source-code analysis and transformation through scripts. In this project, the framework is used to connect a Fortran front end, an AST representation, a weaver, and a scripting interface for loop transformations.

The architecture can be described as a pipeline with four main components.

First, the Fortran source code is parsed using the LLVM Flang 22 compiler. A custom plugin, called `flang-dumper`, is used to extract the relevant information from the compiler representation and dump it into JSON format. This JSON file is the first intermediate representation used by the project.

Second, a Java module reads the dumped JSON and builds the internal AST used by the Fortran transpiler. This AST gives a structured representation of the program. For example, a `do` loop is represented as a node with an iterator, lower bound, upper bound, step, and body. Expressions, assignments, array references, and nested statements are also represented as nodes.

Third, the Java weaver exposes the AST to transformation scripts. The weaver provides a join point model, where relevant AST nodes can be selected, inspected, and modified. Join points are the bridge between the internal compiler representation and the scripting interface.

Fourth, the Fortran-JS module provides a Node.js and TypeScript interface for writing transformation scripts. Through this interface, a transformation script can search for loops, read their properties, check transformation preconditions, and request changes to the AST.

This separation of responsibilities makes the implementation easier to extend. The parsing stage is responsible for extracting information from Fortran code. The Java AST is responsible for storing this information in a structured form. The weaver is responsible for exposing the AST in a controlled way. The Fortran-JS layer is responsible for writing and executing transformation logic.

## 6.2 Parsing, AST Representation, Weaving and Code Generation

### 6.2.1 Parsing Fortran Source Code

The initial parsing stage is based on LLVM Flang 22. Flang is used because it already provides a Fortran parser and can handle many language constructs that would be difficult to support in a custom parser. However, the data produced by the compiler is not directly suitable for the transformations implemented in this project. For that reason, the `flang-dumper` plugin was developed by the team.

The purpose of `flang-dumper` is to traverse the compiler representation and dump the required nodes into a JSON file. This JSON file contains the information needed to reconstruct the source program as an AST. In the context of loop transformations, the most important information includes loop headers, loop variables, loop bounds, loop steps, loop bodies, assignments, array references, scalar variables, and expression trees.

The plugin had to be adjusted during the implementation because several Fortran nodes have a complex internal structure. In many cases, the required information is not stored directly in a single field. It must be collected from nested objects or from different parts of the compiler representation. This is especially relevant for expressions, array subscripts, and loop bounds, because transformation safety depends on understanding which variables appear in these locations.

### 6.2.2 Building the Internal AST

After the JSON representation is produced, it is processed by a Java module that builds the Fortran-transpiler AST. Each supported JSON node is mapped to a corresponding AST node. The AST node stores the node type, its attributes, and its children. For example, a loop node stores the loop iterator, the lower bound, the upper bound, the optional step, and the statements contained in the loop body.

The AST representation is designed to support both analysis and rewriting. Analysis requires access to node properties, such as the iterator of a loop or the subscripts of an array reference. Rewriting requires the ability to replace nodes, move statement groups, and generate new loop nodes. Because of this, the AST is not only a tree for reading the program. It is also the main structure used to construct the transformed program.

A clear node representation is important for loop transformations. For example, loop fusion needs to compare the headers of two adjacent loops. Loop interchange needs to inspect whether two loops are perfectly nested. Loop tiling needs to create new tile loops and adjust the original bounds. These operations are much simpler when each program construct has a well-defined AST node.

### 6.2.3 Exposing AST Nodes Through the Weaver

The transformation scripts do not manipulate the Java AST directly. Instead, the AST is exposed through the Fortran weaver. The weaver provides a join point interface that gives controlled access to AST nodes and their operations.

The available join points and their properties are described in XML files. These XML descriptions define which AST nodes are visible to the scripting layer and which methods or attributes can be used. After the XML structure is complete, the FortranWeaver automatically generates TypeScript interfaces and abstract Java classes. This automatic generation reduces duplicated work and helps keep the scripting interface consistent with the Java side.

However, the generated interfaces are not enough by themselves. For each abstract class, a concrete class must be implemented manually. These concrete classes connect the generated join point model to the actual AST nodes. In practice, they define how a method call from a TypeScript transformation script is translated into an operation on the Java AST.

This design adds some implementation effort, but it also has an advantage. It separates the public transformation interface from the internal AST implementation. A script can use high-level operations such as selecting loops or reading loop bounds, while the Java side controls how those operations are performed.

### 6.2.4 General Transformation Flow

All loop transformations follow the same general flow. The AST is traversed to find candidate loop nodes or loop groups. When a candidate is found, the transformation checks whether the required preconditions are satisfied. These checks are specific to each transformation. If they succeed, the corresponding AST subtree is rewritten. If they fail, the subtree is left unchanged.

The general flow is as follows:

1. Traverse the AST and select candidate nodes.
2. Read the properties needed by the transformation.
3. Check transformation-specific preconditions.
4. Rewrite the AST if the checks succeed.
5. Preserve the original AST if the checks fail.
6. Generate Fortran code from the final AST.

This approach keeps the transformations local. Each transformation works on a clearly defined part of the AST, such as a loop nest or a pair of adjacent loops. This reduces the risk of unintended changes in unrelated parts of the program.

### 6.2.5 Code Generation

After all transformations have been applied, the modified AST is traversed to generate Fortran source code. Code generation is based on the attributes of each AST node and on the position of the node in the tree. A loop node generates a `do` statement, its body, and a closing `end do`. An assignment node generates its left-hand side, the assignment operator, and its right-hand side. Expression nodes generate their textual representation according to their structure.

The generated code is not expected to be a byte-for-byte copy of the original source. Formatting may change because the code is produced from the AST. However, the generated program should preserve the semantics of the original program when no transformation is applied, and it should preserve semantics after a transformation when the corresponding preconditions are satisfied.

## 6.3 Transformation Safety and Dependency Checks

Loop transformations are powerful because they change the execution order of program statements. This can improve locality, reduce loop overhead, or expose more optimization opportunities to a backend compiler. At the same time, these transformations can break a program when there are dependencies between iterations or between statements.

For this reason, the implementation uses conservative dependency checks. These checks are not intended to be a complete dependence analysis for all possible Fortran programs. Instead, they target the patterns that are most relevant to the implemented transformations. The checks inspect loop bounds, iterator usage, scalar assignments, array accesses, and the relative position of statements.

The implementation pays special attention to the following cases:

- whether an inner loop bound depends on an outer loop variable;
- whether a nested loop inside a body depends on a loop variable whose execution order may change;
- whether two loops have compatible bounds before fusion;
- whether a scalar temporary is used across statements that would be separated by fission;
- whether array subscripts indicate a cross-iteration dependency;
- whether unrolling is applied only to a loop that has no nested loops inside it;
- whether tiling would remove or weaken a dependency expressed through loop bounds.

The checks are intentionally strict. If a pattern is recognized as unsafe, the transformation is not applied. If a pattern is not recognized, the implementation also avoids applying the transformation. This choice favours correctness over aggressive optimization.

## 6.4 Loop Interchange

Loop interchange swaps the order of two nested loops. For example, an outer loop over `i` and an inner loop over `j` can be transformed into an outer loop over `j` and an inner loop over `i`. This transformation is often used to change the memory access order or to expose a more suitable loop structure for later transformations.

In this implementation, loop interchange is applied only to two directly nested loops. The original loop body is preserved, but the loop headers are exchanged. Since the order of iteration changes, the transformation is safe only when the new order does not violate data dependencies.

### 6.4.1 Preconditions

The first precondition is that the two loops must be perfectly nested. This means that the outer loop body contains only the inner loop and no additional statements between the outer and inner loop headers. If there are statements before or after the inner loop, interchanging the loops would also change the relative execution order of those statements, so the transformation is not applied.

The second precondition is that the loops must not be triangular. A triangular loop is a loop nest where the bounds of the inner loop depend on the outer loop variable. In such a case, simply swapping the loop headers is not correct because the original iteration space is not rectangular.

The following example shows an unsafe case:

```fortran
! Original
 do j = 1, maxgrid
   do i = j, maxgrid
     do cnt = 1, length
       diff(cnt, i, j) = sumTang(i, j)
     end do
   end do
 end do

! Incorrect result after a direct interchange
 do i = j, maxgrid
   do j = 1, maxgrid
     do cnt = 1, length
       diff(cnt, i, j) = sumTang(i, j)
     end do
   end do
 end do
```

In the transformed version, the bound of the new outer loop refers to `j`, but `j` is no longer defined at that point. Even if such code is accepted by a compiler, its behaviour is not correct. For this reason, the implementation rejects loop interchange when the inner loop bound contains the outer loop variable.

The third precondition concerns nested loops inside the body. Even when the two main loop bounds are rectangular, the body may contain another loop whose bounds depend on the original outer variable. Interchanging the two main loops may then change the order in which values are produced and consumed.

```fortran
! Original
 do i = 2, ni
   do j = 1, ni
     do k = 1, i - 1
       b(j, i) = b(j, i) + alpha * a(k, i) * b(k, j)
     end do
   end do
 end do

! After interchange
 do j = 1, ni
   do i = 2, ni
     do k = 1, i - 1
       b(j, i) = b(j, i) + alpha * a(k, i) * b(k, j)
     end do
   end do
 end do
```

The transformed code is syntactically valid, but it may read values of `b` in a different order. Values that were previously computed before a read may now be read before they are updated. Therefore, the implementation checks whether nested loop bounds inside the body depend on the original outer loop variable.

### 6.4.2 Transformation Algorithm

The loop interchange algorithm is implemented as a local AST rewrite. It uses the following steps:

1. Detect a perfectly nested pair of loops.
2. Identify the outer and inner loop nodes.
3. Check that the inner loop bounds do not depend on the outer loop variable.
4. Check that nested loops inside the body do not introduce unsafe dependencies.
5. Create a new loop nest where the inner and outer loop headers are swapped.
6. Move the original body into the innermost loop of the new nest.
7. Replace the original loop nest with the transformed loop nest.
8. Generate Fortran code from the modified AST.

The body is not rewritten except for its position in the loop nest. This keeps the transformation simple and reduces the number of source-level changes.

### 6.4.3 Example

A valid loop interchange has the following general form:

```fortran
! Before
 do i = lo_i, hi_i
   do j = lo_j, hi_j
     body
   end do
 end do

! After
 do j = lo_j, hi_j
   do i = lo_i, hi_i
     body
   end do
 end do
```

This transformation is safe only if the execution order of `body` can be changed from `(i, j)` order to `(j, i)` order without changing the values that are read or written.

## 6.5 Loop Fusion

Loop fusion combines two adjacent loops into one loop. The bodies of the original loops are placed inside a single loop with the same iteration space. This transformation can reduce loop overhead and may improve locality when the two loops access related data.

In this implementation, fusion is applied to two loops that appear directly one after another in the same block. The loops must have compatible headers, and the combined body must not violate dependencies.

### 6.5.1 Preconditions

The first precondition is that the two loops must be adjacent. There must be no statement between them. If another statement appears between the loops, fusion could change when that statement is executed relative to the loop bodies.

The second precondition is that both loops must have the same iterator, lower bound, upper bound, and step. This ensures that each iteration of the fused loop corresponds to one iteration of the first original loop and one iteration of the second original loop.

The third precondition is that fusion must not cause a loop body to read a value before it has been fully computed. A common unsafe case occurs when the first loop performs a reduction into an array element that does not depend on the fusion variable, and the second loop reads that element.

```fortran
! Original
 do j = 1, n
   tmp(i) = tmp(i) + a(j, i) * x(j)
 end do

 do j = 1, n
   y(j) = y(j) + a(j, i) * tmp(i)
 end do

! Incorrect result after fusion
 do j = 1, n
   tmp(i) = tmp(i) + a(j, i) * x(j)
   y(j) = y(j) + a(j, i) * tmp(i)
 end do
```

In the original code, `tmp(i)` is fully computed before the second loop starts. After fusion, `y(j)` reads `tmp(i)` during the same iteration, when the reduction is still incomplete. The implementation therefore rejects fusion when a written array element does not contain the fusion variable in its subscript and the other loop reads the same element.

Another unsafe pattern appears with transposed array accesses. One loop may write `X(inner_var, fusion_var)`, while the other loop reads `X(fusion_var, inner_var)`. This creates a dependency across different outer iterations.

```fortran
! Original
 do i = 1, n
   do j = 1, n
     a(j, i) = a(j, i) + u1(i) * v1(j)
   end do
 end do

 do i = 1, n
   do j = 1, n
     x(i) = x(i) + beta * a(i, j)
   end do
 end do

! Unsafe fused structure
 do i = 1, n
   do j = 1, n
     a(j, i) = a(j, i) + u1(i) * v1(j)
   end do
   do j = 1, n
     x(i) = x(i) + beta * a(i, j)
   end do
 end do
```

At a given value of `i`, the first inner loop writes one column of `a`, while the second inner loop reads one row of `a`. Some values in that row may belong to columns that will be written only in future iterations. Therefore, fusion is unsafe.

A third unsafe pattern occurs when one loop reads an array across an inner-loop range and the other loop writes one element of the same array at each outer iteration.

```fortran
! Original
 do p = 1, np
   do s = 1, np
     sumA(p) = sumA(p) + a(s) * cFour(p, s)
   end do
 end do

 do p = 1, np
   a(p) = sumA(p)
 end do

! Incorrect result after fusion
 do p = 1, np
   do s = 1, np
     sumA(p) = sumA(p) + a(s) * cFour(p, s)
   end do
   a(p) = sumA(p)
 end do
```

In the original code, all reads of `a(s)` are completed before any element of `a` is overwritten. After fusion, `a(1)` is overwritten during the first iteration and may be read during later iterations. The implementation rejects this pattern because the fused code changes the visible values of the array.

### 6.5.2 Transformation Algorithm

The loop fusion algorithm proceeds as follows:

1. Detect two adjacent loops in the same statement block.
2. Check that both loops have the same iterator, bounds, and step.
3. Analyze the bodies of the two loops for unsafe scalar and array dependencies.
4. Create a new loop using the shared loop header.
5. Copy the body of the first loop into the new loop body.
6. Append the body of the second loop after the first body.
7. Replace the two original loops with the fused loop.
8. Generate Fortran code from the modified AST.

The relative order of the two bodies is preserved. Statements from the first loop remain before statements from the second loop inside each fused iteration.

### 6.5.3 Example

A simple valid fusion is shown below:

```fortran
! Before
 do i = 1, n
   a(i) = b(i)
 end do

 do i = 1, n
   c(i) = d(i)
 end do

! After
 do i = 1, n
   a(i) = b(i)
   c(i) = d(i)
 end do
```

This transformation is valid when the assignments are independent for each value of `i`, and when the second statement does not need the first loop to complete all iterations before it starts.

## 6.6 Loop Fission

Loop fission is the opposite of loop fusion. It splits one loop into two or more loops. Each new loop keeps the original iterator, bounds, and step, but receives only part of the original loop body. This transformation can be useful when different statement groups have different memory access patterns or when later optimizations require simpler loop bodies.

In this implementation, fission is applied only when the statements or statement groups can be separated without changing the program semantics. The main difficulty is that statements inside one loop iteration may depend on each other. When a loop is split, all iterations of the first generated loop execute before any iteration of the second generated loop. This changes the timing of reads and writes.

### 6.6.1 Preconditions

The first precondition is that the loop must contain multiple statements or multiple statement groups. A loop with only one statement cannot be meaningfully split by this transformation.

The second precondition is that scalar temporaries must not be threaded between statements that would be moved into different loops. This pattern appears when an earlier statement computes a scalar value and a later statement uses it in the same iteration.

```fortran
! Original
 do k = 1, nj
   nrm = 0.0D0
   do i = 1, ni
     nrm = nrm + a(k, i) * a(k, i)
   end do
   r(k, k) = sqrt(nrm)
 end do

! Incorrect result after fission
 do k = 1, nj
   nrm = 0.0D0
 end do

 do k = 1, nj
   do i = 1, ni
     nrm = nrm + a(k, i) * a(k, i)
   end do
 end do

 do k = 1, nj
   r(k, k) = sqrt(nrm)
 end do
```

In the original code, `nrm` is computed separately for each value of `k` and is used immediately in the same iteration. After fission, the final loop reads only the scalar value left by the previous loop, which is not the value required for each individual iteration. The implementation rejects fission when it detects this type of scalar producer-consumer relationship.

The third precondition concerns arrays that are read by an earlier statement and written by a later statement. In the original loop, the later write from one iteration may be needed by the earlier read in the next iteration. After fission, all earlier reads happen before any later write, so those reads may observe stale values.

```fortran
! Original structure
 do t = 1, tmax
   ! S1: boundary update
   do j = 1, ny
     ey(j, 1) = fict(t)
   end do

   ! S2: reads hz
   do i = 2, nx
     do j = 1, ny
       ey(j, i) = ey(j, i) - 0.5 * (hz(j, i) - hz(j - 1, i))
     end do
   end do

   ! S3: reads hz
   do i = 1, nx
     do j = 2, ny
       ex(j, i) = ex(j, i) - 0.5 * (hz(j, i) - hz(j, i - 1))
     end do
   end do

   ! S4: writes hz
   do i = 1, nx
     do j = 1, ny
       hz(j, i) = hz(j, i) - 0.7 * (ex(j + 1, i) + ey(j, i + 1))
     end do
   end do
 end do
```

If this loop is split so that all `S2` iterations run before any `S4` iteration, then later time steps may read old values of `hz`. The original loop updates `hz` once per time step, and the next time step expects the updated values. Fission would break that order.

### 6.6.2 Transformation Algorithm

The loop fission algorithm is implemented as follows:

1. Detect a loop that contains multiple statements or statement groups.
2. Build the candidate groups that could be moved into separate loops.
3. Analyze scalar dependencies between the groups.
4. Analyze array read/write relationships between the groups.
5. Create two or more loops with the same iterator, bounds, and step.
6. Move each statement group into the corresponding new loop.
7. Replace the original loop with the generated sequence of loops.
8. Generate Fortran code from the modified AST.

The generated loops keep the original loop header. Only the body is split. This makes the transformation easier to reason about and avoids changing the iteration space.

### 6.6.3 Example

A simple valid fission is shown below:

```fortran
! Before
 do i = 1, n
   a(i) = b(i)
   c(i) = d(i)
 end do

! After
 do i = 1, n
   a(i) = b(i)
 end do

 do i = 1, n
   c(i) = d(i)
 end do
```

This transformation is valid when the two assignments are independent and neither statement needs values produced by the other statement in the same iteration or in a neighbouring iteration.

## 6.7 Loop Unrolling

Loop unrolling duplicates the body of a loop several times and increases the loop step accordingly. The unrolling factor defines how many original iterations are executed inside one transformed iteration. For example, with a factor of four, one iteration of the transformed loop performs the work of four iterations of the original loop.

The purpose of unrolling is to reduce loop-control overhead and to expose a larger straight-line block of code to later compiler optimizations. Since this project performs source-to-source transformation, the unrolled loop is generated directly in Fortran.

### 6.7.1 Preconditions

The implemented unrolling transformation is applied only to innermost loops. A loop is considered innermost when its body does not contain another loop. This restriction keeps the transformation local and avoids complex interactions with nested loop structures.

The transformation also requires an unrolling factor. The factor must be a positive integer greater than one. The implementation duplicates the loop body according to this factor and updates index expressions in each copy.

### 6.7.2 Transformation Algorithm

The loop unrolling algorithm uses the following steps:

1. Find a candidate innermost loop.
2. Read the requested unrolling factor.
3. Create a new loop whose step is multiplied by the unrolling factor.
4. Duplicate the original loop body once for each unrolled iteration.
5. Update occurrences of the loop iterator in each duplicated copy.
6. Generate a remainder loop if the total iteration count is not divisible by the factor.
7. Replace the original loop with the unrolled loop and the optional remainder loop.
8. Generate Fortran code from the modified AST.

The remainder loop is important because the number of iterations may not be a multiple of the unrolling factor. Without a remainder loop, the transformed program could skip the last iterations.

### 6.7.3 Example

The following example shows unrolling with factor `4`:

```fortran
! Before
 do i = 1, n
   a(i) = b(i)
 end do

! After
 do i = 1, n - 3, 4
   a(i)     = b(i)
   a(i + 1) = b(i + 1)
   a(i + 2) = b(i + 2)
   a(i + 3) = b(i + 3)
 end do

 do i = n + 1 - MOD(n - 1 + 1, 4), n
   a(i) = b(i)
 end do
```

The first loop executes groups of four iterations. The second loop executes the remaining iterations, if any. If there is no remainder, the second loop has an empty iteration range and does not change the result.

## 6.8 Loop Tiling

Loop tiling, also called blocking, transforms a nested loop into a set of smaller blocks or tiles. Each tile contains a subset of the original iteration space. This transformation is commonly used to improve cache locality because it allows the program to work on smaller regions of data at a time.

In this implementation, tiling is applied to a pair of nested loops. The transformation creates outer tile loops and inner point loops. The tile loops move through the iteration space using the tile size as the step. The point loops iterate over the elements inside each tile.

### 6.8.1 Preconditions

The first precondition is that the transformation must be applied to two nested loops. The implementation expects an ideally nested structure, where the outer loop contains the inner loop and the inner loop contains the body to be tiled.

The second precondition is that the loops must have bounds with an invariant trip count. The implementation must be able to construct tile boundaries without changing the original iteration space. Rectangular loop nests are suitable for this transformation. Triangular loops are not handled by the implemented tiling algorithm.

A triangular loop appears when the inner loop bound depends on the outer loop variable:

```fortran
! Before
 do j = 1, maxgrid
   do i = j, maxgrid
     do cnt = 1, length
       diff(cnt, i, j) = sumTang(i, j)
     end do
   end do
 end do
```

If this loop is tiled by replacing the inner start with a tile origin, the condition `i >= j` may be lost. This changes the iteration space. In addition, a generated tile loop could refer to a variable that is not yet defined at that point. For this reason, the implementation rejects tiling when the inner bound contains the outer loop variable.

The third precondition concerns nested loops inside the body. If a loop inside the body uses the outer tiled variable in its bounds, tiling may change the order in which required values are computed.

```fortran
! Original
 do i = 2, ni
   do j = 1, ni
     do k = 1, i - 1
       b(j, i) = b(j, i) + alpha * a(k, i) * b(k, j)
     end do
   end do
 end do

! Tiled structure
 do ii = 2, ni, 32
   do jj = 1, ni, 32
     do i = ii, MIN(ii + 32 - 1, ni)
       do j = jj, MIN(jj + 32 - 1, ni)
         do k = 1, i - 1
           b(j, i) = b(j, i) + alpha * a(k, i) * b(k, j)
         end do
       end do
     end do
   end do
 end do
```

The transformed code keeps the expression `k = 1, i - 1`, but the tile order may process combinations of `i` and `j` in an order that differs from the original program. If the body reads values that are produced by earlier outer iterations, tiling may cause reads of incomplete values. The implementation therefore rejects this pattern.

### 6.8.2 Transformation Algorithm

The loop tiling algorithm proceeds as follows:

1. Detect a nested pair of loops suitable for tiling.
2. Check that the loops have invariant and rectangular bounds.
3. Check that the inner bound does not depend on the outer loop variable.
4. Check that nested loops inside the body do not introduce unsafe dependencies.
5. Generate the outer tile loops.
6. Generate the inner point loops.
7. Adjust the upper bounds of the point loops with `MIN` to handle boundary tiles.
8. Move the original loop body into the innermost point loop.
9. Replace the original loop nest with the tiled loop nest.
10. Generate Fortran code from the modified AST.

The use of `MIN` ensures that the final tile does not go beyond the original upper bound when the iteration count is not divisible by the tile size.

### 6.8.3 Example

A general two-dimensional tiling transformation is shown below:

```fortran
! Before
 do i = lo_i, hi_i
   do j = lo_j, hi_j
     body
   end do
 end do

! After
 do ii = lo_i, hi_i, TILE
   do jj = lo_j, hi_j, TILE
     do i = ii, MIN(ii + TILE - 1, hi_i)
       do j = jj, MIN(jj + TILE - 1, hi_j)
         body
       end do
     end do
   end do
 end do
```

The generated tile variables `ii` and `jj` define the start of each tile. The original variables `i` and `j` are still used by the body, but they now iterate inside the tile boundaries.

## 6.9 Chapter Summary

This chapter presented the implementation of the Fortran source-to-source transformation system. The implementation is built around the METAFOR framework and uses the LARA-based weaving approach to expose Fortran AST nodes to transformation scripts. The front end parses Fortran code with LLVM Flang 22 and dumps a JSON representation through the `flang-dumper` plugin. A Java module then builds the internal AST, and the weaver exposes this AST to the Fortran-JS TypeScript interface.

The implemented loop transformations are applied by traversing the AST, selecting candidate loops, checking preconditions, rewriting the relevant subtree, and regenerating Fortran code. The transformations are conservative by design. They are applied only when the implementation can verify that the required structural and dependency conditions are satisfied.

The chapter also described the specific implementation rules for loop interchange, loop fusion, loop fission, loop unrolling, and loop tiling. For each transformation, the main unsafe cases were identified and used as preconditions. This approach allows the system to perform useful source-level loop transformations while reducing the risk of changing program semantics.
