# `Funx.Monad.Either` Usage Rules

## Quick Reference

### Construction

* `right/1` — Wraps a success.
* `left/1` — Wraps a failure.
* `pure/1` — Alias for `right/1`.

### Monadic Composition

*(via `Funx.Monad` protocol)*

* `map/2` — Transforms a `Right`; skips `Left`.
* `bind/2` — Chains context-aware functions (`a -> Either`); short-circuits on `Left`.
* `ap/2` — Applies a `Right(fun)` to a `Right(arg)`; propagates `Left`.

### Refinement & Queries

* `right?/1`, `left?/1` — Check which variant.
* `flip/1` — Swaps `Left` and `Right`.

### Fallback

* `get_or_else/2` — Extracts or supplies default.
* `or_else/2` — Replaces a `Left` with a fallback `Either`.
* `map_left/2` — Transforms the `Left` side only.

### Filtering

* `filter_or_else/3` — Keeps a `Right` only if it satisfies a predicate.

### Monadic Lists

* `concat/1` — Extracts all `Right` values from a list.
* `concat_map/2` — Maps to `Either`, filters `Right` results.
* `sequence/1` — Combines if all are `Right`; halts on first `Left`.
* `traverse/2` — Applies a function to each element, stops at first `Left`.

### Applicative Lists

* `sequence_a/1` — Combines all; accumulates `Left` errors (requires `Semigroup`).
* `traverse_a/2` — Maps with error accumulation.
* `wither_a/2` — Maps to `Maybe` while accumulating errors.

### Validation

* `validate/2` — Applies multiple validators to one input, accumulating all failures.

### Lifting

* `lift_predicate/3` — Wraps `Right` if condition holds, otherwise `Left`.
* `lift_maybe/2` — Converts `Maybe` to `Either`.
* `lift_eq/1`, `lift_ord/1` — Adapts `Eq` and `Ord` logic.

### Elixir Interop

* `from_result/1`, `to_result/1`
* `from_try/1`, `to_try!/1`

Implements: `Monad`, `Eq`, `Ord`, `Foldable`, `String.Chars`, `Summarizable`.

## Overview

The `Either` monad represents a computation that can succeed or fail. It carries one of two variants:

* `Right(success)` — a valid result
* `Left(error)` — a failure, error, or explanation

`Either` is **right-biased**: `map/2`, `bind/2`, and `ap/2` apply only to the `Right`. If the value is `Left`, these operations skip the function and preserve the error. This simplifies branching logic—allowing you to chain multiple steps without manually checking for failure.

Use `Right` when the computation succeeds. Use `Left` when it fails but should continue in a controlled, declarative manner.

## When to Use It

| Situation                        | Use `Either` to…                             |
| -------------------------------- | -------------------------------------------- |
| Represent recoverable failures   | Avoid exceptions, wrap with `Left`           |
| Chain dependent steps            | Use `bind/2` to short-circuit on failure     |
| Validate multiple fields         | Use `traverse_a/2` to accumulate errors      |
| Fallback gracefully              | Use `or_else/2` or `get_or_else/2`           |
| Transform only errors            | Use `map_left/2`                             |
| Turn predicates into branches    | Use `filter_or_else/3` or `lift_predicate/3` |
| Convert from `Maybe` or `Result` | Use `lift_maybe/2` or `from_result/1`        |

## Monadic Control

### `map/2`

Preserves structure, applies a function to transform a `Right`. Preserves `Left` unchanged.

```elixir
map(right(2), fn x -> x + 1 end)
# => Right(3)

map(left("fail"), fn x -> x + 1 end)
# => Left("fail")
```

### `bind/2`

Chains functions that return an `Either`. Skips remaining steps if `Left`.

```elixir
right(2)
|> bind(fn x -> right(x + 1) end)
|> bind(fn x -> right(x * 2) end)
# => Right(6)
```

### `ap/2`

Applies a `Right(fun)` to a `Right(arg)`. Any `Left` halts the chain.

```elixir
pure(fn x -> x * 10 end)
|> ap(right(3))
# => Right(30)

left("bad") |> ap(right(3))
# => Left("bad")
```

## Fallback and Filtering

### `get_or_else/2`

Returns the inner value if `Right`, fallback otherwise.

```elixir
get_or_else(right("ok"), "fallback")     # => "ok"
get_or_else(left("fail"), "fallback")    # => "fallback"
```

### `or_else/2`

Replaces a `Left` with another `Either`.

```elixir
or_else(right("ok"), fn -> right("alt") end)
# => Right("ok")

or_else(left("fail"), fn -> right("alt") end)
# => Right("alt")
```

### `map_left/2`

Transforms the error value, preserving `Right`.

```elixir
map_left(left("fail"), &String.upcase/1)
# => Left("FAIL")
```

### `filter_or_else/3`

Keeps a `Right` only if it satisfies a predicate. Returns `Left` with provided reason otherwise.

```elixir
filter_or_else(right(5), fn x -> x > 3 end, fn -> "too small" end)
# => Right(5)

filter_or_else(right(2), fn x -> x > 3 end, fn -> "too small" end)
# => Left("too small")
```

## List Composition

### Monadic (`traverse/2`, `sequence/1`)

Stops on first `Left`. Use when one error is enough to halt the operation.

```elixir
traverse([1, 2, 3], fn x ->
  if x < 3, do: right(x), else: left("too big")
end)
# => Left("too big")
```

### Applicative (`traverse_a/2`, `sequence_a/1`)

Continues through all inputs. Accumulates all failures via `Semigroup`.

```elixir
use Funx.Semigroup.Sum

traverse_a([1, 2, 3, 4], fn x ->
  if x < 3, do: right(x), else: left(Sum.new(1))
end)
# => Left(%Sum{unwrap: 3})
```

Use `traverse/2` when you want fast failure.
Use `traverse_a/2` when you want all errors, e.g., in form validation.

## Validation

### `validate/2`

Composes multiple validators over a single input, accumulating all failures.

```elixir
validators = [
  fn x -> lift_predicate(x, &(&1 > 0), &"too small: #{x}") end,
  fn x -> lift_predicate(x, &(rem(&1, 2) == 0), &"not even: #{x}") end
]

validate(3, validators)
# => Left(["not even: 3"])

validate(-2, validators)
# => Left(["too small: -2"])
```

## Lifting and Interop

### From Other Types

```elixir
from_result({:ok, 5})        # => Right(5)
from_result({:error, "bad"}) # => Left("bad")

from_try(fn -> raise "fail" end)
# => Left(%RuntimeError{...})

lift_maybe(just(5), fn -> "none" end)     # => Right(5)
lift_maybe(nothing(), fn -> "none" end)   # => Left("none")
```

## Comparison Support

Lifts `Eq` and `Ord` instances into the `Either` context.

* Use `lift_eq/1` to compare wrapped values.
* Use `lift_ord/1` for ordering.
* `Right(_) > Left(_)` always.

## Summary

`Either` helps you model errors explicitly, control branching declaratively, and validate complex input without sacrificing clarity. Use it to avoid exceptions, preserve intent, and build expressive pipelines.

* Short-circuit with `bind/2`
* Accumulate errors with `ap/2`
* Choose structure based on desired failure behavior: fast or wide
