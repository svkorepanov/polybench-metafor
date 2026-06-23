# Chapter 5. Methodology

This chapter describes the methodology used to design, validate, and evaluate the proposed source-to-source loop transformation support for Fortran programs. The work follows an artifact-oriented research approach. The main result is not only a set of performance numbers, but an engineering artifact integrated into the METAFOR infrastructure. The artifact makes loop transformations available as explicit and controllable operations over Fortran source code.

The motivation for this methodology comes from a practical limitation of many compiler-based optimizations. Modern compilers can apply loop transformations automatically, but their decisions are often hidden from the user and can be difficult to control in large scientific projects. This dissertation studies a different approach: loop transformations are applied at the source-code level, before compilation, and the resulting Fortran code can be inspected, adjusted, compiled, and tested by the developer. In this setting, the research question can be stated as follows:

> Can source-to-source transformation make loop transformations and optimizations of large Fortran projects less heuristic, more transparent, and more adjustable, while enabling more precise program tuning?

The purpose of the methodology is therefore to show how the transformation artifact was designed, how its safety was checked, and how its behavior was evaluated using Fortran benchmark programs.

## 5.1 Research Approach

The research uses an artifact-based methodology. The artifact extends the existing METAFOR framework with support for loop transformations over Fortran `DO` loops. METAFOR already provided the main infrastructure before this work started. This included the parsing pipeline based on Flang22, the custom `flang-dumper` plugin, the Java-based AST representation, the weaver, the Fortran-JS scripting layer, and the integration between these components. The missing part, and the focus of this dissertation, was the support needed to represent the relevant loop structures and to perform source-to-source transformations on them.

The work is positioned mainly as a software engineering contribution. The goal is to demonstrate that METAFOR can be extended with built-in loop transformation operations that are available to users through scripts. The methodology does not try to build a complete optimizing compiler. It also does not try to automatically search all possible transformation sequences and select the best variant. Instead, the framework gives the user direct control over what transformation should be applied, where it should be applied, and which parameters should be used.

This distinction is important. In a compiler, an optimization pass is usually enabled or disabled through global flags, and the internal choice of loop transformations is made by the compiler. In the proposed source-to-source approach, the user writes a script that identifies a program region, such as a program, function, or subroutine, and then requests a specific transformation. The transformed source is regenerated and can be inspected before compilation. This makes the process more transparent and gives the developer more freedom to tune important kernels manually.

The scope of the artifact is limited to Fortran `DO` loops. The benchmark programs used in the evaluation are written in a Fortran 90 style, while the parsing infrastructure is based on Flang22 and aims to support modern Fortran features. The methodology therefore does not depend on one specific historical Fortran style. At the same time, the implementation and evaluation are restricted to loop structures that appear in the selected benchmark suite.

The general research workflow consisted of the following steps:

1. Identify the Fortran loop structures that must be represented in the METAFOR AST.
2. Extend the dumping and AST construction stages where required, so that these structures are available to the transformation layer.
3. Expose the required loop nodes and properties to the Fortran-JS interface.
4. Design source-to-source algorithms for the selected loop transformations.
5. Define conservative legality checks for transformation candidates.
6. Generate transformed Fortran code from the modified AST.
7. Validate the transformed programs on small benchmark datasets.
8. Evaluate execution time and transformation success on larger benchmark datasets.

The artifact was considered successful when it could detect a candidate loop structure, check whether the requested transformation was safe according to the implemented rules, rewrite the AST, regenerate compilable Fortran code, and preserve the output of the original program. Performance improvement was also measured, but it was not the only criterion. In this dissertation, loop transformation is treated as a foundation for further optimization, including later parallelization and more advanced tuning.

## 5.2 Transformation Design

Loop transformations were selected because loops dominate the execution time of many scientific and high-performance computing programs. In Fortran programs, especially those based on arrays and numerical kernels, a large part of the computation is expressed as nested `DO` loops. Changing the structure of these loops can affect memory locality, loop overhead, compiler optimization opportunities, and the suitability of the code for later parallel execution.

