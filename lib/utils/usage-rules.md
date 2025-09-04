# `Funx.Utils` Usage Rules

## Quick Reference

* Use `curry_r/1` to curry functions right-to-left—ideal for Elixir’s `|>` pipe style.
* Use `curry/1` or `curry_l/1` to curry left-to-right when needed.
* Use `flip/1` to reverse arguments in binary functions.
* All currying functions adapt to any arity and return nested unary functions.

## Overview

`Funx.Utils` provides functional utilities for reshaping multi-argument functions to support composition, partial application, and point-free style.
Use `curry_r/1` by default—it aligns with Elixir’s `|>` operator by shifting configuration to the right and leaving the data position first.

These tools are especially useful with predicates, monads, and other combinators where composition and reuse are key.

## Composition Rules

| Function    | Description                                                  |
| ----------- | ------------------------------------------------------------ |
| `curry_r/1` | Curries a function right-to-left (recommended for pipelines) |
| `curry/1`   | Curries left-to-right                                        |
| `curry_l/1` | Alias for `curry/1`, makes intent explicit                   |
| `flip/1`    | Reverses arguments of a binary function                      |

Each function returns a chain of unary functions that accumulate arguments until fully applied.

## Usage Patterns

### Right-to-Left Currying for Pipelines

```elixir
f = fn prefix, name -> prefix <> name end
greet = curry_r(f).("Hello, ")
"Alice" |> greet()
# => "Hello, Alice"
```

### Flip for Reordering Binary Functions

```elixir
div = fn a, b -> a / b end
flipped = flip(div)
flipped.(2, 10)  # => 5.0
```

### Left-to-Right Currying (Less Common)

```elixir
sum = curry(fn a, b, c -> a + b + c end)
sum.(1).(2).(3)  # => 6
```

## Guidelines for Composition

Follow these patterns when reshaping or generating function transformations:

* Prefer `curry_r/1` for functions that appear in pipelines.
* Use `flip/1` when argument order doesn’t match surrounding context.
* Use `curry/1` or `curry_l/1` when left-to-right application is more natural.
* Avoid manual `fn` nesting—use the provided helpers instead.
* Avoid fixed-arity assumptions—currying adapts dynamically.
* Avoid capture syntax (`&mod.fun/arity`) when partial application is needed.
  Capture locks arity and order, and cannot be curried or reordered.

Currying is often most useful when composed with lifted combinators like `map`, `bind`, `filter`, and so on.

## Stability Contract

Ensure that generated or transformed functions preserve:

* Purity — returned functions are referentially transparent.
* Laziness — arguments are applied only when provided.
* Equivalence — full application matches the original function:

```elixir
curry_r(f).(b).(a) == f.(a, b)
```

## Anti-Patterns

Avoid generating or emitting:

* Manual currying via nested `fn` chains: `fn a -> fn b -> f.(a, b) end end`
* Fixed-arity assumptions that break with dynamic currying
* Argument reordering by hand—prefer `flip/1`
* Full application immediately after currying
* Capture syntax (`&fun/2`) when transformation is required

## Good Patterns

Encourage completions like:

```elixir
# Partial right-to-left application for pipelines
assign_role = curry_r(fn role, user -> %{user | role: role} end)
user |> assign_role.("admin")
```

```elixir
# Flipping to enable higher-order composition
compare = flip(fn a, b -> a > b end)
Enum.filter(list, compare.(10))
```

```elixir
# Contextual function with partial application
transform =
  curry_r(fn format, name -> format.("<" <> name <> ">") end)
"Alex" |> transform.(&String.upcase/1)
```

## When to Use

Reach for these utilities when you want to:

* Enable point-free style
* Compose partial functions within a pipeline
* Shift configuration before data
* Adapt argument order to match surrounding combinators
* Prepare functions before lifting into a monadic or applicative context

## Built-in Behavior

* `curry_r/1`, `curry/1`, and `curry_l/1` inspect function arity via `:erlang.fun_info/2`.
* Returned functions accumulate arguments until fully applied.
* `flip/1` applies only to functions of arity 2.
