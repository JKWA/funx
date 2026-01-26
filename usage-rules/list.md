# `Funx.List` Usage Rules

## Quick Reference

* All functions operate on Elixir lists (`[term()]`).
* `Eq` is used for: `uniq/2`, `union/3`, `intersection/3`, `difference/3`, `symmetric_difference/3`, `group/2`, `partition/3`, `subset?/3`, and `superset?/3`.
* `Ord` is used for: `sort/2`, `strict_sort/2`, and `group_sort/2`.
* `strict_sort/2` combines `Ord` (for sorting) and `Eq` (for deduplication).
* All functions default to protocol dispatch; no wiring needed if instances exist.
* Ad-hoc comparators can be passed using `Eq.contramap/1` or `Ord.contramap/1`.

## Overview

The `Funx.List` module provides equality- and ordering-aware utilities for working with lists.
It supports deduplication, sorting, and set-like behavior using `Eq` and `Ord` instances.

This allows logic like "unique cars by VIN" or "sort by price, then mileage" to be clean, composable, and domain-aware.

## Eq-Based Operations

### `uniq/2`

Removes duplicates using `Eq`.

```elixir
Funx.List.uniq([%Car{vin: "A"}, %Car{vin: "A"}])
# => [%Car{vin: "A"}]
```

With custom comparator:

```elixir
eq = Eq.contramap(& &1.make)
Funx.List.uniq(cars, eq)
```

### `union/3`

Combines two lists, removing duplicates using `Eq`.

```elixir
Funx.List.union([1, 2], [2, 3])
# => [1, 2, 3]
```

### `intersection/3`

Returns the elements common to both lists.

```elixir
Funx.List.intersection([1, 2, 3], [2, 3, 4])
# => [2, 3]
```

### `difference/3`

Returns elements from the first list that are not in the second.

```elixir
Funx.List.difference([1, 2, 3], [2])
# => [1, 3]
```

### `symmetric_difference/3`

Returns elements that appear in only one of the two lists.

```elixir
Funx.List.symmetric_difference([1, 2], [2, 3])
# => [1, 3]
```

### `group/2`

Groups consecutive equal elements into sublists. This is the Eq-based equivalent of Haskell's `group`.

```elixir
Funx.List.group([1, 1, 2, 2, 2, 3, 1, 1])
# => [[1, 1], [2, 2, 2], [3], [1, 1]]
```

With custom comparator:

```elixir
eq = Eq.contramap(&String.downcase/1)
Funx.List.group(["a", "A", "b", "B"], eq)
# => [["a", "A"], ["b", "B"]]
```

### `partition/3`

Partitions a list into elements equal to a value and elements not equal. This is the Eq-based equivalent of predicate-based partition.

```elixir
Funx.List.partition([1, 2, 1, 3, 1], 1)
# => {[1, 1, 1], [2, 3]}
```

With custom comparator:

```elixir
eq = Eq.contramap(&String.downcase/1)
Funx.List.partition(["a", "B", "A", "c"], "a", eq)
# => {["a", "A"], ["B", "c"]}
```

### `subset?/3` and `superset?/3`

Checks for inclusion using `Eq`.

```elixir
Funx.List.subset?([1, 2], [1, 2, 3])
# => true

Funx.List.superset?([1, 2, 3], [1, 2])
# => true
```

## Ord-Based Operations

### `sort/2`

Sorts the list using `Ord`. Defaults to protocol dispatch.

```elixir
Funx.List.sort([3, 1, 2])
# => [1, 2, 3]
```

With ad-hoc ordering:

```elixir
ord = Ord.contramap(& &1.price)
Funx.List.sort(cars, ord)
```

### `strict_sort/2`

Sorts the list and removes duplicates. Uses `Ord` for sorting and derives `Eq` from ordering.

```elixir
Funx.List.strict_sort([3, 1, 3, 2])
# => [1, 2, 3]
```

### `group_sort/2`

Sorts the list and groups consecutive equal elements. Uses `Ord` for sorting and derives `Eq` from ordering.

```elixir
Funx.List.group_sort([1, 2, 1, 2, 1])
# => [[1, 1, 1], [2, 2]]
```

With custom ordering:

```elixir
ord = Ord.contramap(&String.downcase/1)
Funx.List.group_sort(["b", "A", "a", "B"], ord)
# => [["A", "a"], ["b", "B"]]
```

## Concatenation

### `concat/1`

Concatenates a list of lists left-to-right using the `ListConcat` monoid.

```elixir
Funx.List.concat([[1], [2, 3], [4]])
# => [1, 2, 3, 4]
```

## Good Patterns

* Use `uniq/2`, `intersection/3`, and related functions instead of manual deduplication.
* Use `contramap/1` to lift equality or ordering by projecting key fields.
* Use `strict_sort/2` when you need sorted unique results.
* Define protocol instances for domain types to remove the need for custom comparator logic.

## Anti-Patterns

* Using `==` in list operations instead of `Eq`:

  ```elixir
  # BAD
  Enum.uniq_by(users, & &1.id)  # not composable or testable
  ```

* Sorting maps or structs without defining `Ord`:

  ```elixir
  # BAD
  Enum.sort([%User{}])  # may raise
  ```

* Mixing raw and protocol-based comparison:

  ```elixir
  # BAD
  if user1.id == user2.id and Eq.eq?(user1, user2), do: ...
  ```

## When to Use

Use `Funx.List` when:

* You want list operations that follow your domain's equality or ordering rules.
* You need composable set logic like `union` or `difference`.
* You want deterministic, extensible sorting.
* You're working with domain types (e.g., `User`, `Car`, `Ticket`) and want safe behavior.
