# `Funx.Monoid` Usage Rules

## Quick Reference

* A monoid = `empty/1` (identity) + `append/2` (associative).  
* Identities must be true identities (e.g. `0` for sum, `1` for product, `[]` for concatenation).  
* `wrap/2` and `unwrap/1` exist for infrastructure, not daily use.  
* `m_append/3` and `m_concat/2` are low-level helpers that power higher abstractions.  
* Application code should prefer helpers in `Math`, `Eq.Utils`, `Ord.Utils`, or `Predicate`.

---

## Overview

`Funx.Monoid` defines how values combine under an associative operation with an identity.  
Each monoid is represented by a struct (e.g. `%Sum{}`, `%Product{}`, `%Eq.All{}`, `%Ord{}`) and implements:

* `empty/1` → the identity element  
* `append/2` → associative combination  
* `wrap/2` / `unwrap/1` → convert between raw values and monoid structs  

Monoids are rarely used directly in application code. Instead, they support utilities like `Math.sum/1`, `Eq.Utils.concat_all/1`, and `Ord.Utils.concat/1`.

---

## Protocol Rules

* Provide all four functions: `empty/1`, `append/2`, `wrap/2`, `unwrap/1`.  
* Identity: `append(empty(m), x) == x == append(x, empty(m))`.  
* Associativity: `append(append(a, b), c) == append(a, append(b, c))`.  
* Purity: results must be deterministic and side-effect free.  

---

## Preferred Usage

### Go Through Utilities

Use high-level helpers instead of wiring monoids manually:

* **Numbers** → `Math.sum/1`, `Math.product/1`, `Math.max/1`, `Math.min/1`  
* **Equality** → `Eq.Utils.concat_all/1`, `Eq.Utils.concat_any/1`  
* **Ordering** → `Ord.Utils.concat/1`, `Ord.Utils.append/2`  
* **Predicates** → `Predicate.p_and/2`, `Predicate.p_or/2`, `Predicate.p_all/1`, `Predicate.p_any/1`

These functions already call `m_concat/2` and `m_append/3`.  
You don’t need to construct `%Monoid.*{}` by hand.

---

### Examples

#### Equality Composition

```elixir
alias Funx.Eq.Utils, as: EqU

name_eq = EqU.contramap(& &1.name)
age_eq  = EqU.contramap(& &1.age)

EqU.concat_all([name_eq, age_eq])  # AND semantics
EqU.concat_any([name_eq, age_eq])  # OR semantics
```

#### Ordering Composition

```elixir
alias Funx.Ord.Utils, as: OrdU

age  = OrdU.contramap(& &1.age)
name = OrdU.contramap(& &1.name)

OrdU.concat([age, name])  # lexicographic ordering
```

#### Math Helpers

```elixir
alias Funx.Math

Math.sum([1, 2, 3])     # => 6
Math.product([2, 3, 4]) # => 24
Math.max([7, 3, 5])     # => 7
Math.min([7, 3, 5])     # => 3
```

---

## Interop

* `Eq.Utils` relies on `Eq.All` and `Eq.Any` monoids for composition.
* `Ord.Utils` uses the `Ord` monoid for lexicographic comparison.
* `Math` uses monoids for numeric folds.

**Rule of thumb:** application code never wires `%Monoid.*{}` directly—always go through the utility combinators.

---

## Stability Contract

* Identities must be stable and input-independent.
* `append/2` must be associative for all valid values.
* `wrap/2` and `unwrap/1` must be inverses.

---

## Anti-Patterns

* Hand-wiring `%Monoid.*{}` in application code.
* Mixing different monoid types in one `append/2`.
* Using fake identities (`nil` instead of `0` for sum).
* Hiding side effects inside protocol functions.

---

## Good Patterns

* Use `Math`, `Eq.Utils`, `Ord.Utils`, or `Predicate` instead of raw monoids.
* Keep identities explicit in library code (`0`, `1`, `[]`, `Float.min_finite()` / `Float.max_finite()`).
* Let `m_concat/2` and `m_append/3` handle the wrapping/combining logic.

---

## When to Define a New Monoid

Define a monoid struct if you need associative combination + identity:

* Counters, tallies, or scores
* Config merges (e.g. left-biased / right-biased maps)
* “Best-of” or “min-by/max-by” selections
* Predicate or decision combination

Expose it through a utility module—application code should not use it raw.

---

## Built-in Instances

* `%Funx.Monoid.Sum{}` — numeric sum (`0`)
* `%Funx.Monoid.Product{}` — numeric product (`1`)
* `%Funx.Monoid.Max{}` — maximum (`Float.min_finite()`)
* `%Funx.Monoid.Min{}` — minimum (`Float.max_finite()`)
* `%Funx.Monoid.ListConcat{}` — list concatenation (`[]`)
* `%Funx.Monoid.StringConcat{}` — string concatenation (`""`)
* `%Funx.Monoid.Eq.All{}` / `%Funx.Monoid.Eq.Any{}` — equality composition
* `%Funx.Monoid.Ord{}` — ordering composition

These back the higher-level helpers. Use `Math`, `Eq.Utils`, `Ord.Utils`, or `Predicate` instead.
