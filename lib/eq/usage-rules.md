# `Funx.Eq` Usage Rules

## Quick Reference

* Use `Eq.eq?/2` instead of `==`.
* Implement both `eq?/2` and `not_eq?/2`.
* If no instance exists, the fallback uses Elixir’s `==` and `!=` via `Any`.
* `Eq.Utils.*` defaults to protocol dispatch—no extra wiring needed.
* `Funx.List` functions (`uniq`, `union`, `intersection`, etc.) respect `Eq`.
* `Eq` is composable (`contramap`, `append_all`, `concat_any`); `==` is not.

## Overview

`Funx.Eq` defines contextual equality in Elixir.
Use `Eq` instead of `==` for identity checks, filters, and deduplication.

* `==` is structural and fixed. It cannot be changed or composed.
* `Eq` is extensible and composable. You can define it for your own types, and build new comparisons with helpers like `contramap`, `append_all`, and `concat_any`.

`Eq.Utils` provides combinators for building custom equality rules.
`Funx.List` uses `Eq` automatically—set operations respect domain semantics.

## Protocol Rules

* Implement both `eq?/2` and `not_eq?/2`.

* Follow the standard equality laws:

  * Reflexivity: `eq?(a, a) == true`
  * Symmetry: `eq?(a, b) == eq?(b, a)`
  * Transitivity: if `eq?(a, b)` and `eq?(b, c)`, then `eq?(a, c)`

* Prefer semantic equality over structural equality:

  * Identity fields
  * Business logic
  * Domain rules

### Fallback (`Any`)

If no explicit implementation is provided, `Any` uses Elixir’s `==`:

```elixir
defimpl Funx.Eq, for: Any do
  def eq?(a, b), do: a == b
  def not_eq?(a, b), do: a != b
end
```

Fallback is fine for primitives.
For maps and structs, define your own `Eq` instance.

## Preferred Usage

### Use `Eq.eq?/2` Instead of `==`

Define equality in terms of domain identity.
Prefer projecting and delegating:

```elixir
defimpl Funx.Eq, for: User do
  def eq?(%User{id: v1}, %User{id: v2}), do: Funx.Eq.eq?(v1, v2)
  def not_eq?(a, b), do: not eq?(a, b)
end
```

This delegates to the `Eq` instance for `id`, if one exists.
It keeps your comparison logic composable and consistent.

You can also build custom equality on the fly:

```elixir
eq = Eq.Utils.contramap(& &1.id)
Eq.Utils.eq?(user1, user2, eq)
```

### Default Dispatch in `Eq.Utils`

All helpers default to protocol dispatch—you don’t need to pass logic manually.

```elixir
Eq.Utils.eq?(a, b)
Eq.Utils.not_eq?(a, b)
Eq.Utils.eq_by?(&proj/1, a, b)
Eq.Utils.to_predicate(target)
```

### Projections and Composition

```elixir
# Compare by ID
eq = Eq.Utils.contramap(& &1.id)
Eq.Utils.eq?(%User{id: 1}, %User{id: 1}, eq)

# Filter a list by identity
Enum.filter(users, Eq.Utils.to_predicate(current_user, eq))

# Combine comparators
Eq.Utils.concat_all([
  Eq.Utils.contramap(& &1.name),
  Eq.Utils.contramap(& &1.age)
])
```

You can also use:

* `append_all/2` (left-to-right composition)
* `concat_all/1` (multi-key lexicographic comparison)
* `concat_any/1` (any-match logic)

## In `Funx.List`

`Funx.List` uses `Eq` automatically via `Eq.Utils`.
No extra setup required.

### Equality-Sensitive Functions

* `uniq/2`
* `union/3`
* `intersection/3`
* `difference/3`
* `symmetric_difference/3`
* `subset?/3`
* `superset?/3`

> Sorting is handled by `Funx.Ord` (`sort/2`, `strict_sort/2`).

### Examples

```elixir
# With a protocol impl
Funx.List.uniq([%User{id: 1}, %User{id: 1}])
# => [%User{id: 1}]

# With fallback (Any)
Funx.List.uniq([1, 1.0])
# => [1]  # Elixir: 1 == 1.0

# With ad-hoc comparator
eq = Eq.Utils.contramap(& &1.name)
Funx.List.uniq(users, eq)
```

## Stability Contract

* `eq?/2` must be pure (same inputs → same output).
* `eq?/2` and `not_eq?/2` must be exact complements.
* Instances should be domain-aware and consistent.

## Anti-Patterns

* Mixing `==` and `Eq` in the same logic:

  ```elixir
  # BAD
  if a == b and Eq.eq?(a, b), do: ...
  ```

* Comparing unrelated types:

  ```elixir
  Eq.eq?(:ok, %{ok: true})  # meaningless
  ```

## Good Patterns

* Use `Eq` for identity checks, filters, and deduplication.
* Use `contramap` to project domain keys.
* Compose equality logic close to its use.
* Avoid relying on fallback for domain types.

## When to Define an `Eq` Instance

Define an `Eq` instance when you need control over what counts as equal.

### Common Cases

* Identity fields (`id`, `slug`, `handle`)
* Semantic keys (birthdays = same day/month)
* Ignoring metadata (timestamps, versions)
* Composite identity (multiple fields together)
* Domain logic (business rules define equality)
* Set-like operations (deduplication, membership)

### Why `Eq` Instead of `==`

* `==` is fixed and structural.
* `Eq` is extensible through protocols.
* `Eq` is composable (`contramap`, `append_all`, `concat_any`).
* `Eq` integrates with `Eq.Utils` and `Funx.List`.

## Built-in Instances

`Funx.Eq` provides ready-to-use instances for Elixir’s time types:
Each uses the standard library’s `compare/2`, but only checks for equality:

* `DateTime` → `DateTime.compare(a, b) == :eq`
* `Date` → `Date.compare(a, b) == :eq`
* `Time` → `Time.compare(a, b) == :eq`
* `NaiveDateTime` → `NaiveDateTime.compare(a, b) == :eq`

Also included:
A fallback for `Any` using Elixir’s `==` and `!=`:

```elixir
Eq.eq?(1, 1.0)  # true
Eq.eq?("a", "a")  # true
```

Safe for primitives.
**For domain types, define an explicit instance.**
