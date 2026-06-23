# Background \label{chap:background}

## Introduction

This chapter introduces the main concepts needed to understand the work presented in this dissertation. The dissertation is concerned with source-to-source compilation of Fortran programs, with a particular focus on loop transformations. The goal is not only to improve program performance, but also to make loop optimization more explicit, adjustable, and visible to the developer.

Loop transformations are widely used in optimizing compilers, high-performance computing tools, domain-specific languages, and source-to-source transformation systems. However, the way these transformations are selected and applied is often hidden inside the compiler or tied to a particular programming model. This creates difficulties when developers want to control optimization decisions for large scientific programs. For this reason, the background chapter first discusses Fortran and scientific computing, then introduces source-to-source compilation, abstract syntax trees, loop transformations, and legality checking.

## Fortran in Scientific and High-Performance Computing

Fortran remains important in scientific and high-performance computing because many numerical applications are written around arrays, loops, and long-running computational kernels. It is often associated with legacy software, but this view is incomplete. A large amount of existing scientific software has been developed in Fortran over many years, and modern Fortran continues to support structured programming, modules, array operations, and interoperability features. Therefore, Fortran should be understood both as a historical language of scientific computing and as an active language used in current numerical software.

This distinction is relevant for source-to-source transformation. Scientific projects may contain older coding styles, newer Fortran features, or a mixture of both. A transformation tool that targets Fortran should therefore avoid being limited to one narrow language style. In this dissertation, the benchmark programs are written in a Fortran 90 style, while the broader engineering goal is to support modern Fortran features as the transformation framework evolves.

Fortran is also closely connected with performance-critical loop nests. Many scientific kernels are expressed as `DO` loops over one-dimensional or multi-dimensional arrays. These loops often dominate execution time and are therefore natural candidates for transformation. Optimizing such loops can improve cache locality, reduce loop overhead, expose parallelism, and sometimes help the backend compiler generate better machine code.

One Fortran-specific point that is useful in this context is array layout. Fortran stores multi-dimensional arrays in column-major order, which means that the leftmost subscript varies fastest in memory. As a result, the order of loops may affect memory access locality. This dissertation does not treat array layout as a separate optimization topic, but loop order is still relevant when transformations such as loop interchange or tiling are considered.

## Source-to-Source Compilation

A traditional optimizing compiler transforms source code into a lower-level representation and then into machine code. Many optimizations happen after the original source structure has already been lowered. This approach is powerful, but it also means that the developer usually does not see the exact transformations applied by the compiler.

Source-to-source compilation follows a different model. It takes a source program as input and produces another source program as output. The generated program remains written in a high-level language, such as Fortran, C, or C++. It can then be compiled by a normal compiler. In the context of this dissertation, source-to-source compilation is used to transform Fortran code while preserving a readable source-level representation.

This approach has several practical advantages. First, the transformed code can be inspected, compiled, tested, and compared with the original version. Second, the transformation process can be controlled outside the compiler. Third, the high-level algorithmic source can be kept separate from the transformed source used for performance experiments. This separation is important for software maintenance, because highly optimized code is often harder to read and modify than the original version.

The term source-to-source compilation is related to transpilation and program rewriting, but the terms are not identical in every context. Transpilation often means translating from one programming language to another language at a similar abstraction level. Program rewriting may refer to smaller pattern-based changes applied to text or structured program representations. In this dissertation, source-to-source compilation means structured transformation of Fortran source code into transformed Fortran source code.

## Abstract Syntax Trees and Program Representation

Program transformation can be performed directly on text, but text-based rewriting is fragile for non-trivial changes. It is difficult to reason about nested structures, declarations, expressions, and scopes using plain strings. For this reason, many source-to-source tools use an abstract syntax tree (AST).

An AST represents a program as a tree of structured nodes. A loop, an assignment, a variable reference, a function call, and an expression can each be represented as a node with properties and children. This representation makes it easier to locate program constructs and to rewrite them in a controlled way. For example, a loop transformation can be implemented by finding a `DO` loop node, checking its bounds and body, rewriting the relevant subtree, and then generating source code again from the modified AST.