The implemented transformations are loop fusion, loop fission, loop interchange, loop tiling, and loop unrolling. These transformations were chosen because they are well-known, practical, and representative of different optimization goals. They also cover different types of AST rewriting. Some transformations merge or split loops, while others change loop nesting, introduce new loop levels, or duplicate loop bodies.

The transformations are exposed as user-controlled operations in the Fortran-JS layer. A user selects a region of the program and requests a transformation. The framework then searches for matching `DO` loop structures inside that region. If a loop satisfies the required preconditions and legality checks, the AST is rewritten. If the loop is unsafe or unsupported, the transformation is not applied and the original code is preserved.

### 5.2.1 Selected transformations and their goals

The following table summarizes the transformations considered in this work and the main reason for including each of them.

| Transformation | Main purpose in the methodology |
| --- | --- |
| Loop fusion | Merge adjacent loops with compatible iteration spaces to reduce loop overhead and possibly improve locality between producer and consumer statements. |
| Loop fission | Split a loop into several loops to separate independent computation stages and expose simpler loop bodies for later optimization. |
| Loop interchange | Swap the order of nested loops to improve memory access order or expose a more suitable loop structure. |
| Loop tiling | Introduce block-based traversal of nested loops to improve cache reuse and enable comparison with OpenMP-based tiling. |
| Loop unrolling | Duplicate the loop body by a fixed factor to reduce loop control overhead and expose more straight-line code to the compiler. |

The transformations were not combined in the experimental evaluation. Each transformation was evaluated separately. However, the framework design does not prevent users from building transformation pipelines. For example, a user could apply loop fission first and then apply tiling to one of the resulting loops. This was not treated as an automatic search problem in this dissertation. Choosing the best transformation sequence remains the responsibility of the user.

The transformation parameters were also selected manually. The tile size used for loop tiling was `32`, and the unrolling factor used for loop unrolling was `4`. These values were selected to demonstrate that the framework can support parameterized transformations. They were not the result of an automatic tuning process.

### 5.2.2 General transformation procedure

The transformation procedure follows the same general structure for all implemented transformations. The user specifies the transformation kind and the target program region. The framework then traverses the AST, searches for candidate loops, checks preconditions, applies the transformation when legal, and regenerates source code.

```text
Algorithm 5.1: Controlled source-to-source loop transformation

Input:
  ast              - AST of the original Fortran program
  target_region    - program, subroutine, function, or loop selected by the user
  transformation   - requested transformation kind
  parameters       - transformation parameters, such as tile size or unroll factor

Output:
  transformed_ast  - AST after applying the requested transformation where legal
  report           - information about applied and rejected transformations

procedure APPLY_TRANSFORMATION(ast, target_region, transformation, parameters):
    candidates = FIND_DO_LOOPS(target_region, transformation)

    for each loop_candidate in candidates do
        if not MATCHES_REQUIRED_SHAPE(loop_candidate, transformation) then
            mark loop_candidate as rejected
            continue
        end if

        if not PASSES_LEGALITY_CHECKS(loop_candidate, transformation) then
            mark loop_candidate as rejected
            continue
        end if

        new_subtree = REWRITE_AST(loop_candidate, transformation, parameters)
        REPLACE_SUBTREE(ast, loop_candidate, new_subtree)
        mark loop_candidate as transformed
    end for

    return ast and report
end procedure
```

This procedure reflects the main methodological decision of the work. The framework does not silently change the program in uncertain cases. If the required loop shape is not present, or if the legality checks cannot prove that the rewrite is safe, the transformation is rejected. In the user-facing result, this is reported as a transformation that was not applied.

### 5.2.3 Legality checking strategy

Correctness is the main risk in loop transformation. A transformation that changes the order of reads and writes can produce a program that still compiles but computes a different result. For this reason, each transformation is guarded by a set of legality checks.

The implemented legality checking strategy is conservative and rule-based. It is not a complete data dependence analysis. A full dependence analysis would need to reason about all array subscripts, scalar variables, procedure calls, aliases, pointers, and possible side effects. Such an analysis is outside the scope of this dissertation. Instead, the artifact implements checks that were required by the benchmark analysis and by the unsafe patterns encountered during development.

Several kinds of checks are used:

