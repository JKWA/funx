# Maybe

## Structure

A `maybe` block compiles to a struct containing the pipeline input, ordered steps, return mode (`:maybe`, `:nil`, or `:raise`), and user-supplied options. This struct is the complete representation of the DSL expression and is what the executor receives at runtime.

## Steps

The Maybe DSL uses a small set of step types, each represented by its own struct:

* `Step.Bind`
* `Step.Map`
* `Step.Ap`
* `Step.MaybeFunction`
* `Step.ProtocolFunction`

Each step describes a single operation. The executor pattern-matches on these structs to determine how the pipeline proceeds.

```text
Pipeline
    ├── Step.Bind
    ├── Step.Map
    ├── Step.Ap
    ├── Step.MaybeFunction
    └── Step.ProtocolFunction
```

## Parser

The parser converts the DSL block into a step list. It applies the Maybe DSL's lifting rules (turning call forms into unary functions), expands module aliases, validates operations, and raises compile-time errors for unsupported syntax. The parser produces the final step list that appears in the compiled struct.

## Transformers

Transformers run during compilation and may rewrite the step list before it is finalized. They can add, remove, or rearrange steps. A transformer must return a valid list of Maybe step structs and introduces a compile-time dependency for modules that use it.

## Execution

The executor evaluates steps in order:

* `Step.Bind` unpacks the current Maybe value, calls the operation, and normalizes its return into Maybe (accepting Maybe, Either, result tuples, or nil).
* `Step.Map` applies a pure function to the inner value.
* `Step.Ap` applies an applicative function contained in a Maybe.
* `Step.MaybeFunction` calls a built-in Maybe operation such as `or_else`.
* `Step.ProtocolFunction` calls a protocol operation such as `tap` (Funx.Tappable), `filter`, `filter_map`, or `guard` (Funx.Filterable).

A `Nothing` value stops the pipeline immediately. The return mode controls how the final result is wrapped (`:maybe` returns the Maybe struct, `:nil` unwraps to the value or nil, `:raise` unwraps or raises an error).

## Behaviours

Modules participating in the Maybe DSL implement `Funx.Monad.Maybe.Dsl.Behaviour`. The executor calls `run/3` on these modules. The DSL determines whether the result is interpreted as a bindable value (returning Maybe, Either, result tuple, or nil) or a mapped value (returning a plain value). The executor only invokes the callback and applies the step semantics.
