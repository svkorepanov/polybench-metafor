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
