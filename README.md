<p style="background-color: #38127C;">
  <img
  src="https://raw.githubusercontent.com/JKWA/funx/refs/heads/main/assets/images/funx-banner.jpg"
  alt="Funx Banner"
  height="120"/>
</p>

# Funx - Functional Programming Patterns for Elixir

[![Continuous Integration](https://github.com/JKWA/funx/actions/workflows/ci.yml/badge.svg)](https://github.com/JKWA/funx/actions/workflows/ci.yml)
[![Hex.pm](https://img.shields.io/hexpm/v/funx.svg)](https://hex.pm/packages/funx)

⚠️ **Beta:** Funx is in active development. APIs may change until version 1.0. Feedback and contributions are welcome.

**Official website:** [https://www.funxlib.com](https://www.funxlib.com)
**Code and API documentation:** [https://hex.pm/packages/funx](https://hex.pm/packages/funx)

## Breaking Changes in 0.6.0

If you're upgrading from 0.6.0 or earlier, be aware of the module reorganization:

### Eq changes

```elixir
# Change protocol implementations
defimpl Funx.Eq, for: MyStruct          # Old
defimpl Funx.Eq.Protocol, for: MyStruct  # New

# Change imports and aliases
alias Funx.Eq.Utils  # Old
use Funx.Eq.Dsl      # Old

use Funx.Eq          # New (imports eq DSL macro)
alias Funx.Eq        # New (for utility functions)

# Example usage
Eq.contramap(&(&1.age))
```

### Ord changes

```elixir
# Change protocol implementations
defimpl Funx.Ord, for: MyStruct          # Old
defimpl Funx.Ord.Protocol, for: MyStruct  # New

# Change imports and aliases
alias Funx.Ord.Utils  # Old
use Funx.Ord.Dsl      # Old

use Funx.Ord          # New (imports ord DSL macro)
alias Funx.Ord        # New (for utility functions)

# Example usage
Ord.contramap(&(&1.score))
```

See the [CHANGELOG](CHANGELOG.md) for more details.

## Installation  

To use Funx, add it to the list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:funx, "~> 0.7"}
  ]
end
```

Then, run the following command to fetch the dependencies:

```bash
mix deps.get
```

## Usage Rules

Funx includes embedded **usage rules** in addition to API documentation.  
They are written for development workflows assisted by LLMs.  

## Equality

The `Eq` protocol defines how two values are compared, making equality explicit and adaptable to your domain.

- Define what “equal” means—compare by ID, name, or any derived attribute.
- Compose multiple comparisons—require all to match or just one.
- Implement for structs, built-in types, or custom comparators.

## Ordering

The `Ord` protocol defines ordering relationships in a structured way, without relying on Elixir's built-in comparison operators.

- Define comparisons based on properties like size, age, or priority.
- Chain orderings to create fallback tiebreakers.
- Implement for any type, including custom structs.

### Ord DSL

The Ord module includes a DSL for building custom ordering comparators declaratively:

```elixir
use Funx.Ord

user_ord = ord do
  desc :priority
  asc :name
  desc :created_at
end

Enum.sort(users, Funx.Ord.comparator(user_ord))
```

Features:

- Multiple projections with `asc` and `desc` directions
- Automatic identity tiebreaker for deterministic ordering
- Support for optics (Lens, Prism), functions, and modules
- Ord variables for composing and reversing orderings

### Eq DSL

The Eq module includes a DSL for building equality comparators with boolean logic:

```elixir
use Funx.Eq

contact_eq = eq do
  on :name
  any do
    on :email
    on :username
  end
end

Funx.Eq.eq?(user1, user2, contact_eq)
```

Features:

- `on` - Field must be equal
- `diff_on` - Field must differ (non-equivalence constraint)
- `all` blocks - All checks must pass (AND logic)
- `any` blocks - At least one check must pass (OR logic)
- Support for optics, functions, and custom comparators

## Monads

Monads encapsulate computations, allowing operations to be chained while handling concerns like optional values, failures, dependencies, or deferred effects.

- `Identity`: Wraps a value with no additional behavior—useful for organizing transformations.
- `Maybe`: Represents optional data using `Just` for presence and `Nothing` for absence.
- `Either`: Models computations with two possibilities—`Left` and `Right`.
- `Effect`: Encapsulates deferred execution with error handling, similar to `Task`.
- `Reader`: Passes an immutable environment through a computation for dependency injection or configuration.
- `Writer`: Threads a log alongside a result using any monoid—useful for tracing, reporting, or accumulating metadata during computation.

### Either DSL

The Either monad includes a DSL for writing declarative pipelines that handle errors gracefully:

```elixir
use Funx.Monad.Either

either user_id do
  bind fetch_user()
  bind validate_active()
  map transform_to_dto()
end
```

Supported operations:

- `bind` - for operations that return Either or result tuples
- `map` - for transformations that return plain values
- `ap` - for applying a function in an Either to a value in an Either
- `validate` - for accumulating multiple validation errors
- Either functions: `filter_or_else`, `or_else`, `map_left`, `flip`, `tap`

**Formatter Configuration**: Funx exports formatter rules for clean DSL formatting. Add `:funx` to `import_deps` in your `.formatter.exs`:

```elixir
[
  import_deps: [:funx],
  inputs: ["{mix,.formatter}.exs", "{config,lib,test}/**/*.{ex,exs}"]
]
```

See [FORMATTER_EXPORT.md](FORMATTER_EXPORT.md) for details.

## Optics

Optics provide composable, lawful abstractions for focusing on and transforming parts of data structures.

- `Lens`: Total optic for required fields—raises if focus is missing. Use for fields that should always exist.
- `Prism`: Partial optic for optional fields—returns `Maybe`. Use for fields that may be absent or for selecting struct types.
- `Traversal`: Optic for accessing multiple foci simultaneously. Use for filtering collections, combining multiple optics, or working with list-like structures.
- `Iso`: Total optic for reversible representation changes. Use when two shapes carry the same information and you need guaranteed round trip conversion (`view` then `review`).

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
- `ListConcat`: Concatenates lists (`[]` is the identity).
- `StringConcat`: Concatenates strings (`""` is the identity).

## Predicates

Predicates are functions that return `true` or `false`. Funx provides combinators for composing them cleanly.

- `p_and`: Returns `true` if both predicates pass.
- `p_or`: Returns `true` if either predicate passes.
- `p_not`: Negates a predicate.
- `p_all`: Returns `true` if all predicates in a list pass.
- `p_any`: Returns `true` if any predicate in a list passes.
- `p_none`: Returns `true` if none pass.

### Pred DSL

The Predicate module includes a DSL for building boolean predicates declaratively:

```elixir
use Funx.Predicate

check_eligible = pred do
  check :age, fn age -> age >= 18 end
  check :verified, fn v -> v == true end
  any do
    check :role, fn r -> r == :admin end
    check :role, fn r -> r == :moderator end
  end
end

Enum.filter(users, check_eligible)
```

Features:

- `check` - Project into a field and test with a predicate
- `negate` - Invert a predicate (logical NOT)
- `all` blocks - All predicates must pass (AND logic)
- `any` blocks - At least one must pass (OR logic)
- Support for optics (Lens, Prism), functions, and behaviour modules

## Validation

The `Validate` module provides declarative data validation with applicative error accumulation—all validators run and all errors are collected.

### Validate DSL

```elixir
use Funx.Validate
alias Funx.Monad.Either
alias Funx.Validator.{Required, Email, MinLength, Positive}

user_validation =
  validate do
    at :name, [Required, {MinLength, min: 3}]
    at :email, [Required, Email]
    at :age, Positive
  end

Either.validate(%{name: "Alice", email: "alice@example.com", age: 30}, user_validation)
# => %Right{right: %{name: "Alice", email: "alice@example.com", age: 30}}

Either.validate(%{name: "", email: "bad", age: -5}, user_validation)
# => %Left{left: %ValidationError{errors: ["is required", "must be at least 3 characters", ...]}}
```

Features:

- `at :field, Validator` - Field validation using Prism (optional by default)
- `at [:a, :b], Validator` - Nested path validation
- `at Lens.key(:field), Validator` - Required field (raises if missing)
- Multiple validators: `[Required, Email]` or `{MinLength, min: 3}`
- Root validators for whole-structure validation
- Environment passing for context-dependent validation
- Composable validators that can be nested and reused

Built-in validators: `Required`, `Email`, `MinLength`, `MaxLength`, `Pattern`, `Positive`, `Negative`, `Integer`, `GreaterThan`, `LessThan`, `In`, `NotIn`, `Range`, `Each`, `Confirmation`, `Not`

## Folding

The `Foldable` protocol defines how to reduce a structure to a single result.

- `fold_l`: Reduces from the left, applying functions in order.
- `fold_r`: Reduces from the right, applying functions in reverse.

Useful for accumulating values, transforming collections, or extracting data.

## Filtering

The `Filterable` protocol defines how to conditionally retain values within a context.

- `guard`: Keeps a value if a condition is met; otherwise returns an empty context.
- `filter`: Retains values that satisfy a predicate.
- `filter_map`: Applies a transformation and keeps results only when the transformed value is present.

## Sequencing

Sequencing runs a series of monadic operations in order, combining the results.

- `concat/1`: Removes empty values and unwraps the present results from a list.
- `concat_map/2`: Applies a function to each element and collects only the present results.
- `sequence/1`: Converts a list of monadic values into a single monadic value containing a list. Short-circuits on the first failure or absence.
- `traverse/2`: Applies a function to each element and sequences the resulting monadic values.
- `sequence_a/1`: Applicative version of sequence—combines all and collects results.
- `traverse_a/2`: Applicative version of traverse—applies a function to each element and collects results.

## Lifting

Lifting functions promote ordinary logic into a monadic or contextual form.

- `lift_predicate/3`: Wraps a value in a monad if a condition holds; returns an empty or failed context otherwise.
- `lift_eq/1`: Adapts an `Eq` comparator to work within a monadic context.
- `lift_ord/1`: Adapts an `Ord` comparator to work within a monadic context.

## Interop

Funx integrates with common Elixir patterns like `{:ok, value}` and `{:error, reason}`.

- `from_result/1`: Converts a result tuple into a monadic context that distinguishes success from failure.
- `to_result/1`: Converts a monadic value back into a result tuple.
- `from_try/1`: Wraps a function call in a monad, capturing exceptions as failures.
- `to_try!/1`: Extracts the value from a monad or raises if it represents a failure.

## Documentation

The authoritative API documentation is published on [HexDocs](https://hexdocs.pm/funx).

## Learning Resources

- **[Funx Blog Posts](https://www.joekoski.com/categories/funx/)** - Articles and tutorials about using Funx, including deep dives into the Either DSL and functional programming patterns in Elixir

## Contributing  

1. Fork the repository.  
2. Create a new branch for the feature or bugfix (`git checkout -b feature-branch`).  
3. Commit changes (`git commit -am 'Add new feature'`).  
4. Push the branch (`git push origin feature-branch`).  
5. Create a pull request.  

## License  

This project is licensed under the MIT License.