- **Syntactic loop-shape checks.** These checks verify whether the loop structure has the form required by the transformation. For example, loop interchange requires a perfectly nested pair of loops, loop fusion requires two adjacent loops with compatible bounds, and loop unrolling is applied only to innermost loops.
- **Array read/write comparison.** The transformation inspects statements in the candidate region and records which arrays are written and which arrays are read. If a transformation would move a write before a read that originally occurred earlier, or would cause a read to observe a partial value, the candidate is rejected.
- **Iterator-based subscript checks.** These checks compare how loop iterators appear in array subscripts. They are used to detect patterns such as transposed accesses, writes to the same element across all iterations, and reads that span a range of elements that may be updated by another loop.
- **Scalar dependency checks.** These checks detect scalar variables that are written in one statement and read by a later statement in a way that depends on the original loop order. This is especially important for loop fission, where scalar temporaries can lose their per-iteration meaning after the loop is split.
- **Reduction rejection.** Reductions were treated as unsafe in this work. Although reductions can sometimes be transformed legally, they require special handling to preserve numerical and semantic correctness. The current methodology therefore rejects them for safety.

The checks are intentionally stricter than a complete compiler dependence analysis would be. Some transformations that are legal in theory may be rejected by the framework. This is an acceptable trade-off for the current artifact because preserving program semantics is more important than maximizing the number of transformed loops.

The current checks operate only inside the selected loop nest. For loop fusion, the framework considers adjacent loops, because fusion is only meaningful when the loops can be merged without moving unrelated code across the new loop boundary. Procedure calls, I/O statements, and pointer-like constructs were not handled with specific legality rules because they did not appear in the benchmark cases used for this work. In future work, these constructs should be treated conservatively as possible side effects unless more precise information is available.

The following pseudocode summarizes the conservative legality strategy.

```text
Algorithm 5.2: Conservative legality checking

Input:
  candidate       - loop or loop nest selected for transformation
  transformation  - requested transformation kind

Output:
  true if the candidate is considered safe, false otherwise

procedure PASSES_LEGALITY_CHECKS(candidate, transformation):
    if candidate contains an unsupported loop shape then
        return false
    end if

    reads, writes = COLLECT_ARRAY_READS_AND_WRITES(candidate)
    scalars       = COLLECT_SCALAR_DEFINITIONS_AND_USES(candidate)

    if DETECTS_REDUCTION_PATTERN(candidate, reads, writes) then
        return false
    end if

    if DETECTS_UNSAFE_ARRAY_DEPENDENCE(candidate, reads, writes) then
        return false
    end if

    if DETECTS_UNSAFE_SCALAR_DEPENDENCE(candidate, scalars) then
        return false
    end if

    if transformation requires rectangular bounds
       and candidate contains triangular or variable-dependent bounds then
        return false
    end if

    return true
end procedure
```

This rule-based design matches the practical goal of the dissertation. The objective is not to prove every possible legal transformation. The objective is to provide a safe and understandable transformation mechanism that can be used, inspected, and extended.

### 5.2.4 Transformation-specific design choices

Each transformation has its own structural requirements.

Loop interchange is applied to two perfectly nested loops. The transformation swaps the loop headers and preserves the original body inside the new nesting order. Candidate loops with triangular bounds are rejected because the inner bound may refer to the outer iterator. If the loops were interchanged, that variable could become unavailable or could change meaning. The method also rejects cases where deeper nested loops depend on the original outer variable in a way that may change the order of updates.

Loop fusion is applied to adjacent loops with the same iteration structure. The framework checks that the iterator, lower bound, upper bound, and step are compatible. The bodies of the two loops are then merged into one loop. Fusion is rejected when an array written in the first loop may be read in the second loop before the write is complete, or when a transposed subscript pattern suggests a cross-iteration dependency.

Loop fission is applied to loops that contain more than one independent statement or statement group. The method creates separate loops with the same iterator and bounds. It is rejected when a scalar temporary is written by an earlier statement and read by a later statement in the same iteration, or when a later statement writes an array that an earlier statement reads in a later iteration. These cases can change the order of data flow after fission.

Loop tiling is applied to two nested loops with bounds that can be safely blocked. The method introduces tile loops and point loops. Boundary tiles are handled using `MIN` expressions. Triangular loops and loops where inner bounds depend on outer variables are rejected because the simple rectangular tiling scheme would not preserve the original iteration domain. The tile size used in the evaluation was `32`.

