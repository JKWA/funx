# Funx  

[![Continuous Integration](https://github.com/JKWA/funx/actions/workflows/ci.yml/badge.svg)](https://github.com/JKWA/funx/actions/workflows/ci.yml)  

[View the code on GitHub](https://github.com/JKWA/funx)  

Elixir is a dynamically typed language, which lacks the static type system that many functional languages use to enforce monadic patterns through the type checker. Instead, it relies on pattern matching, protocols, and structs to define and compose abstractions at runtime. These provide structure and behavioral guarantees, but not compile-time type safety.

Funx leverages these mechanisms to bring functional programming abstractions to Elixir.

## Equality

The `Eq` protocol defines how two values are compared, making equality explicit and adaptable to your domain.

- Define what “equal” means—compare by ID, name, or any derived attribute.
- Compose multiple comparisons—require all to match or just one.
- Implement for structs, built-in types, or custom comparators.

## Ordering

The `Ord` protocol defines ordering relationships in a structured way, without relying on Elixir’s built-in comparison operators.

- Define comparisons based on properties like size, age, or priority.
- Chain orderings to create fallback tiebreakers.
- Implement for any type, including custom structs.

## Monads

Monads encapsulate computations, allowing operations to be chained while handling concerns like absence, failure, dependency, or deferred effects.

- `Identity`: Wraps a value with no additional behavior—useful for organizing transformations.
- `Maybe`: Represents optional data using `Just` for presence and `Nothing` for absence.
- `Either`: Models computations with two possibilities—`Left` and `Right`.
- `Effect`: Encapsulates deferred execution with error handling, similar to `Task`.
- `Reader`: Passes an immutable environment through a computation for dependency injection or configuration.

## Monoids

Monoids combine values using an associative operation and an identity element. They are useful for accumulation, selection, and combining logic.

- `Sum`: Adds numbers (`0` is the identity).
- `Product`: Multiplies numbers (`1` is the identity).
- `Eq.All`: Values are equal only if all comparators agree.
- `Eq.Any`: Values are equal if any comparator agrees.
- `Predicate.All`: All predicates must hold.
- `Predicate.Any`: At least one predicate must hold.
- `Ord`: Defines ordering compositionally.
- `Max` and `Min`: Select the largest or smallest value by custom ordering.

## Predicates

Predicates are functions that return `true` or `false`. Funx provides combinators for composing them cleanly.

- `p_and`: Returns `true` if both predicates pass.
- `p_or`: Returns `true` if either predicate passes.
- `p_not`: Negates a predicate.
- `p_all`: Returns `true` if all predicates in a list pass.
- `p_any`: Returns `true` if any predicate in a list passes.
- `p_none`: Returns `true` if none pass.

## Folding

The `Foldable` protocol defines how to reduce a structure to a single result.

- `fold_l`: Reduces from the left, applying functions in order.
- `fold_r`: Reduces from the right, applying functions in reverse.

Useful for accumulating values, transforming collections, or extracting data.

## Filtering

The `Filterable` protocol defines how to conditionally retain values within a context.

- `guard`: Keeps a value if a condition is met; otherwise returns an empty context.
- `filter`: Retains values that satisfy a predicate.
- `filter_map`: Maps and filters in one pass, keeping transformed values that match a condition.

## Sequencing

Sequencing runs a series of monadic operations in order, combining the results.

- `concat/1`: Extracts `Just` values from a list of `Maybe`.
- `concat_map/2`: Maps a function over a list and collects the `Just` results.
- `sequence/1`: Converts a list of `Maybe` into a single `Maybe` containing a list, short-circuiting on `Nothing`.
- `traverse/2`: Applies a function that returns a `Maybe` to each element and sequences the results.

## Lifting

Lifting functions promote ordinary logic into a monadic context.

- `lift_predicate`: Wraps a value in a monad if a condition holds.
- `lift_eq`: Lifts an `Eq` comparator to work with `Maybe`.
- `lift_ord`: Lifts an `Ord` comparator to work with `Maybe`.

## Interop

Funx integrates with common Elixir patterns like `{:ok, value}` and `{:error, reason}`.

- `from_result`: Converts a result tuple into an `Either`.
- `to_result`: Converts an `Either` back into a result tuple.
- `from_try`: Wraps a function in an `Either`, catching exceptions as `Left`.
- `to_try!`: Extracts a value from an `Either`, or raises if it’s a `Left`.  

## Installation  

To use Funx, add it to the list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:funx, "~> 0.1.0"}
  ]
end
```

Then, run the following command to fetch the dependencies:

```bash
mix deps.get
```

## Documentation  

Full documentation is available on [GitHub Pages](https://jkwa.github.io/funx/readme.html).  

## Contributing  

1. Fork the repository.  
2. Create a new branch for the feature or bugfix (`git checkout -b feature-branch`).  
3. Commit changes (`git commit -am 'Add new feature'`).  
4. Push the branch (`git push origin feature-branch`).  
5. Create a pull request.  

## License  

This project is licensed under the MIT License.  
