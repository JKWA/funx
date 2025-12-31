# Either

The Either DSL is a pipeline DSL that executes a sequence of operations on an input value. See the [DSL Overview](overview.md) for the distinction between builder and pipeline DSLs.

## Structure

An `either` block compiles to a struct containing the pipeline input, ordered steps, return mode (`:either`, `:tuple`, or `:raise`), and user-supplied options. This struct is the complete representation of the DSL expression and is what the executor receives at runtime.

## Steps

The Either DSL uses a small set of step types, each represented by its own struct:

* `Step.Bind`
* `Step.Map`
* `Step.Ap`
* `Step.EitherFunction`
* `Step.BindableFunction` (used by `validate`)

Each step describes a single operation. The executor pattern-matches on these structs to determine how the pipeline proceeds.

```text
Pipeline
    ├── Step.Bind
    ├── Step.Map
    ├── Step.EitherFunction
    └── Step.Ap
```

## Parser

The parser converts the DSL block into a step list. It applies the Either DSL’s lifting rules (turning call forms into unary functions), expands module aliases, validates operations, and raises compile-time errors for unsupported syntax. The parser produces the final step list that appears in the compiled struct.

## Transformers

Transformers run during compilation and may rewrite the step list before it is finalized. They can add, remove, or rearrange steps. A transformer must return a valid list of Either step structs and introduces a compile-time dependency for modules that use it.

## Execution

The executor evaluates steps in order:

* `Step.Bind` unpacks the current Either value, calls the operation, and normalizes its return into Either.
* `Step.Map` applies a pure function to the inner value.
* `Step.Ap` applies an applicative function contained in an Either.
* `Step.EitherFunction` calls a built-in Either operation such as `filter_or_else`, `or_else`, `map_left`, `flip`, or `tap`.
* `Step.BindableFunction` wraps functions like `validate`, which accumulate errors instead of short-circuiting.

Except for validation, a `Left` value stops the pipeline immediately. The return mode controls how the final result is wrapped.

## Behaviours

Modules participating in the Either DSL implement `Funx.Monad.Either.Dsl.Behaviour`. The executor calls `run/3` on these modules. The DSL determines whether the result is interpreted as a bindable value, a mapped value, or a result to be normalized. The executor only invokes the callback and applies the step semantics.
