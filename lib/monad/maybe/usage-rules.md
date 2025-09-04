# `Funx.Monad.Maybe` Usage Rules

## Quick Reference

### Construction

* `just/1` – Wraps a present value. Raises on `nil`.
* `nothing/0` – Represents absence.
* `pure/1` – Alias for `just/1`.

### Monadic Composition

*(via `Funx.Monad` protocol)*

* `map/2` – Transforms a present value; preserves `Maybe` structure.
* `bind/2` – Chains context-aware steps; skips if `Nothing`.
* `ap/2` – Applies a function in context to a value in context.

### Refinement & Queries

* `just?/1`, `nothing?/1` – Pattern-aware checks.
* `to_predicate/1` – Converts to boolean presence.

### Fallback

* `get_or_else/2` – Extracts or defaults.
* `or_else/2` – Substitutes with fallback `Maybe`.

### Lists

* `concat/1` – Keeps present values.
* `concat_map/2` – Filters and maps to `Just`.
* `sequence/1` – Combines if all are present.
* `traverse/2` – Applies function, stops on first `Nothing`.

### Lifting

* `lift_predicate/2` – Conditional construction.
* `lift_identity/1`, `lift_either/1` – Interop with other monads.
* `lift_eq/1`, `lift_ord/1` – Lifts `Eq` and `Ord` logic.

### Elixir Interop

* `from_nil/1`, `to_nil/1`
* `from_result/1`, `to_result/1`
* `from_try/1`, `to_try!/2`

Implements `Monad`, `Eq`, `Ord`, `Foldable`, `Filterable`, `String.Chars`, and `Summarizable`.

---

## Overview

The `Maybe` monad represents optional presence.
It models the difference between “something” and “nothing” using two variants:

* `Just(value)` — present and usable
* `Nothing` — absent, incomplete, or failed

`Maybe` provides declarative control flow.
It avoids manual branching (`if`, `case`, `with`) by composing steps that only run if data is present.

## When to Use It

| Problem                          | Use `Maybe` to…                           |
| -----------------------------| --------------------------------------|
| You receive `nil` from a library | Make absence explicit and pipe-safe       |
| A function may fail to produce   | Return `Nothing` instead of raising       |
| A value may be incomplete        | Encode presence at the type level         |
| You want conditional composition | Use `bind/2` to skip steps on `Nothing`   |
| You need a fallback              | Use `get_or_else/2` or `or_else/2`        |
| You’re transforming optional     | Use `map/2` to preserve structure         |
| You’re combining optional values | Use `ap/2`, `sequence/1`, or `traverse/2` |

Think of `Maybe` as a guardrail that wraps a computation.
Each operation either continues or short-circuits, but the structure (`Just` or `Nothing`) is preserved until explicitly extracted.

## Monadic Control

These functions are dispatched via the `Funx.Monad` protocol:

### `map/2`

Transforms the contents of a `Just`.
Preserves the `Maybe` structure.
Does nothing if the value is `Nothing`.

```elixir
map(just(2), fn x -> x + 1 end)     # => Just(3)
map(nothing(), fn x -> x + 1 end)  # => Nothing
```

### `bind/2`

Chains a Kleisli function, one that takes a value and returns a `Maybe`.
Used to sequence steps that might fail or skip.

```elixir
just(2)
|> bind(fn x -> just(x + 1) end)
|> bind(fn x -> just(x * 2) end)
# => Just(6)
```

### `ap/2`

Applies a wrapped function to a wrapped value.

```elixir
pure(fn x -> x * 10 end)
|> ap(just(2))      # => Just(20)
```

---

## Fallbacks

### `get_or_else/2`

```elixir
get_or_else(just("ok"), "fallback")    # => "ok"
get_or_else(nothing(), "fallback")     # => "fallback"
```

### `or_else/2`

```elixir
or_else(just("ok"), fn -> just("alt") end)    # => Just("ok")
or_else(nothing(), fn -> just("alt") end)     # => Just("alt")
```

## Filtering

### `filter/2`

Keeps `Just` if it passes the predicate; else becomes `Nothing`.

```elixir
filter(just(5), fn x -> x > 3 end)   # => Just(5)
filter(just(2), fn x -> x > 3 end)   # => Nothing
```

### `guard/2`

Keeps `Just` if boolean is true.

```elixir
guard(just("go"), true)    # => Just("go")
guard(just("go"), false)   # => Nothing
```

## List Composition

Use `Maybe` to represent failure or emptiness across a list:

```elixir
sequence([just(1), just(2)])    # => Just([1, 2])
sequence([just(1), nothing()])  # => Nothing

traverse([1, 2], fn x -> just(x + 1) end)
# => Just([2, 3])
```

## Lifting from Other Contexts

These functions convert other values into the `Maybe` domain:

```elixir
from_nil(nil)        # => Nothing
from_nil("hi")       # => Just("hi")

lift_identity(Identity.pure(42))     # => Just(42)
lift_identity(Identity.pure(nil))    # => Nothing
```

## Interop with Other Types

| From                 | To `Maybe`          |
| -----------------| ----------------|
| `nil`                | `Nothing`           |
| `{:ok, val}`         | `Just(val)`         |
| `{:error, _}`        | `Nothing`           |
| `Identity(nil)`      | `Nothing`           |
| `Left(_)`            | `Nothing`           |
| `Right(val)`         | `Just(val)`         |
| `try(fn -> ... end)` | `Just` or `Nothing` |

## Comparison Support

Lifts `Eq` and `Ord` logic to support custom comparison of `Just` values:

* `lift_eq/1`
* `lift_ord/1`

## Elixir Integration

Supports:

* `String.Chars` — inspectable output
* `Summarizable` — structured inspection tools
* `Foldable`, `Filterable`, and `Monad` protocols