AST-based rewriting is not automatically simple. The tool still needs accurate parsing, a sufficiently complete representation of language constructs, and a reliable code generation stage. However, it provides a better engineering basis than purely textual rewriting when transformations must preserve program structure and semantics.

## Loops as Optimization Targets

Loops are central in scientific computing because they often express repeated numerical work over arrays. A small change in loop order, loop structure, or loop body may have a noticeable effect on performance. The same source loop can also be a preparation point for later optimizations such as vectorization, parallelization, memory tiling, or accelerator mapping.

Loop transformations should not be understood only as direct performance improvements. In many cases, they are intermediate steps that reshape the program into a form more suitable for another optimization. For example, loop fission may separate independent computations and make parallelization easier. Loop fusion may improve locality by joining operations over the same data. Loop tiling may improve cache reuse. Loop unrolling may reduce loop overhead and expose more instruction-level parallelism. Loop interchange may improve memory access order or enable a later transformation.

At the same time, a legal transformation is not always a profitable transformation. A transformation is legal if it preserves the observable behavior of the program. It is profitable if it improves a chosen metric, such as execution time. Profitability depends on many factors, including memory layout, cache behavior, compiler optimization flags, processor architecture, dataset size, and interactions with other compiler optimizations. Therefore, the role of a transformation framework is not only to perform transformations, but also to make it possible to test, compare, and tune them.

## Basic Loop Transformations

The dissertation focuses on five classical loop transformations: loop fusion, loop fission, loop interchange, loop tiling, and loop unrolling. They are presented here conceptually, without source-level examples, because the implementation details are discussed later.

**Loop fusion** combines two adjacent loops into a single loop. This is useful when two loops iterate over the same range and can be executed together without changing program semantics. Fusion may improve data locality and reduce loop overhead. However, it is only safe when merging the loop bodies does not change the order in which dependent values are produced and consumed.

**Loop fission**, also called loop distribution, splits one loop into two or more loops. It can separate independent computations, simplify loop bodies, and expose opportunities for vectorization or parallelization. It may also reduce register pressure in some cases. However, fission can be unsafe when statements inside the original loop depend on values produced earlier in the same iteration.

**Loop interchange** changes the order of nested loops. It is often used to improve memory locality or to move a more profitable loop to the innermost position. In Fortran programs, this can be important because array layout affects which access pattern is more cache-friendly. Interchange requires careful legality checks, especially when loop bounds or inner computations depend on outer loop variables.

**Loop tiling**, also known as blocking, splits the iteration space into smaller blocks. The main purpose is to improve data reuse by keeping a working set in cache for a longer period. Tiling is especially common for nested loops over arrays. It can also be used as a preparation step for parallel execution. However, tiling requires regular loop bounds and careful handling of boundary tiles.

**Loop unrolling** duplicates the loop body several times and increases the loop step accordingly. This can reduce loop-control overhead and expose more operations to the compiler. It may also help vectorization or instruction scheduling. On the other hand, unrolling can increase code size and does not always improve performance.

## Legality and Dependence Checking

The main difficulty in loop transformation is not changing the syntax of the program. The main difficulty is preserving its meaning. A transformation must respect data dependences between reads and writes. If a transformed loop reads a value before it is computed, or overwrites a value before it is used, the transformed program may compile but produce incorrect results.

Dependence analysis can be complex. A full data dependence analysis may need to reason about array subscripts, loop bounds, aliases, scalar variables, reductions, procedure calls, and control flow. In practical source-to-source transformation systems, a conservative strategy is often used. This means that if the tool cannot prove that a transformation is safe, it rejects the transformation. Such a strategy may reject some transformations that are theoretically legal, but it reduces the risk of producing incorrect code.

The main types of checks relevant to this work are syntactic loop checks, array read/write comparisons, iterator-based subscript checks, scalar dependency checks, and conservative handling of reductions. These checks do not replace a complete compiler dependence analysis. Instead, they provide a practical engineering method for guarding transformations that are applied to common loop structures in scientific benchmarks.

## Transparency and User Control