Loop unrolling is applied to innermost loops. The loop body is duplicated according to the unrolling factor, and a remainder loop is generated when the iteration count is not divisible by the factor. The unrolling factor used in the evaluation was `4`.

## 5.3 Benchmark Selection

The evaluation used the full PolyBench/Fortran benchmark suite. PolyBench/Fortran was selected because it contains compact scientific kernels with many array-based computations and nested loops. These properties make it suitable for evaluating loop transformations. The suite also provides a consistent structure for building and running kernels, which is useful when comparing original and transformed programs.

The benchmark choice was also practical. The goal of the dissertation was to build and validate the transformation artifact, not to perform a broad benchmark survey across many application domains. PolyBench/Fortran was available, manageable within the project time, and representative of the kinds of loop-heavy kernels that motivate source-to-source transformation.

The main selection criteria were:

- the benchmark should contain Fortran `DO` loops;
- the benchmark should contain array-intensive computation;
- the benchmark should include loop nests that are realistic for scientific computing;
- the benchmark should be small enough to support repeated transformation and debugging;
- the benchmark should provide output data that can be compared between original and transformed versions.

No additional benchmark suite was evaluated. The full PolyBench/Fortran suite was used as the input set, but not every benchmark necessarily provided legal candidates for every transformation. In such cases, the benchmark was not removed from the methodology. Instead, the transformation was considered rejected or not applicable for that specific loop structure. This is important for measuring transformation success rate, because rejection is part of the behavior of a conservative transformation tool.

Before transformation, the benchmark sources were preprocessed to reduce macro interference. This preprocessing step was necessary because the transformation framework operates on the Fortran structure produced by the parsing pipeline. Macros can obscure the actual loop structure and make AST construction or source regeneration less direct. The preprocessing step therefore made the benchmark code more suitable for source-to-source transformation while preserving its computational content.

Two dataset sizes were used. The small dataset was used for correctness validation. This made output comparison faster and simplified debugging when a transformation was rejected or produced unexpected behavior. The large dataset was used for performance evaluation. This allowed the transformed kernels to run long enough for loop transformations to have a measurable effect.

## 5.4 Experimental Setup

The experimental setup was designed to test whether the transformed programs could be generated, compiled, executed, and compared against the original versions. The focus was on transformation feasibility and observable performance behavior, not on producing a statistically complete benchmarking study.

### 5.4.1 Hardware environment

The experiments were executed on a machine with the following hardware characteristics.

| Component | Configuration |
| --- | --- |
| Processor | Intel Xeon E5-2630 v3, Haswell-EP |
| Sockets and cores | 2 sockets, 8 cores per socket, 16 physical cores total |
| Base frequency | 2.40 GHz |
| Turbo Boost | Disabled |
| L1 cache | 64 KiB per core |
| L2 cache | 256 KiB per core |
| L3 cache | 40 MiB total, 2 x 20 MiB shared per socket |
| NUMA configuration | 2 NUMA nodes |
| Operating system | Ubuntu 26 |

Turbo Boost was disabled to reduce one source of frequency variation. The machine was not guaranteed to be completely idle during all executions. For this reason, the performance results should be interpreted as indicative measurements of transformation behavior rather than as a full statistical performance study.

### 5.4.2 Software environment

The software environment consisted of the METAFOR toolchain and the Flang22 compiler infrastructure.

| Software component | Role in the methodology |
| --- | --- |
| Flang22 | Parses Fortran source code and supports the dumping stage. |
| `flang-dumper` plugin | Extracts Fortran node information into a JSON-based intermediate representation. |
| Java AST representation | Builds and stores the program structure used by METAFOR. |
| METAFOR weaver | Provides the infrastructure for AST traversal and modification. |
| Fortran-JS / Node.js | Exposes transformation operations to user scripts. |
| Java | Supports the AST and weaver components. |

The `flang-dumper` plugin was modified as part of this work to expose missing properties that were necessary for building the AST and transforming `DO` loops. The transformation algorithms themselves were implemented in the Fortran-JS module, so that they can be used as built-in features by METAFOR users. Code generation was also part of the work. After the AST was modified, each node generated its corresponding Fortran source representation.

