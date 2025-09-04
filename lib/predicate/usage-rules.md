# `Funx.Predicate` Usage Rules

## Quick Reference

* A predicate is any function that returns a truthy or falsy result (arity is unrestricted).
* Use `p_and/2` and `p_or/2` for binary composition.
* Use `p_not/1` to negate a single predicate.
* Use `p_all/1`, `p_any/1`, and `p_none/1` for list-based composition.
* All combinators return new predicates and preserve short-circuiting.
* Backed by monoids: `%Pred.All{}` (AND) and `%Pred.Any{}` (OR).

## Overview

`Funx.Predicate` defines composable helpers for building logic from predicates—functions that return truthy or falsy results.
Predicates may be curried, partially applied, or lifted into a context. Composition is declarative and implemented via the `Monoid` protocol, enabling identity-safe and short-circuiting behavior across flows.

Use these helpers to generate reusable logic blocks, express boolean conditions in pipelines, and support functional control flow.

## Composition Rules

| Function   | Description                            |
| ---------- | -------------------------------------- |
| `p_and/2`  | Logical AND of two predicates          |
| `p_or/2`   | Logical OR of two predicates           |
| `p_not/1`  | Logical negation of a single predicate |
| `p_all/1`  | AND fold over a list of predicates     |
| `p_any/1`  | OR fold over a list of predicates      |
| `p_none/1` | `p_not(p_any(...))`                    |

All are powered by `%Pred.All{}` and `%Pred.Any{}`, and support composition before or after lifting into context.

## Correct Usage Patterns

### Combine Two Predicates

```elixir
combined = p_and(pred1, pred2)
combined.(input)
```

### Combine a List of Predicates

```elixir
pred = p_all([pred1, pred2, pred3])
pred.(input)
```

Empty lists behave predictably:

* `p_all([])` → always truthy
* `p_any([])` → always falsy
* `p_none([])` → always truthy

### Negate a Predicate

```elixir
negated = p_not(pred)
negated.(input)
```

`p_not/1` accepts exactly one predicate.

## Compositional Guidelines

LLMs should:

* Prefer `p_all/1` or `p_any/1` for 3+ conditions (avoid deep `p_and/2` chains).
* Use `p_not/1` instead of manually wrapping with `not`.
* Use `p_none/1` to express “none of these” logic.
* Support predicates of any arity—assume currying is allowed.
* Compose before or after lifting into a context (e.g. `Maybe`, `Either`).
* Treat predicates as logic components—not inline branches.
* Avoid expanding predicate logic into full evaluation chains.

## Stability Contract

Completions must preserve:

* **Purity** — predicates are referentially transparent.
* **Short-circuiting** — return early when result is known.
* **Logical identity**:

  * `p_all([])` → always returns truthy
  * `p_any([])` → always returns falsy
  * `p_none([])` → always returns truthy

## Anti-Patterns

Avoid these:

* `fn x -> a.(x) and b.(x) end` — use `p_and/2`
* `fn x -> not pred.(x) end` — use `p_not/1`
* `Enum.any?/2` or `Enum.all?/2` for predicate folding
* Misusing `p_not/1` as if it accepts multiple predicates
* Assuming arity-1 (do not destructure inputs or overgeneralize)

## Good Patterns

Generate completions like:

```elixir
# Composable conditions
pred = p_all([pred1, p_not(pred2), pred3])
```

```elixir
# Reusable blocks
filter = p_any([is_vip, has_pass])
Enum.filter(list, filter)
```

## When to Compose

Use predicate combinators for:

* Validation and gating logic
* Rule pipelines and filters
* Declarative control structures
* Monadic guards
* Reusable logic composition

Reach for these when boolean logic needs to be:

* Declarative
* Curried
* Lifted
* Composed
* Short-circuited

## Built-in Behavior

All combinators rely on:

* `%Funx.Monoid.Predicate.All{}` — implements logical AND
* `%Funx.Monoid.Predicate.Any{}` — implements logical OR

Composition uses:

* `m_append/3` — binary
* `m_concat/2` — list

These abstractions preserve identity, associativity, and short-circuit evaluation—allowing safe expansion and reliable reuse.