A central motivation for this dissertation is the need for more transparent and adjustable loop transformation workflows. Modern compilers already perform many optimizations, but their decisions are usually internal. Directives and pragmas allow the programmer to guide the compiler, but the final transformation may still depend on compiler support and implementation choices. Domain-specific languages provide stronger control in some domains, but they often require rewriting existing applications in a new programming model.

Source-to-source transformation offers a different compromise. It can expose the transformation process at the source level, allow transformation scripts to be reused, and make optimization experiments easier to reproduce. Instead of relying only on compiler heuristics, the developer can choose where a transformation should be applied and which parameters should be used. This is especially useful when working with large scientific programs, where domain knowledge and manual tuning may be important.

The background presented in this chapter therefore motivates the state-of-the-art discussion that follows. Existing approaches provide many useful mechanisms for loop optimization, but they differ in transparency, language support, source-code visibility, and the degree of control given to the developer.

# State of the Art \label{chap:state-of-the-art}

## Introduction

This chapter reviews existing approaches related to loop transformation and source-to-source optimization. The aim is not to list every compiler or transformation system, but to identify the main design choices that are relevant to this dissertation. The reviewed work is organized by approach category: optimizing compilers, compiler directives and annotation-based tools, domain-specific languages, rewrite-oriented systems, and scriptable source-to-source transformation tools.

This organization follows the main distinction behind the dissertation. Some systems hide most optimization decisions inside the compiler. Others expose optimization through directives, annotations, schedules, rewrite rules, or scripts. These approaches are not competing in a simple way. Each of them makes a different trade-off between automation, control, portability, and effort required from the developer.

## Optimizing Compilers \label{sec:sota_compiler_opt}

Optimizing compilers represent the traditional approach to automatic performance enhancement. They apply transformations to source code, intermediate representations, or machine-level forms in order to generate efficient executable code. This approach is essential for modern software and remains the default optimization path for most Fortran programs.

However, compiler optimization has natural limits. A compiler must preserve language semantics and remain safe for a wide range of programs. For example, respecting language standards may prevent some transformations of floating-point operations. A compiler may also avoid a transformation when the risk of performance degradation is too high. ~\textcite{chargueraud_optitrust_2022_0014} discuss this point in the context of source-to-source optimization of C code, noting that compilers cannot always apply transformations that are useful from the programmer's point of view.

Another limitation is visibility. The developer may know that the compiler was invoked with an optimization flag such as `-O3`, but the exact sequence of transformations is usually not visible at the source level. This does not make compiler optimization weak or unimportant. It only means that compiler optimization is not always the best tool when the goal is to make transformation decisions explicit, repeatable, and adjustable.

For scientific programs, this is especially relevant because domain knowledge can matter. A developer may know that a particular loop nest is safe to tile, that a certain loop should not be fused, or that a transformation is useful only for a given dataset size or hardware target. In such cases, relying only on compiler heuristics may not provide enough control.

## Compiler Directives, Pragmas, and Annotation-Based Tools \label{sec:sota_pragmas}

