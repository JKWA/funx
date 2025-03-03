# Learning Resources

## The Basics of a Monad

### [Elixir and Functors: Map in Monads](https://www.joekoski.com/blog/2024/09/01/fp-map.html)

This post introduces **functors**—structures that use `map` to apply transformations to values within a structure. We’ll look at how the `Funx.Identity`, `Funx.Maybe`, and `Funx.Either` monads implement `map`, showcasing the unique context each brings to this process.

### [Elixir and Functors: Apply in Monads](https://www.joekoski.com/blog/2024/09/05/fp-ap.html)

This post introduces **applicatives**—structures that extend functors by allowing values within a context to be applied to functions in the same context using `ap`. We’ll explore how the `Funx.Identity`, `Funx.Maybe`, and `Funx.Either` monads implement `ap` within their unique contexts.

### [Elixir and Monads: Bind in Monads](https://www.joekoski.com/blog/2024/09/03/fp-bind.html)

This post introduces **monads**, structures that extend applicatives by adding `bind` for chaining and flattening a sequence of transformations within the same context. We’ll explore how the `Funx.Identity`, `Funx.Maybe`, and `Funx.Either` monads implement `bind` within their unique contexts.

## Ordering in Monads

### [Monad Basics: Order](https://www.joekoski.com/blog/2024/09/10/fp-ord.html)

This post explores custom comparison logic in Elixir with Funx's `Funx.Ord.Utils` utilities. We’ll examine how Funx enables meaningful comparisons for both plain and monadic values, allowing flexible ordering beyond basic operators.

### [Monad Basics: Composing Order](https://www.joekoski.com/blog/2024/09/10/fp-ord-compose.html)

Building on `Funx.Ord.Utils`, this post covers `contramap`, `comparator`, and `reverse` utilities for composing complex sorting logic from simple, modular components.

## Defining Equality and Ordering in the Domain

### [FP Basics: Domain-Specific Eq and Ord](https://www.joekoski.com/blog/2024/09/16/fp-domain.html)

This post explores how to centralize equality (`Funx.Eq`) and ordering (`Funx.Ord`) in the domain using Elixir’s Funx library. By defining `Eq` and `Ord` in the `Example.User` module, the application gains consistent, domain-specific rules for comparing and ordering users. This approach keeps equality and ordering logic adaptable, maintainable, and aligned with the domain’s evolving requirements.

## Building Monads in Elixir

### [Elixir and Monads: Naming Challenges](https://www.joekoski.com/blog/2024/06/10/monad-naming-conventions.html)

This post explores the challenges of learning functional programming, which include mastering abstractions grounded in mathematical principles and navigating the moving target of naming conventions across languages and libraries. It also discusses the naming decisions for the Funx library, which brings monadic structures to Elixir.

### [Elixir and Monads: Identity](https://www.joekoski.com/blog/2024/06/15/monad-identity.html)

This post introduces the fundamentals of the `Funx.Identity` monad, the simplest monad used to wrap and operate on a single value. It lays the groundwork for understanding monads in Elixir by explaining key functions like `map`, `bind`, and `ap`, and their implementation using Elixir's `defprotocol`. By starting with the basic Identity monad, this post sets the stage for more complex monads to follow.

### [Elixir and Monads: Equality and Order](https://www.joekoski.com/blog/2024/06/17/eq-ord.html)

Building on the Identity monad, this post introduces custom protocols to handle equality and ordering within monads. It explains the `Funx.Eq` protocol for comparing monadic values and the `Funx.Ord` protocol for ordering them, extending the principles of the Identity monad with new functionality. These protocols show how monads establish consistent comparisons and ordering across different contexts.

### [Elixir and Monads: Maybe](https://www.joekoski.com/blog/2024/06/20/monad-maybe.html)

The `Funx.Maybe` monad expands on the previous concepts by introducing the notion of optional values, represented by `Just` and `Nothing`. This post demonstrates how to handle missing values safely without null checks, extending the Identity monad’s principles to more practical scenarios. It also shows how the `Eq` and `Ord` protocols apply to the `Maybe` context, while introducing operations like `filter`, `fold`, and `get_or_else`.

### [Elixir and Monads: Either](https://www.joekoski.com/blog/2024/06/25/monad-either.html)

The `Funx.Either` monad extends the `Funx.Maybe` monad by handling two distinct possibilities: `Right` (success) and `Left` (error). This post explores how `Either` differs from `Maybe`, particularly in managing error propagation. Functions like `ap`, `bind`, and `map` are adapted to handle success and failure paths, while `fold`, `sequence`, and `traverse` enable working with lists of `Either` values. This demonstrates how monads manage multiple outcomes and deal with success and error paths in effectful code.

### [Elixir and Monads: Example](https://www.joekoski.com/blog/2024/06/27/monad-example.html)

This post compares two approaches to handling business logic in Elixir: a typical tuple-based approach and monadic composition. It demonstrates how monads, specifically the `Funx.Either` monad, abstract away error handling and streamline operations by leveraging functions like `bind` and `map`. This post shows how monads can enhance composability and maintainability in complex workflows.

### [Elixir and Monads: Effect](https://www.joekoski.com/blog/2024/07/07/monad-lazy-task-either.html)

Here’s the updated paragraph:

`Funx.Effect` combines error handling with deferred execution, enabling the composition of asynchronous operations that may fail. This post explains how `Funx.Effect` manages both success (`Right`) and error (`Left`) contexts while deferring execution until `run/1` is called. It covers key functions like `bind`, `map`, and `ap`, demonstrating how to integrate error handling into complex, asynchronous workflows in a clean, functional style.

### [Elixir and Monads: Async Example](https://www.joekoski.com/blog/2024/07/09/monad-example-2.html)

Continuing from [the previous post](https://www.joekoski.com/blog/2024/06/27/monad-example.html) on handling business logic with the `Funx.Either` monad, this post extends the discussion to asynchronous operations using `Funx.Effect`. It demonstrates how monadic composition can be applied to handle tasks like input validation and availability checks while managing both success (`Right`) and failure (`Left`) paths. By deferring execution with `Funx.Effect`, asynchronous workflows are structured in the same way as synchronous ones, maintaining consistency and composability in error handling.

### [Elixir and Applicatives: Validation](https://www.joekoski.com/blog/2024/07/11/applicative-validation.html)

This post explores how the applicative approach to validation allows the collection of all errors without short-circuiting, unlike monads. It introduces `sequence_a/2` (sequence applicative) in the `Funx.Either` and `Funx.Effect`, along with `validate/2`, which accumulates errors rather than stopping at the first failure. This post highlights the benefits of applicative validation in scenarios requiring multiple checks.

### [Elixir and Monads: Operators](https://www.joekoski.com/blog/2024/07/14/monad-operators.html)

Inspired by Haskell's monadic operators, this post introduces custom operators for working with monads in Elixir using macros. It defines operators like `~>`, `~>>`, and `<<~` for `map`, `bind`, and `ap` functions, enabling more concise and expressive monadic composition. The post also explores the trade-offs between conciseness and readability when using custom operators.

### [Elixir and Monads: Reader](https://www.joekoski.com/blog/2024/07/18/mondad-reader.html)

The Reader monad, also known as the Environment monad, brings dependency injection to functional programming, allowing computations to access shared context without directly passing it to every function. This post covers `Funx.Reader`, demonstrating how it enables environment-based logic using `ask` and `run` for dynamic configuration injection.
