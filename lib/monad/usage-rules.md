# `Funx.Monad` Usage Rules

## Quick Reference

* A monad = `pure/1` (inject into context) + `bind/2` (chain with context).
* Use `map/2` to transform while preserving structure.
* Use `bind/2` to sequence context-aware operations.
* Use `ap/2` to apply functions already in context.
* Prefer monads when control flow depends on prior results.
* Avoid extracting intermediate values—compose instead.

---

## Overview

`Funx.Monad` supports declarative control flow in the presence of context.
It lets you sequence steps without branching manually or managing state explicitly.

The `Monad` protocol defines three core operations:

| Function | Purpose                                                            |
| -------- | ------------------------------------------------------------------ |
| `pure/1` | Injects a plain value into the monadic context.                    |
| `map/2`  | Applies a transformation while preserving structure.               |
| `bind/2` | Sequences context-aware steps—each step may reshape the structure. |
| `ap/2`   | Applies a function and a value, both inside the same context.      |

---

## When to Use It

Use a monad when your code depends on prior steps that occur inside a context:

| Context  | Use Case Example                         |
| -------- | ---------------------------------------- |
| `Maybe`  | A missing value cancels the rest.        |
| `Either` | A failure short-circuits the pipeline.   |
| `Effect` | Asynchronous steps chained in order.     |
| `Reader` | Configuration passed implicitly.         |
| `Writer` | Accumulate logs or context across steps. |

Each step you define declares what happens next—the monad handles how and when.

---

## Transforming with `map/2`

Use `map/2` to apply a function without changing the structure:

```elixir
map(monad, fn x -> transform(x) end)
```

If `monad` is a list, the result is a list.
If it's a `Maybe`, the result is still a `Maybe`.
The shape of the context is preserved.

---

## Sequencing with `bind/2`

Use `bind/2` when your function returns a new monadic value and should take over the pipeline:

```elixir
bind(monad, fn x -> step(x) end)
```

Each function must return the same type of monad.
This kind of function is called a Kleisli function—a function from a plain value to a wrapped value.

The structure may change. The monad will flatten and continue.
This allows dependent steps to be composed declaratively.

---

## Applying with `ap/2`

Use `ap/2` when both the value and the function are inside the context:

```elixir
ap(monadic_value, monadic_function)
```

This is especially useful when you want to apply multiple independent values to a multi-argument function:

```elixir
pure(fn x, y -> x + y end)
|> ap(m1)
|> ap(m2)
```

---

## Composing Declarative Logic

Functional control flow becomes:

```elixir
pure(initial)
|> bind(step1)
|> bind(step2)
|> bind(step3)
```

Each step declares its own rule.
The monad handles branching, structure, and short-circuiting as needed.
This replaces `case`, `with`, and `try` chains with composable, predictable logic.

---

## Design Guidance

* Do not unwrap intermediate values—compose using `bind/2`.
* Do not mix monadic and non-monadic code inside pipelines.
* Avoid early `case` or pattern matches—prefer `bind` to handle flow.