Compiler directives and pragmas provide a mechanism for programmers to guide optimization through annotations embedded in the source code. Directives such as OpenMP\footnote{\url{https://www.openmp.org/}} and OpenACC\footnote{\url{https://www.openacc.org/}} have become standard tools for expressing parallelism and optimization hints in HPC applications, particularly for multicore processors and accelerators.

Directive-based programming is attractive because it allows the original language to remain in use. A Fortran or C program can be extended with annotations without being rewritten in a new DSL. This is useful for large scientific codebases. At the same time, directives still depend on compiler support. The annotation describes programmer intent, but the final generated code may differ across compilers and platforms.

### OpenMP 5.x Loop Transformations

OpenMP is most widely known for shared-memory parallel programming, but recent versions also include loop transformation constructs. In OpenMP 5.1 and 5.2, the specification describes loop transformation constructs such as `tile` and `unroll`.\footnote{\url{https://www.openmp.org/spec-html/5.1/openmp.html}}\footnote{\url{https://www.openmp.org/spec-html/5.2/openmp.html}} These constructs allow a developer to express transformations in the source code using standard directives.

For example, the `tile` construct can be used to divide a loop nest into blocks, while the `unroll` construct can request full or partial loop unrolling. These directives make some loop transformations more portable and more explicit than relying only on compiler flags. They also provide an important comparison point for source-to-source transformation tools, because they show that loop transformation is becoming part of mainstream programming models.

The main trade-off is that OpenMP directives are still tied to compiler implementation support and to the syntax allowed by the standard. They are useful when the required transformation fits the directive model. They are less flexible when a developer wants to build a longer custom transformation pipeline, inspect each generated intermediate source version, or apply transformations beyond the directives supported by the compiler.

### Orio

Orio is an extensible annotation-based empirical performance tuning system developed by Albert Hartono, Boyana Norris, and P. Sadayappan ~\parencite{orio_2009_0007}. Its primary mission is to improve both performance and productivity by allowing developers to embed structured annotations directly into source code. These annotations mark code regions and describe low-level performance transformations.

Orio can generate many tuned versions of a computation and empirically evaluate them to select the best-performing version. It supports source-to-source transformations such as loop unrolling, loop tiling, loop permutation, scalar replacement, register tiling, array copy optimization, and OpenMP-based multicore parallelization. For example, a developer can annotate a loop region and allow Orio to explore different tile sizes or unrolling factors.

The workflow starts with annotated C source code. Orio scans the annotations, extracts the marked regions, applies the selected transformation modules, generates optimized code variants, compiles them, and measures their performance. This makes Orio strong for empirical tuning. Its limitation for the present dissertation is that it is primarily centered on C code and annotation-guided search, while the dissertation focuses on controlled source-to-source transformation of Fortran `DO` loops.

### X Language

The X Language is an annotation-based tool designed to support the creation of high-performance code, particularly for matrix-matrix multiplication routines ~\parencite{x_language_2006_0012}. It was designed to represent parameterized programs compactly and to enable empirical search over program versions.

The workflow uses annotated C or C++ programs. A frontend parses the annotated program, builds an abstract syntax tree, identifies loops and directives, and rewrites marked loops into transformation calls. The language supports transformations such as unrolling and strip-mining, and parameters such as tile size or unrolling degree can be explored through empirical search.

The X Language is relevant because it shows an early attempt to make transformations explicit through annotations and transformation rules. Its focus, however, is mainly on C/C++ and on a particular style of parameterized optimization. It demonstrates the value of external control but does not directly address modern Fortran source-to-source loop transformation.

### Scout

Scout is a source-to-source transformation tool designed mainly for SIMD vectorization of C source code ~\parencite{scout_2012_0017}. It targets modern SIMD architectures such as SSE and AVX and aims to provide a configurable vectorizing preprocessor.

Scout uses `#pragma` directives to mark loops for vectorization. Internally, it uses the Clang parser to build an AST, performs transformations on that AST, and rewrites the result back to C code. Its transformations include loop simplification, unrolling, partial vectorization, and generation of SIMD intrinsics. For example, a loop marked with a Scout vectorization pragma can be rewritten into a form that uses target-specific SIMD operations.

Scout is important because it shows how source-to-source transformation can expose architecture-specific optimization while still producing ordinary source code. Its focus is narrower than the focus of this dissertation: it is primarily aimed at SIMD vectorization for C, while the dissertation investigates a broader set of classical loop transformations for Fortran.

## Domain-Specific Languages \label{sec:sota_dsl}

Domain-specific languages provide a different way to improve performance. Instead of transforming an existing program directly, a DSL gives the developer a high-level language designed for a specific problem domain. In HPC, DSLs often separate the mathematical algorithm from the implementation schedule. This can allow the compiler or code generator to apply aggressive optimizations.

The main advantage of DSLs is that they can expose domain structure more clearly than general-purpose languages. The main adoption cost is that existing applications may need to be rewritten. As noted by ~\textcite{hyperf_2025_0013}, many HPC applications contain years of development and expertise in languages such as Fortran. Rewriting them in a new DSL may be too expensive or too risky. This point is also relevant to Loopy and similar systems, where learning a new programming model can be justified for some projects but difficult for maintaining established codebases ~\parencite{rival_loopy_2016_0008}.

### Halide

Halide is a domain-specific language developed for image processing pipelines ~\parencite{halide_2012_0021}. Its main design idea is to separate the algorithm from the schedule. The algorithm describes what is computed, while the schedule describes how it should be executed.

This separation allows the developer to explore different implementation choices without rewriting the algorithm. Halide supports scheduling operations such as tiling, fusion, vectorization, parallelization, and recomputation versus storage. For example, an image-processing pipeline can be written once, and then scheduled differently for CPUs, GPUs, or mobile processors.

Halide is highly successful in its target domain, but it is not designed as a direct transformation tool for existing Fortran programs. It is most useful when the application can be expressed in Halide's functional model. For this reason, it represents a powerful but different approach from Fortran source-to-source transformation.

### Tiramisu

Tiramisu is a polyhedral framework and C++ embedded DSL for generating high-performance code across multicore CPUs, GPUs, and distributed machines ~\parencite{tiramisu_2019_0015}. Like Halide, it separates the algorithm from the schedule, but it targets a wider set of computations, including image processing, deep learning, linear algebra, tensor operations, and stencil computations.

Tiramisu supports affine loop transformations such as tiling, splitting, shifting, fusion, parallelization, vectorization, and mapping to GPU blocks and threads. It uses integer sets and maps, based on the Integer Set Library, to represent iteration domains and transformations. For example, a computation can be expressed in an architecture-independent form, and then scheduled with explicit commands for tiling, communication, and memory placement.

Tiramisu demonstrates the strength of schedule-based optimization. It gives fine-grained control over generated code and can target multiple architectures. However, like other DSL-based systems, it usually requires the computation to be expressed in its own representation. This makes it less direct for developers who need to transform existing Fortran projects without rewriting them.

## Code Transformations via Rewrite Tools \label{sec:sota_rewrite_tools}

Rewrite-oriented systems operate directly on source code representations or intermediate program representations. They apply pattern matching, transformation rules, or optimization patterns to modify the program. This approach can be flexible and can work with existing codebases, depending on the tool and language support.

A natural trade-off is that rewrite systems are often limited by the patterns they can recognize and by the safety conditions they can check. Applying a second transformation round may also be harder if the first transformation changes the source into a form that no longer matches the expected pattern. These are design limitations rather than weaknesses, and they are common in many practical transformation systems.

### EPOD

EPOD, or Extendable Pattern-Oriented Optimization Directives, is a framework for encapsulating algorithm-specific optimizations into optimization patterns ~\parencite{epod_0019}. Its goal is to integrate domain experts' knowledge into general-purpose compilers through pattern-oriented directives and an Optimization Programming Interface.

EPOD supports patterns such as stencils, dense matrix multiplication, dynamically allocated arrays, and compressed arrays. These patterns can trigger loop transformations, data-layout changes, and fine-grained synchronization. For example, the dense matrix multiplication pattern can apply loop fission and peeling after tiling.

The workflow starts with C or Fortran source code annotated using EPOD pragmas. The framework checks whether the controlled region satisfies the conditions for the pattern, normalizes loop nests, analyzes data access patterns, and applies an EPOD script that defines the optimization scheme. EPOD is relevant because it supports both C and Fortran and combines source-to-source translation with pattern-specific knowledge. Its approach is more pattern-oriented than the one investigated in this dissertation, where the emphasis is on explicit control over general loop transformations.

## Scriptable Source-to-Source Transformation Tools \label{sec:sota_scripts}

Scriptable source-to-source compilers use external scripts to describe how transformations should be applied. A script can specify the order of transformations, transformation parameters, and the program locations to be modified. This approach is especially relevant to this dissertation because it separates the original algorithmic code from the transformed version and makes optimization steps easier to inspect and reproduce.

Scriptable transformation also supports experimentation. A developer can apply one transformation script for one target machine and another script for a different target. The same original source can remain unchanged while multiple transformed versions are generated. This is useful in HPC, where hardware changes over time and performance tuning often requires repeated experiments.

### OptiTrust

OptiTrust is an interactive framework for source-to-source transformations of C code ~\parencite{chargueraud_optitrust_2022_0014}. Its main purpose is to make high-performance code development more systematic, reviewable, and maintainable than manual optimization.

OptiTrust uses transformation scripts written in OCaml. The original source code is encoded into an internal AST, and transformations are applied step by step. The framework can visualize textual differences after each transformation, making the optimization process easier to inspect. It supports control-flow transformations such as loop fission, fusion, unrolling, and tiling, as well as data-layout transformations and lower-level rewriting.

OptiTrust is one of the closest conceptual references for this dissertation because it emphasizes transparency and script-based transformation. The main difference is language focus. OptiTrust targets C and parts of C++, while this dissertation is concerned with Fortran source-to-source loop transformation.

### Xevolver

Xevolver is an XML-based code translation framework for HPC application migration and evolution ~\parencite{xevolver_2014_0016}. Its goal is to separate platform-specific optimizations from application code and to allow expert programmers to define custom translation rules.

The workflow parses C or Fortran programs into an AST and exposes the AST as XML. Users then manipulate the XML AST using XSLT-based translation recipes. After transformation, the modified representation is converted back and unparsed into source code. For example, Xevolver can describe transformations such as loop interchange for numerical simulation codes.

Xevolver is relevant because it works with C and Fortran and supports user-defined transformations. Its XML/XSLT representation provides flexibility, but it also requires developers to work with XML-based transformation rules, which can be verbose for complex program rewrites.

### Loopy

Loopy is a Python-based tool for representing and transforming array-based computational kernels ~\parencite{rival_loopy_2016_0008}. It supports fine-grained control over code generation for high-performance computing, especially for GPU and many-core targets.

A Loopy kernel is a symbolic description of a computation. Users apply Python-based transformation instructions to change loop structure, memory mapping, scheduling, and parallelization. Loopy supports transformations such as tiling, unrolling, fusion, permutation, vectorization, and dependency-aware scheduling. It can generate C or OpenCL C code.

Loopy is powerful for programmatic kernel generation and transformation, but it requires computations to be represented in Loopy's own model. For projects that already exist as Fortran source code, this may require a significant adaptation step.

### CHiLL

CHiLL, or Composing High-Level Loop Transformations, is a framework for applying high-level loop transformations through scripts ~\parencite{chen2008chill_0002}. It was designed to support empirical optimization and to provide a robust system for composing loop transformations.

CHiLL supports transformations such as permutation, tiling, unroll-and-jam, data copying, iteration-space splitting, fusion, and distribution. It uses a polyhedral representation of iteration spaces and statements. This allows transformations to be composed without generating intermediate source code after each step.

The system is relevant because it focuses directly on loop transformations and transformation scripts. It also demonstrates the importance of composing transformations in a controlled way. Its polyhedral basis gives it strong analytical power, but the dissertation takes a more engineering-oriented route focused on source-level Fortran transformation and practical AST rewriting.

### ASSIST

ASSIST is a source-to-source transformation tool for HPC applications, integrated into the MAQAO toolset ~\parencite{lebras2017assist_0020}. Its goal is to help application programmers improve productivity and performance by combining source manipulation with static and dynamic profiling information.

ASSIST supports loop transformations such as interchange, unrolling, strip mining, and tiling. It also implements specialization, constant propagation, local dead-code elimination, and block vectorization. The tool can use directives or Lua scripts to specify transformations. It relies on the ROSE compiler infrastructure to parse and manipulate C, C++, and Fortran ASTs.

ASSIST is relevant because it supports Fortran and provides both directive-oriented and script-based transformation mechanisms. Compared with the present dissertation, ASSIST has a broader profiling and performance-engineering context, while the dissertation focuses specifically on implementing and validating a selected set of Fortran loop transformations.

### POET

POET, or Parameterized Source-to-source Program Transformations, is a scripting language for programmable source-to-source transformation ~\parencite{yi_poet_2012_0011}. It was designed to reduce the cost of building ad-hoc translators, code generators, and compiler optimizations.

POET uses external syntax descriptions to parse and unparse code in different languages. It can support C, C++, Java, Fortran, and domain-specific languages. Transformations are defined as `xform` routines and can include pattern matching, AST replacement, and parameterized code generation. POET has been used for loop interchange, parallelization, blocking, fusion/fission, scalar replacement, and vectorization.

POET is relevant because it provides a high degree of language independence and scriptable control. At the same time, the need to define syntax descriptions and transformation scripts makes it a general transformation infrastructure rather than a focused Fortran loop transformation artifact.

## Discussion of the Research Gap

The reviewed approaches show that loop transformations can be supported in many different ways. Optimizing compilers provide automatic transformation but often hide decisions from the developer. Directives and pragmas make some intentions visible, but they still depend on compiler support and the directive model. DSLs provide strong scheduling control but usually require existing programs to be rewritten. Rewrite-oriented systems and source-to-source tools offer more explicit transformation, but they differ in language support, scriptability, and ease of applying transformation pipelines.

The gap addressed by this dissertation is therefore not the absence of loop transformations in general. Many systems already support them. The gap is the need for a Fortran-oriented source-to-source workflow in which loop transformations are transparent, adjustable, and controlled by the user rather than fully hidden inside compiler heuristics. Such a workflow should make it possible to select the program region to transform, choose parameters such as tile size or unrolling factor, inspect the generated source, and evaluate the result against the original program.

The approach investigated in this dissertation is intended to test whether the team's source-to-source transformation direction can cover some of the drawbacks identified in the state of the art. In particular, it aims to combine the source-level visibility of transformation tools with explicit user control over Fortran loop transformations. The goal is not to replace optimizing compilers, DSLs, or directive standards, but to explore a practical engineering path that can make loop transformation of existing Fortran programs more transparent and tunable.

## Comparison Tables

### Compact comparison of approaches

| Approach category | Main control mechanism | Typical strength | Main trade-off relevant to this dissertation |
|---|---|---|---|
| Optimizing compilers | Compiler heuristics and optimization flags | Automatic optimization with little user effort | Transformation decisions are usually hidden from the developer |
| OpenMP/OpenACC directives | Source-level directives and pragmas | Portable way to express parallelism and selected transformations | Limited to constructs supported by the standard and compiler implementation |
| Annotation-based empirical tuning | Structured source annotations and search parameters | Can generate and evaluate many optimized variants | Often centered on empirical search and specific input languages |
| Domain-specific languages | Separate algorithm and schedule in a DSL | Strong optimization model for selected domains | Existing Fortran applications may need to be rewritten |
| Pattern/rewrite tools | Pattern rules, directives, or rewrite recipes | Can encode domain-specific transformations | Limited by recognized patterns and available legality checks |
| Scriptable source-to-source tools | External transformation scripts | Transparent, reproducible, and composable optimization steps | Requires accurate program representation and careful legality checking |

### Detailed comparison of source-level and directive/script-based tools

| Tool or approach | Input language | Transformation control mechanism | Supported loop transformations | Fortran support | Scriptability | Source-to-source output | Transparency of transformations | Manual parameter control | Suitability for existing Fortran codebases | Main strength | Limitation relevant to this dissertation |
|---|---|---|---|---|---|---|---|---|---|---|---|
| OpenMP 5.x loop transformations | C, C++, Fortran | Standard directives such as `tile` and `unroll` | Tiling and unrolling in the standard loop transformation model | Yes | Limited; directives are embedded in source | Compiler-dependent generated code, not mainly source-to-source | Medium; intent is visible, final compiler transformation may not be | Yes, for directive parameters such as tile sizes or unroll factors | High when compiler support is available | Standardized and portable mechanism for selected loop transformations | Less flexible for custom multi-step transformation pipelines |
| OpenACC | C, C++, Fortran | Directives for accelerator programming | Mainly parallelism and accelerator mapping rather than general loop rewriting | Yes | Limited; directive-based | Compiler-dependent generated code | Medium | Some parameter control through clauses | High for accelerator-oriented projects | Practical path to accelerator execution without full rewrite | Not primarily a general loop transformation framework |
| Orio | Primarily C; future Fortran support discussed | Structured annotations and empirical search | Unrolling, tiling, permutation, unroll/jam, scalar replacement, register tiling | Limited in the described system | Yes, through annotations and tuning parameters | Yes | High for annotated regions and generated variants | High; explores parameter values empirically | Limited for direct Fortran transformation | Strong empirical tuning and variant generation | Primarily C-focused and search-oriented |
| X Language | C/C++ | Pragmas, transformation directives, pattern rewriting, macro language | Unrolling, strip-mining, scalarization, parameterized transformations | No direct Fortran focus | Yes, through transformation descriptions | Yes | Medium to high | High; supports empirical parameter search | Low | Compact representation of parameterized optimized programs | Focused mainly on C/C++ and selected optimization styles |
| Scout | C | Pragmas and configurable AST-based transformation | Unrolling, loop simplification, partial vectorization, SIMD-oriented rewrites | No | Configuration-based, not general transformation scripting | Yes | Medium; vectorization is explicitly requested | Some, through configuration | Low | Strong source-to-source SIMD vectorization for C | Narrower focus than general loop transformation |
| EPOD | C and Fortran | Pattern-oriented directives and EPOD scripts | Pattern-specific transformations including tiling, fission, peeling, layout changes | Yes | Yes, through EPOD scripts | Yes | Medium to high | Yes, depending on pattern scripts | Medium to high | Encodes domain-specific optimization knowledge | More pattern-oriented than general user-selected loop transformation |
| OptiTrust | C and some C++ features | OCaml transformation scripts | Fission, fusion, unrolling, tiling, data-layout transformations | No | Yes | Yes | High; supports step-by-step diffs | High | Low for direct Fortran use | Very strong transparency and reviewability of optimization scripts | Does not target Fortran |
| Xevolver | C and Fortran | XML AST and XSLT translation recipes | User-defined rewrites, including loop interchange examples | Yes | Yes, through XSLT recipes | Yes | High, but through XML representation | Yes, if encoded in recipes | Medium | Separates platform-specific translations from application code | XML/XSLT can be verbose for complex transformations |
| Loopy | Kernel representation in Python; generates C/OpenCL C | Python API and embedded transformation language | Tiling, unrolling, fusion, permutation, vectorization, scheduling | Not direct Fortran source transformation | Yes | Yes, generates C/OpenCL C | High within Loopy's kernel model | High | Low to medium; requires representing kernels in Loopy | Powerful programmable control of generated kernels | Existing Fortran code must be adapted to another model |
| CHiLL | Primarily loop-oriented source representations | High-level transformation scripts over polyhedral representation | Permutation, tiling, unroll-and-jam, splitting, fusion, distribution | Related to Fortran loop transformation contexts | Yes | Yes | High at transformation-script level | High | Medium | Strong composition of high-level loop transformations | Requires polyhedral-style representation and constraints |
| ASSIST | C, C++, Fortran | Directives or Lua scripts over ROSE AST | Interchange, unroll, strip mine, tile, specialization, vectorization support | Yes | Yes | Yes | Medium to high | Yes | High | Combines source transformation with profiling information | Broader performance-engineering tool, not only focused on loop transformation artifact design |
| POET | C, C++, Java, Fortran, DSLs | POET transformation scripts and syntax descriptions | Interchange, blocking, fusion/fission, parallelization, scalar replacement, vectorization | Yes | Yes | Yes | High for scripted transformations | High | Medium to high | Language-neutral programmable transformation framework | Requires syntax descriptions and general transformation infrastructure |

### Separate comparison of DSL-based systems

| Tool | Host or input model | Main control mechanism | Supported optimization style | Source-to-source relation | Main strength | Main trade-off for existing Fortran projects |
|---|---|---|---|---|---|---|
| Halide | C++ embedded DSL for image-processing pipelines | Separation of algorithm and schedule | Tiling, fusion, vectorization, parallelization, storage/recomputation decisions | Generates optimized lower-level code from DSL representation | Very strong schedule control for image-processing pipelines | Existing Fortran code must be rewritten into Halide's model |
| Tiramisu | C++ embedded DSL with polyhedral representation | Scheduling commands over iteration domains and buffers | Tiling, splitting, fusion, shifting, vectorization, parallelization, GPU mapping, communication | Generates optimized backend code, including LLVM IR and CUDA paths | Fine-grained control for complex data-parallel computations | Existing Fortran code must be expressed in Tiramisu's representation |
