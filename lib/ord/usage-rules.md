# `Funx.Ord` Usage Rules

## Quick Reference

* Use `Ord.lt?/2`, `Ord.le?/2`, `Ord.gt?/2`, and `Ord.ge?/2` instead of raw comparison operators.
* Always implement all four functions when defining an instance.
* The fallback implementation uses Elixir's native operators and may raise for some types.
* `Ord.Utils.*` functions default to protocol dispatch.
* `Funx.List.sort/2` and `strict_sort/2` use `Ord`, not `Eq`.
* `Ord` is composable with helpers like `contramap`, `append`, `concat`, and `reverse`.

---

## Overview

`Funx.Ord` defines contextual ordering in Elixir.
Use `Ord` to express domain-specific comparison rules.

* Raw operators like `<` and `>` are not extensible or composable.
* `Ord` is implemented via protocol and can be customized per type.
* `Ord` integrates with `Funx.List`, `Ord.Utils`, and sorting operations.
* `Ord` supports composition and projection via utility helpers.

---

## Protocol Rules

* Implement all of the following:

  ```elixir
  lt?(a, b)  # less than
  le?(a, b)  # less than or equal
  gt?(a, b)  # greater than
  ge?(a, b)  # greater than or equal
  ```

* Implementations should define a total order and follow standard laws:

  * Antisymmetry: if `a <= b` and `b <= a`, then `a == b`
  * Transitivity: if `a <= b` and `b <= c`, then `a <= c`
  * Connexity: for any `a`, `b`, either `a <= b` or `b <= a`

* Prefer semantic ordering (e.g., domain fields) over structural details.

---

## Fallback (`Any`)

If no instance is defined, the protocol falls back to Elixir’s built-in comparison operators:

```elixir
defimpl Funx.Ord, for: Any do
  def lt?(a, b), do: a <  b
  def le?(a, b), do: a <= b
  def gt?(a, b), do: a >  b
  def ge?(a, b), do: a >= b
end
```

### Safe fallback types:

* Numbers (`1 < 2`)
* Strings and binaries (`"a" < "b"`)
* Tuples and lists (compared lexicographically)

### Unsafe fallback types:

* Maps and structs: raise `ArgumentError` when compared with `<`, `<=`, etc.
* Cross-type comparisons: may raise or produce invalid results

Use fallback only if you know the inputs are safe.
Define explicit `Ord` instances for structs and domain types.

---

## Preferred Usage

### Use `Ord` Instead of Raw Operators

```elixir
defimpl Funx.Ord, for: User do
  def lt?(%User{joined_at: a}, %User{joined_at: b}),
    do: Funx.Ord.lt?(a, b)

  def le?(a, b), do: lt?(a, b) or eq?(a, b)
  def gt?(a, b), do: not le?(a, b)
  def ge?(a, b), do: not lt?(a, b)

  defp eq?(%User{joined_at: a}, %User{joined_at: b}),
    do: Funx.Eq.eq?(a, b)
end
```

Project domain fields and delegate to `Ord` on those fields.
If the projected field also has an `Eq` instance, use it for consistency.

---

### Use `Ord.Utils` for Dispatch

All `Ord.Utils` functions default to the protocol.
You do not need to pass logic manually if the type has an instance.

```elixir
Ord.Utils.compare(a, b)      # :lt | :eq | :gt
Ord.Utils.min(a, b)
Ord.Utils.max(a, b)
Ord.Utils.clamp(value, min, max)
Ord.Utils.between(value, min, max)
Ord.Utils.comparator()       # For Enum.sort/2
```

---

### Projections and Composition

```elixir
# Order by projected key
by_length = Ord.Utils.contramap(&String.length/1)
Ord.Utils.max("cat", "zebra", by_length)  # "zebra"

# Reverse an ordering
desc = Ord.Utils.reverse(by_length)

# Compose by multiple fields
ord =
  Ord.Utils.concat([
    Ord.Utils.contramap(& &1.age),
    Ord.Utils.contramap(& &1.name)
  ])

Ord.Utils.compare(%{age: 30, name: "Bob"}, %{age: 30, name: "Charlie"}, ord)
# => :lt
```

Use `append/2` or `concat/1` to build lexicographic orderings.
Use `reverse/1` to invert direction.

---

### Convert `Ord` to `Eq`

You can derive equality from ordering:

```elixir
eq = Ord.Utils.to_eq()
eq.eq?.(7, 7)  # true
```

This ensures consistent logic across equality and ordering.

---

## In `Funx.List`

Sorting uses `Ord`.
All `Funx.List` sorting functions accept a comparator, defaulting to the protocol.

```elixir
Funx.List.sort(list, ord \\ Funx.Ord)
Funx.List.strict_sort(list, ord \\ Funx.Ord)
```

`strict_sort/2` removes duplicates using `Ord.Utils.to_eq/1`.

### Examples

```elixir
# Default: numeric sort
Funx.List.sort([3, 1, 2])
# => [1, 2, 3]

# Custom: by string length, then alphabetically
ord =
  Ord.Utils.concat([
    Ord.Utils.contramap(&String.length/1),
    Ord.Utils.contramap(& &1)
  ])

Funx.List.sort(~w(zero one two three), ord)
# => ["one", "two", "zero", "three"]

Funx.List.strict_sort(["aa", "a", "aa"], ord)
# => ["a", "aa"]
```

---

## Stability Contract

* All functions must be pure.
* Each instance must define a total order.
* If the type also defines `Eq`, keep the implementations consistent:

```elixir
Ord.Utils.compare(a, b) == :eq  <=>  Eq.eq?(a, b)
```

---

## Anti-Patterns

* Using `<` or `>` on maps or structs.
* Comparing values of unrelated types.
* Mixing protocol-based and ad-hoc logic in the same function.

---

## Good Patterns

* Use `contramap` to project comparison keys.
* Use `append` or `concat` to build multi-key orderings.
* Use `reverse` to define descending order without rewriting logic.
* Use `Ord.Utils.comparator/1` when sorting with `Enum.sort/2`.

---

## When to Define an `Ord` Instance

Define an `Ord` instance when you need to control how values are ordered.

### Common cases

* Time-based comparisons (`inserted_at`, `scheduled_on`)
* Lexicographic fallback (sort by age, then name)
* Score-based ordering (revenue, priority, bonus)
* Domain-specific sort (e.g., "VIP before General")

---

## Built-in Instances

`Funx.Ord` includes protocol implementations for Elixir’s temporal types:

* `DateTime` → uses `DateTime.compare/2`
* `Date` → uses `Date.compare/2`
* `Time` → uses `Time.compare/2`
* `NaiveDateTime` → uses `NaiveDateTime.compare/2`

These implementations support full ordering: `lt?/2`, `le?/2`, `gt?/2`, `ge?/2`.
They are safe for use with `Ord.Utils` and `Funx.List`.

Avoid relying on the fallback for maps or structs—define explicit rules instead.
