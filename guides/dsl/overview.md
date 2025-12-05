# Overview

## Structure

A Funx DSL block compiles to a single struct that contains an ordered list of steps. This struct is the complete representation of the DSL expression and is what the executor receives at runtime.

```text
Compilation
    ├── DSL Block (AST)
    ├── Parser
    │     └── Builds step list
    ├── Transformers
    │     └── Optional rewrites
    ├── Compiled Struct
    └── Executor
          └── Runs the steps
```

## Steps

Each DSL defines its own set of step types. Every step is a struct that describes one operation in the pipeline. The executor pattern-matches on these structs to determine how each step should run.

```text
Pipeline
    ├── Step
    ├── Step
    ├── Step
    └── Step
```

## Parser

Each DSL provides its own parser. The parser converts the DSL block into a list of steps, applies lifting and alias-expansion rules, and raises compile-time errors for invalid or unsupported forms.

## Transformers

Transformers run during compilation and may rewrite the step list before it is finalized. They can insert, remove, or modify steps. A transformer must return a valid list of steps for that DSL and introduces a compile-time dependency.

## Execution

Each DSL has a dedicated executor. The executor receives the compiled struct and evaluates the steps in order. It does not inspect source code; it operates only on the compiled representation.

## Behaviours

Each DSL defines a behaviour for modules that participate in the DSL. Modules implementing this behaviour supply the callback the executor invokes for a step. The DSL determines how the callback’s return value is interpreted.
