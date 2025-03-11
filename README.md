# Funx  

[![Continuous Integration](https://github.com/JKWA/funx/actions/workflows/ci.yml/badge.svg)](https://github.com/JKWA/funx/actions/workflows/ci.yml)  

[View the code on GitHub](https://github.com/JKWA/funx)  

Elixir is a dynamically typed language and does not have the static type system that many functional languages use to enforce monadic patterns. Instead, it relies on pattern matching, protocols, and structs to define structured abstractions. These mechanisms provide runtime guarantees but do not offer the compile-time type safety of statically typed languages.  

Funx leverages these principles to deliver functional programming abstractions for Elixir.  

## Equality  

The `Eq` protocol defines how two values should be compared, making equality explicit and adaptable to your domain.  

- Custom comparisons: Define what "equal" means—compare by ID, name, or any derived attribute.  
- Composable equality: Combine multiple checks—require all to match or just one.  
- Flexible implementation: Use `Eq` with structs, built-in types, or custom comparators.  

## Ordering  

The `Ord` protocol defines how values should be compared, making ordering explicit and adaptable to different contexts. Instead of relying on Elixir’s built-in comparison operators, `Ord` provides a structured approach to defining and composing order relations.  

- Custom ordering: Define comparisons based on any property, such as size, age, or priority.  
- Composable comparisons: Chain multiple orderings to provide tiebreakers when needed.  
- Works with any type: Implement `Ord` for structs or use it with built-in types.  

## Monads  

A monad encapsulates computations, allowing operations to be chained while handling concerns like optional values, errors, dependencies, and effects.  

- Identity: Wraps a value without additional behavior, serving as a minimal monad useful for structuring transformations.  
- Maybe: Represents optional values using `Just` for presence and `Nothing` for absence.  
- Either: Models computations that can fail, with `Left` for errors and `Right` for success.  
- Effect: Encapsulates deferred computations, combining asynchronous execution and error handling.  
- Reader: Passes an immutable environment through a computation, useful for dependency injection and contextual data.

## Monoids  

A monoid combines values using an associative operation with an identity element.  

- Sum: Adds numbers, identity is `0`.  
- Product: Multiplies numbers, identity is `1`.  
- Eq All: Values are equal only if all comparators agree.  
- Eq Any: Values are equal if at least one comparator agrees.  
- Predicate All: Returns `true` only if all predicates hold.  
- Predicate Any: Returns `true` if at least one predicate holds.  
- Ord: Defines structured comparisons instead of relying on built-in operators.  
- Max and Min: Select the largest or smallest value based on ordering.  

Monoids provide a foundation for structuring accumulation and combination in a predictable way.  

## Predicates  

A predicate is a function that returns `true` or `false`. This module provides functions for composing predicates declaratively.  

- `p_and`: Returns `true` if both predicates are `true`.  
- `p_or`: Returns `true` if at least one predicate is `true`.  
- `p_not`: Negates a predicate.  
- `p_all`: Returns `true` if all predicates in a list are `true`.  
- `p_any`: Returns `true` if any predicate in a list is `true`.  
- `p_none`: Returns `true` if none of the predicates in a list are `true`.  

These functions make it easy to express complex conditions without nested logic.  

## Folding  

The `Foldable` protocol allows structures to be collapsed into a single value.  

- `fold_l`: Folds a structure from the left, applying transformations sequentially.  
- `fold_r`: Folds a structure from the right, applying transformations in reverse order.  

Folding is useful for reducing structures to a single result, such as computing sums, aggregating values, or extracting optional data.  

## Filtering  

The `Filterable` protocol defines functions for conditionally retaining or discarding values within a context.  

- `guard`: Keeps a value if a condition is met; otherwise, returns an empty value for the context.  
- `filter`: Retains values that satisfy a given predicate.  
- `filter_map`: Combines filtering and mapping in one step, keeping transformed values that satisfy a condition.  

Filtering helps manage conditional logic cleanly, allowing transformation and selection in a single operation.  

## Sequencing  

Funx provides tools for sequencing computations within a monadic context:  

- `sequence`: Converts a list of monads into a monad containing a list, propagating failures if any exist.  
- `traverse`: Applies a function to each element in a list that returns monads, sequencing the results.  

## Lifting  

Lifting functions allow transforming values into monadic contexts:  

- `lift_predicate`: Converts a value into a `Maybe`, `Either`, or another monad based on a condition.  
- `lift_eq`: Lifts an equality function to work within a `Maybe` context.  
- `lift_ord`: Lifts an ordering function to work with `Maybe`.  

## Interop  

Funx integrates with common Elixir idioms like `{:ok, value}` and `{:error, reason}` tuples:  

- `from_result`: Converts a result tuple into an `Either` monad.  
- `to_result`: Converts an `Either` monad back into a result tuple.  
- `from_try`: Wraps a function in an `Either`, catching exceptions as `Left`.  
- `to_try!`: Extracts a value from an `Either` or raises an exception if it is a `Left`.  

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