All original and transformed benchmark programs were compiled with Flang22 using the same optimization level. The `-O3` flag was used for both versions. This ensured that performance comparisons were not biased by different compiler optimization settings.

### 5.4.3 Experimental procedure

The same basic procedure was followed for each benchmark and transformation.

```text
Algorithm 5.3: Experimental procedure

For each benchmark in the PolyBench/Fortran suite:
    1. Preprocess the source code to remove macro interference.
    2. Compile and run the original program on the small dataset.
    3. Save the original array dump for correctness validation.
    4. Select a target region for transformation.
    5. Apply one requested loop transformation through METAFOR.
    6. Generate the transformed Fortran source code.
    7. Compile the transformed program with Flang22 and -O3.
    8. Run the transformed program on the small dataset.
    9. Compare the transformed array dump with the original array dump.
   10. If validation succeeds, run the original and transformed versions on the large dataset.
   11. Record the PolyBench kernel execution time.
   12. Compute speedup and transformation success information.
```

Each transformation was evaluated independently. The framework is able to support transformation pipelines, but automatic pipelines were not part of the experiment. This choice made the results easier to interpret, because the effect of each transformation could be considered separately.

The final reported value for a benchmark configuration corresponds to the best valid kernel execution time recorded for that configuration. In the final experiment, each configuration was run once as the main measurement. Repeated execution, warm-up removal, and outlier filtering were not the main concern of this methodology. This decision reflects the artifact-oriented focus of the dissertation. The performance measurements show whether the generated code behaves reasonably and whether transformations can improve or degrade execution time, but they should not be read as a complete statistical performance analysis.

Only kernel execution time was measured. This timing was already available through the PolyBench infrastructure. Full program execution time was not used because it would include setup, allocation, input/output, and other costs that are less directly related to loop transformation.

## 5.5 Correctness Validation

Correctness validation was performed before performance evaluation. A transformed benchmark was included in performance results only if it compiled successfully and produced the expected output on the small dataset.

The validation procedure used array dump comparison. First, the original benchmark was executed on the small dataset and its output arrays were saved. Then, the transformed version was compiled and executed using the same dataset. The array dump produced by the transformed version was compared with the original dump. If the outputs matched according to the comparison procedure, the transformation was treated as correct for that benchmark case.

The validation criteria were:

1. The transformed program must compile successfully.
2. The transformed program must execute without runtime failure.
3. The transformed array dump must match the original array dump on the small dataset.
4. If the framework determines that a transformation is unsafe, the transformation must be rejected rather than applied.

No separate tolerance-based comparison mechanism was introduced in the transformation framework. The validation relied on comparing the array dumps produced by the benchmark runs. This is acceptable for the current artifact because reductions and other numerically sensitive dependency patterns were rejected for safety. However, future work that supports more aggressive transformations should define an explicit floating-point tolerance policy.

Illegal or unsupported transformations were reported as not applied. This behavior is part of the correctness methodology. A rejected transformation is preferable to a transformation that generates incorrect code. The framework therefore follows a conservative principle: when the implemented checks cannot establish that a transformation is safe, the original loop is preserved.

Some transformed programs were also inspected manually. Manual inspection was useful during development because source-to-source transformation produces readable Fortran code. This is one of the advantages of the approach. It allows the developer to check whether the transformation result is understandable and whether the structure matches the intended rewrite.

Correctness validation was especially important for transformations that change execution order. Loop interchange and loop tiling can change the order in which iteration pairs are visited. Loop fusion and loop fission can change the relative order of statements across iterations. Loop unrolling duplicates the body and modifies index expressions. In all cases, the legality checks and output comparison were used together: legality checks prevented obvious unsafe rewrites, and output comparison checked the behavior of the generated program.

## 5.6 Performance Evaluation

Performance evaluation was used to study the practical effect of the generated transformations. The evaluation was not designed to prove that every transformation improves execution time. In fact, not every legal loop transformation is profitable. A transformation may preserve correctness and still lead to worse performance because of cache behavior, register pressure, code size, or interactions with compiler optimizations.

