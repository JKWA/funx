# `Funx.Monad.Identity` Usage Rules

## Quick Reference

* `pure/1` injects a value into the `Identity` context.
* `extract/1` unwraps the value.
* `map/2`, `bind/2`, `ap/2` are protocol functions that *target* `Identity`.
* `lift_eq/1`, `lift_ord/1` lift custom `Eq` and `Ord` logic.

Implements `Monad`, `Eq`, `Ord`, `String.Chars`, and `Summarizable`.

---

## Overview

`Identity` wraps a value without introducing branching, failure, delay, or effects.
It exists to carry structure—so logic can be written in terms of generic `Monad`, `Eq`, or `Ord` operations.

This makes `Identity` ideal for scaffolding, testing, and teaching: nothing is hidden, nothing is added.

---

## When to Use

| Use Case         | Reason                            |
| ---------------- | --------------------------------- |
| Teaching         | Simplest monad—no surprises       |
| Pipeline testing | Safe to test `bind/2` and `map/2` |
| Function lifting | Enables polymorphic reuse         |
| Placeholder      | Swap in richer monads later       |

---

## Core Functions

| Function       | Purpose                                       |
| -------------- | --------------------------------------------- |
| `pure/1`       | Wrap a value for composition                  |
| `extract/1`    | Unwrap the inner value                        |
| `Monad.map/2`  | Apply a plain function (structure-preserving) |
| `Monad.bind/2` | Chain Kleisli functions                       |
| `Monad.ap/2`   | Apply a contextual function to a value        |
| `lift_eq/1`    | Lift a custom `Eq` definition                 |
| `lift_ord/1`   | Lift a custom `Ord` definition                |

---

## Examples

### Wrapping and Extracting

```elixir
Identity.pure(42) |> extract()
# => 42
```

---

### Mapping (via `Monad`)

```elixir
Identity.pure(3)
|> Monad.map(&(&1 + 1))
# => %Identity{value: 4}
```

---

### Chaining (via `bind/2`)

```elixir
step = fn x -> Identity.pure(x + 1) end

Identity.pure(3)
|> Monad.bind(step)
|> Monad.bind(step)
# => %Identity{value: 5}
```

---

### Applying (via `ap/2`)

```elixir
Identity.pure(fn x, y -> x + y end)
|> Monad.ap(Identity.pure(1))
|> Monad.ap(Identity.pure(2))
# => %Identity{value: 3}
```

---

### Equality (via `Eq`)

```elixir
Eq.eq?(Identity.pure(5), Identity.pure(5)) # true

custom = Eq.Utils.by_key(:id)
Identity.lift_eq(custom).eq?.(
  Identity.pure(%{id: 1}), Identity.pure(%{id: 1})
)
```

---

### Ordering (via `Ord`)

```elixir
Ord.lt?(Identity.pure(1), Identity.pure(2)) # true

custom = Ord.Utils.by_key(:score)
Identity.lift_ord(custom).gt?.(
  Identity.pure(%{score: 10}), Identity.pure(%{score: 5})
)
```

---

### Display and Logging

```elixir
to_string(Identity.pure(42))
# => "Identity(42)"

Summarizable.summarize(Identity.pure(:ok))
# => {:identity, :ok}
```