The main metrics were execution time, speedup, transformation success rate, and comparison with an OpenMP-based tiling alternative where applicable.

Execution time was measured using the kernel timing already included in the benchmark infrastructure. The original program and the transformed program were both compiled with Flang22 using `-O3`. The same large dataset was used for the original and transformed versions.

Speedup was computed as:

```text
Speedup = T_original / T_transformed
```

where `T_original` is the execution time of the original benchmark kernel and `T_transformed` is the execution time of the transformed benchmark kernel. A speedup greater than `1.0` means that the transformed version was faster. A value below `1.0` means that the transformed version was slower.

Transformation success rate was used to describe how often the framework could apply a requested transformation and produce a valid result. It can be expressed as:

```text
Success Rate = N_successful / N_requested
```

where `N_requested` is the number of transformation attempts and `N_successful` is the number of attempts that produced transformed code that compiled and passed correctness validation.

The results were intended to be analyzed in two ways. First, they can be grouped by transformation type. This shows which transformations were more often applicable and which ones produced better performance behavior. Second, they can be grouped by benchmark. This shows which benchmark kernels are more suitable for source-to-source transformation.

Loop fusion can improve performance when adjacent loops access related data and can benefit from reduced loop overhead or improved locality. However, fusion can also increase the size of the loop body and create more register pressure. For this reason, the methodology does not assume that fusion is always profitable.

Loop fission can simplify loop bodies and may expose opportunities for later vectorization or parallelization. At the same time, it may reduce temporal locality because data used by adjacent statements in the original loop may be accessed in separate loop passes after fission.

Loop interchange is especially relevant for multidimensional arrays. Since Fortran uses column-major array layout, memory locality often depends on which index changes fastest in the innermost loop. Interchange can improve access order when it moves the more locality-friendly iterator to the inner loop. It can also reduce performance if it disrupts a useful access pattern or prevents the compiler from applying another optimization.

Loop tiling is intended to improve cache reuse by executing blocks of the iteration space before moving to the next block. The tile size used in this work was `32`. Tiling was also compared with an OpenMP-based tiling alternative where applicable, because this gives a useful reference point for source-to-source transformation. The comparison is not only about raw performance. It also shows the difference between an explicit transformed source code approach and a directive-based or compiler-supported approach.

Loop unrolling with factor `4` was used to reduce loop control overhead and expose more straight-line computation to the compiler. It may improve performance for simple innermost loops, but it can also increase code size and register usage. Therefore, unrolling results must be interpreted per benchmark rather than as a universally beneficial transformation.

The performance methodology has several limitations. The experiment used one compiler, Flang22, and one optimization level, `-O3`. The machine was not fully isolated from other activity. The final measurements did not include a full repeated-run statistical analysis. The framework also did not perform automatic parameter search, so the selected tile size and unrolling factor may not be optimal for every benchmark. These limitations are acceptable for the main goal of the dissertation, which is to demonstrate feasibility and controllability of source-to-source loop transformations in METAFOR.

The most important methodological point is that performance is treated as evidence of practical usefulness, not as the only measure of success. The artifact is designed to make transformations explicit, inspectable, and adjustable. This makes it useful as a foundation for future work on automatic tuning, parallelization, and more complete dependence analysis.

## 5.7 Summary

This chapter presented the methodology used to build and evaluate source-to-source loop transformation support for Fortran in METAFOR. The research followed an artifact-oriented approach and focused on practical engineering decisions. The framework allows users to request specific transformations on selected program regions, while conservative legality checks protect program correctness.

The evaluation used the full PolyBench/Fortran benchmark suite. Correctness was checked on small datasets by comparing array dumps, and performance was measured on large datasets using kernel execution time. The main metrics were speedup, transformation success rate, and comparison with an OpenMP-based tiling alternative where applicable.

The methodology deliberately favors transparency and safety over aggressive automation. Transformations are not selected automatically by the framework, and uncertain cases are rejected. This makes the current approach more conservative than a complete optimizing compiler, but it also makes the transformation process easier to understand, inspect, and control. As a result, the work provides a foundation for future extensions, including stronger legality analysis, additional loop transformations, automatic parameter tuning, and transformation pipelines for larger Fortran projects.
