# `Funx.Monad.Either` Usage Rules

## LLM Functional Programming Foundation

**Key Concepts for LLMs:**

**CRITICAL Elixir Implementation**: All monadic operations are under `Funx.Monad` protocol

- **NO separate Functor/Applicative protocols** - Elixir protocols cannot be extended after definition
- Always use `Monad.map/2`, `Monad.bind/2`, `Monad.ap/2` or import `Funx.Monad`
- Different from Haskell's separate Functor, Applicative, Monad typeclasses

**Either**: Represents immediate success/failure with detailed error context

- `left(error)` represents failure with error information
- `right(value)` represents success with the actual value
- **Right-biased**: Operations work on the Right (success) path
- **Immediate/Synchronous**: Values exist right now, no deferred execution
- **No concurrency**: All operations are synchronous - use Effect for async operations

**Right-biased Monad**: Operations transform Right values, preserve Left errors

- `map/2`, `bind/2`, `ap/2` only operate on Right values
- Left values (errors) pass through unchanged
- Similar to Maybe but with error context preserved

**Validation vs Error-handling**: Two distinct patterns

- **Validation**: Use `traverse_a/2` to collect ALL errors
- **Error-handling**: Use `bind/2` chains that stop on first error
- **Critical difference**: validation accumulates, error-handling short-circuits

**Kleisli Functions**: Functions `a -> Either e b` (unwrapped input, wrapped output)

- **Primary use**: `traverse/2`, `traverse_a/2`, and `concat_map/2` for list operations
- **Individual use**: `bind/2` for single Either values
- Example: `validate_email :: String -> Either ValidationError Email`

**Key List Operation Patterns:**

- `concat([Either e a])` → `[a]` (extract all Right values, ignore Left)
- `concat_map([a], kleisli_fn)` → `[b]` (apply Kleisli, collect Right results)
- `traverse([a], kleisli_fn)` → `Either e [b]` (apply Kleisli, all succeed or first Left)
- `traverse_a([a], kleisli_fn)` → `Either [e] [b]` (apply Kleisli, all succeed or collect all Left)
- `sequence([Either e a])` → `Either e [a]` (like traverse with identity, first Left or all Right)

**Sequence (Category Theory)**: Transform type constructor order

- `[Either e a]` → `Either e [a]` (list of Either becomes Either of list)
- Fails fast: first Left value becomes the result
- Success: all Right values collected into Right list

## LLM Decision Guide: When to Use Either

**✅ Use Either when:**

- Need specific error context/details
- Multiple validation steps with different error types  
- Business logic with detailed failure messages
- Error recovery or different handling per error type
- User says: "validate", "check", "ensure", "verify", "error details"

**❌ Use Effect when:**

- Async operations (database calls, HTTP requests, file I/O)
- Need concurrency or deferred execution
- Operations that take significant time
- User says: "async", "concurrent", "fetch", "call API"

**❌ Use Maybe when:**

- Simple presence/absence (no error context needed)
- "Not found" is sufficient error information
- Optional fields where missing is normal

**⚡ Either Strategy Decision:**

- **Single operation error-handling**: Use `bind/2` chains
- **Multi-field validation**: Use `validate/2` to collect all errors
- **Transform success values**: Use `map/2` with regular functions
- **Combine Either values**: Use `ap/2` for applicative patterns
- **Convert from Maybe**: Use `maybe_to_either/2` with error message
- **Pattern match results**: Use `%Left{left: error}` and `%Right{right: value}` struct patterns

**⚙️ Function Choice Guide (Mathematical Purpose):**

- **Chain error-prone operations**: `bind/2` with Kleisli functions
- **Transform success values**: `map/2` with regular functions
- **Validate multiple fields**: `validate/2` for comprehensive error collection
- **Apply functions to multiple Either**: `ap/2` for combining contexts
- **Convert lists**: `sequence/1` to collect successes or first failure
- **Handle specific errors**: Pattern match Left values for recovery

## LLM Context Clues

**User language → Either patterns:**

- "validate user input" → Use Either for validation with specific error messages
- "parse and validate" → Chain with `bind/2` for step-by-step validation
- "check all fields" → Use `validate/2` to collect all validation errors
- "detailed error messages" → Left values contain specific error information
- "stop on first error" → Use `bind/2` chains for fail-fast behavior
- "collect all errors" → Use `validate/2` for comprehensive validation

## Quick Reference

- Use `right(value)` for success, `left(error)` for failure
- Chain operations with `bind/2` - stops on first Left (error)
- Transform success values with `map/2` - leaves Left unchanged  
- Use `bind/2` with identity to flatten nested Either values
- Validate data comprehensively with `validate/2` - collects all errors
- **Prefer `fold_l/3` over pattern matching** for functional case analysis
- Import `Funx.Monad` for `map`, `bind`, `ap` and `Funx.Foldable` for `fold_l`
- Convert from Maybe with error context using helper functions

## Either DSL

The Either monad includes a declarative DSL for writing error-handling pipelines without explicit `bind`, `map`, or `ap` calls.

**Design Philosophy:**

- **Surface intent over implementation** - Focus on what the code does, not how
- **Declarative error handling** - Let the DSL manage branching and short-circuits
- **Pipeline-friendly** - Works naturally with Elixir's pipeline syntax
- **Safer than bang functions** - Handle errors explicitly without sacrificing ergonomics
- **Kleisli composition** - Chain operations that return branching types (Either, result tuples)

**Key Benefits:**

- Automatic input lifting (plain values, result tuples, Either values)
- Short-circuits on first error (fail-fast behavior)
- Compile-time warnings for common mistakes (bind vs map usage)
- Multiple output formats (Either, tuple, or raise)
- Clean, readable syntax for complex error-handling flows
- More ergonomic than manual Either operations while maintaining safety

### Basic Usage

```elixir
use Funx.Monad.Either

either user_id do
  bind fetch_user()
  bind validate_active()
  map transform_to_dto()
end
```

### Practical Comparison: Before and After

**Traditional Elixir with bang functions (unsafe):**

```elixir
def handle_close_assignment(id) do
  assignment = Ash.get!(Assignment, id)  # Might crash!

  case close_assignment(assignment) do
    {:ok, updated} ->
      updated = Ash.load!(updated, [:status, :user])  # Might crash!
      {:ok, updated}

    {:error, error} ->
      {:error, error}
  end
end
```

**With Either DSL (safe and ergonomic):**

```elixir
def handle_close_assignment(id) do
  either Assignment, as: :tuple do
    bind Ash.get(id)
    bind close_assignment()
    bind Ash.load([:status, :user])
  end
end
```

The DSL version:

- ✅ Handles all errors explicitly (no hidden crashes)
- ✅ More concise (5 lines vs 10 lines)
- ✅ Clearer intent (declarative pipeline)
- ✅ All operations can fail safely

### Supported Operations

- `bind` - Chain operations that return Either or `{:ok, value}` / `{:error, reason}` tuples
- `map` - Transform values with functions that return plain values
- `ap` - Apply a function wrapped in Either to a value wrapped in Either
- `validate` - Collect all validation errors from multiple validators
- Either functions: `filter_or_else`, `or_else`, `map_left`, `flip`

### DSL Examples

**Basic pipeline with bind and map:**

```elixir
either "42" do
  bind parse_int()
  bind validate_positive()
  map double()
end
# right(84)
```

**Using ap to apply wrapped functions:**

```elixir
either 5 do
  map fn x -> &(&1 + x) end  # Returns Right(fn y -> y + 5 end)
  ap right(10)               # Applies function to 10
end
# right(15)
```

**Validation with error collection:**

```elixir
either user_data do
  validate [
    validate_name(),
    validate_email(),
    validate_age()
  ]
end
# Collects all validation errors if any fail
```

**Filter with predicate:**

```elixir
either user do
  bind fetch_user()
  filter_or_else fn u -> u.level >= 10 end, fn -> "Level too low" end
end
```

**Error recovery with or_else:**

```elixir
either user_id do
  bind fetch_user()
  or_else fn -> right(default_user()) end
end
```

**Transform errors with map_left:**

```elixir
either input do
  bind parse_json()
  map_left fn error -> "Parse failed: #{error}" end
end
```

### Output Formats

**Default - Either (default):**

```elixir
either user_id do
  bind fetch_user()
end
# Returns: right(%User{}) or left("error")
```

**Tuple format (`:tuple`):**

```elixir
either user_id, as: :tuple do
  bind fetch_user()
  map format_response()
end
# Returns: {:ok, response} or {:error, reason}
```

**Raise on error (`:raise`):**

```elixir
either config_path, as: :raise do
  bind read_file()
  bind parse_json()
end
# Returns: parsed value or raises RuntimeError
```

### Function Call Lifting

The DSL automatically lifts function call syntax for cleaner pipelines:

```elixir
# Zero-arity qualified calls → function capture
either user_id do
  bind Repo.fetch_user()  # Becomes: &Repo.fetch_user/1
end

# Zero-arity bare calls → function capture
either user_id do
  bind validate_user()    # Becomes: &validate_user/1
end

# Partial application with arguments
either user_id do
  bind Repo.fetch_user(preload: :posts)  # Becomes: fn x -> Repo.fetch_user(x, preload: :posts) end
end

# Module references
either user_id do
  bind ParseInt           # Calls: ParseInt.run(user_id, [], env)
  bind {ParseInt, base: 16}  # Calls: ParseInt.run(user_id, [base: 16], env)
end
```

**This means you write:**

```elixir
either data do
  bind parse_json()
  bind validate_schema()
end
```

**Instead of:**

```elixir
Either.right(data)
|> bind(&parse_json/1)
|> bind(&validate_schema/1)
```

### Input Lifting

The DSL automatically lifts various input types:

```elixir
# Plain values → Right
either 42 do
  map &(&1 * 2)
end
# right(84)

# Result tuples → Either
either {:ok, 42} do
  map &(&1 * 2)
end
# right(84)

either {:error, "fail"} do
  map &(&1 * 2)
end
# left("fail") - map never runs

# Either values pass through
either right(42) do
  map &(&1 * 2)
end
# right(84)

either left("error") do
  map &(&1 * 2)
end
# left("error") - short-circuits immediately
```

### Module-Based Operations

Create reusable operations as modules with `run/3`:

```elixir
defmodule ParseInt do
  @behaviour Funx.Monad.Either.Dsl.Behaviour
  use Funx.Monad.Either

  def run(str, _opts, _env) do
    case Integer.parse(str) do
      {int, ""} -> right(int)
      _ -> left("Invalid integer: #{str}")
    end
  end
end

# Use in pipelines
either "42" do
  bind ParseInt
  map &(&1 * 2)
end

# With options
defmodule ParseIntWithBase do
  @behaviour Funx.Monad.Either.Dsl.Behaviour
  use Funx.Monad.Either

  def run(str, opts, _env) do
    base = Keyword.get(opts, :base, 10)
    case Integer.parse(str, base) do
      {int, ""} -> right(int)
      _ -> left("Invalid integer in base #{base}: #{str}")
    end
  end
end

either "FF" do
  bind {ParseIntWithBase, base: 16}
end
# right(255)
```

### Compile-Time Safety

**Warning: bind with plain value returns:**

```elixir
# ⚠️ Compile warning - function returns plain value, should use 'map'
either 5 do
  bind fn x -> x * 2 end
end
```

**Warning: map with Either returns:**

```elixir
# ⚠️ Compile warning - function returns Either, should use 'bind'
either 5 do
  map fn x -> right(x * 2) end
end
```

### When to Use the DSL

**✅ Use the DSL when:**

- You have multiple sequential operations that may fail
- You want declarative, readable error-handling pipelines
- You're combining bind, map, and validation operations
- You prefer pipeline syntax over explicit function calls
- You need automatic input lifting and type conversions
- You want compile-time safety checks

**❌ Use direct functions when:**

- You only need one or two operations
- You need complex branching or conditionals
- You're implementing reusable combinators
- Performance is critical (DSL has minimal but non-zero overhead)
- You need fine-grained control over the monad operations

### Formatter Configuration

Funx exports formatter rules for clean DSL formatting without parentheses. To enable in your project:

**Add to `.formatter.exs`:**

```elixir
[
  import_deps: [:funx],
  inputs: ["{mix,.formatter}.exs", "{config,lib,test}/**/*.{ex,exs}"]
]
```

**This formats DSL code cleanly:**

```elixir
# With formatter rules (clean)
either user_id do
  bind fetch_user()
  map format_response()
end

# Without formatter rules (parentheses added)
either(user_id) do
  bind(fetch_user())
  map(format_response())
end
```

## Overview

`Funx.Monad.Either` handles success/failure scenarios with detailed error context.

Use Either for:

- Parsing and validation with specific error messages
- Operations that can fail in multiple ways
- Business logic where error details matter for recovery
- API responses where clients need error specifics

**Key insight**: Either represents "success or failure" with the failure carrying detailed information. Right-biased operations focus on the success path while preserving any errors encountered.

## Constructors

### `right/1` - Wrap a Success Value

Creates an Either representing success:

```elixir
Either.right(42)           # Success: contains 42
Either.right("valid")      # Success: contains "valid"
Either.right([1, 2, 3])    # Success: contains [1, 2, 3]
```

### `left/1` - Wrap an Error Value

Creates an Either representing failure:

```elixir
Either.left("error")                    # Failure: contains error message
Either.left({:validation, "invalid"})   # Failure: structured error
Either.left(%ValidationError{})         # Failure: error struct
```

### `pure/1` - Alias for `right/1`

Alternative constructor for success values:

```elixir
Either.pure(42)    # Same as Either.right(42)
```

## Core Operations

### `map/2` - Transform Success Values

Applies a function to Right values, leaves Left values unchanged:

```elixir
import Funx.Monad
import Funx.Foldable

Either.right("hello")
|> map(&String.upcase/1)        # right("HELLO")

Either.left("error")  
|> map(&String.upcase/1)        # left("error") - function never runs
```

**Use `map` when:**

- You want to transform the success value
- The transformation function returns a plain value (not wrapped in Either)
- You want to preserve the Either structure

### `bind/2` - Chain Error-Prone Operations

Chains operations that return Either values, for fail-fast error handling:

```elixir
import Funx.Monad
import Funx.Foldable

# These functions return Either values
parse_int = fn s -> 
  case Integer.parse(s) do
    {int, ""} -> Either.right(int)
    _ -> Either.left("Invalid integer: #{s}")
  end
end

validate_positive = fn n ->
  if n > 0 do
    Either.right(n)
  else 
    Either.left("Must be positive: #{n}")
  end
end

Either.right("42")
|> bind(parse_int)           # right(42)
|> bind(validate_positive)   # right(42)

Either.right("invalid")
|> bind(parse_int)           # left("Invalid integer: invalid") - chain stops
|> bind(validate_positive)   # left("Invalid integer: invalid") - never runs
```

**Use `bind` when:**

- You're chaining operations that each can fail
- Each step depends on the success of the previous step
- You want fail-fast behavior (stop on first error)

**Common bind pattern:**

```elixir
def process_user_input(input) do
  Either.right(input)
  |> bind(&parse_user_data/1)      # String -> Either Error UserData
  |> bind(&validate_user_data/1)   # UserData -> Either Error ValidUser
  |> bind(&save_user/1)            # ValidUser -> Either Error SavedUser
end
```

### `ap/2` - Apply Functions Across Either Values

Applies a function in an Either to a value in an Either:

```elixir
import Funx.Monad
import Funx.Foldable

# Apply a wrapped function to wrapped values
Either.right(fn x -> x + 10 end)
|> ap(Either.right(5))          # right(15)

# Combine multiple Either values
add = fn x -> fn y -> x + y end end

Either.right(add)
|> ap(Either.right(3))          # right(fn y -> 3 + y end)  
|> ap(Either.right(4))          # right(7)

# If any value is left, result is left
Either.right(add)
|> ap(Either.left("error1"))    # left("error1")
|> ap(Either.right(4))          # left("error1")
```

**Use `ap` when:**

- You want to apply a function to multiple Either values
- You need all values to be Right for the operation to succeed
- You're implementing applicative patterns

### Flattening Nested Either Values with `bind`

Since there's no `join/1` function, use `bind/2` with the identity function to flatten nested Either values:

```elixir
import Funx.Monad
import Funx.Foldable

# Flatten nested Right using bind
nested_right = Either.right(Either.right(42))
bind(nested_right, fn inner -> inner end)    # right(42)

# Left in outer - stays Left
outer_left = Either.left("outer error")
bind(outer_left, fn inner -> inner end)      # left("outer error")

# Left in inner - becomes Left
inner_left = Either.right(Either.left("inner error"))
bind(inner_left, fn inner -> inner end)      # left("inner error")
```

**Use this pattern when:**

- You have nested Either values that need flattening
- You're implementing monadic operations manually
- You're working with higher-order Either computations

### `tap/2` - Side Effects Without Changing Values

Executes a side-effect function on a Right value and returns the original Either unchanged. If the Either is Left, the function is not called:

```elixir
import Funx.Monad.Either

# Side effect on Right
Either.right(42)
|> Tappable.tap(&IO.inspect(&1, label: "debug"))  # prints "debug: 42"
# Returns: right(42)

# No side effect on Left
Either.left("error")
|> Tappable.tap(&IO.inspect(&1, label: "debug"))  # nothing printed
# Returns: left("error")
```

**Use `tap` when:**

- Debugging pipelines - inspect intermediate values without breaking the chain
- Logging - record values as they flow through computations
- Metrics/telemetry - emit events based on success values
- Side effects - perform actions (like notifications) without changing the computation result

**Common tap patterns:**

```elixir
# Debug a pipeline
Either.right(user_input)
|> bind(&parse_user/1)
|> Tappable.tap(&IO.inspect(&1, label: "after parse"))
|> bind(&validate_user/1)
|> Tappable.tap(&IO.inspect(&1, label: "after validate"))
|> bind(&save_user/1)

# Logging in business logic
process_order(order_id)
|> Tappable.tap(fn order -> Logger.info("Processing order #{order.id}") end)
|> bind(&charge_payment/1)
|> Tappable.tap(fn _ -> Logger.info("Payment successful") end)

# Telemetry
calculate_result(data)
|> Tappable.tap(fn result ->
  :telemetry.execute([:app, :calculation], %{value: result})
end)
```

**Important notes:**

- The function's return value is discarded
- Only executes on Right values (success path)
- Does not affect the Either value or its error state
- In the Either DSL, you must use `Tappable.tap` (not `Kernel.tap`) to avoid conflicts

## List Operations

### `concat/1` - Extract All Right Values

Removes all Left values and unwraps Right values from a list:

```elixir
Either.concat([
  Either.right(1),
  Either.left("error1"),
  Either.right(3),
  Either.left("error2")
])                              # [1, 3]
```

### `validate/2` - Comprehensive Data Validation

The high-level validation function that collects ALL errors from multiple validators:

```elixir
# Basic validation with error lists
validate_positive = fn n ->
  if n > 0, do: Either.right(n), else: Either.left(["Must be positive"])
end

validate_even = fn n ->
  if rem(n, 2) == 0, do: Either.right(n), else: Either.left(["Must be even"])
end

Either.validate(3, [validate_positive, validate_even])
# left(["Must be even"])

Either.validate(-2, [validate_positive, validate_even])  
# left(["Must be positive"])
```

**Use `validate` when:**

- You need comprehensive validation with ALL error details
- You're validating forms or user input
- You want to show users all validation problems at once
- You need to apply multiple validation rules to a single value

### Validation with ValidationError

For comprehensive domain validation with structured error handling, use `Funx.Errors.ValidationError`:

```elixir
alias Funx.Errors.ValidationError

# Wrap simple errors in ValidationError
validate_age = fn age ->
  Either.lift_predicate(age, &(&1 >= 18), "Must be 18 or older")
  |> Either.map_left(&ValidationError.new/1)
end

Either.validate(user, [validate_age])
# left(ValidationError{errors: ["Must be 18 or older"]})
```

**See `ValidationError` usage rules for advanced patterns:**

- Curried validation functions with `curry_r/1`
- Fallback validation with `Either.or_else/2`
- Error message transformation techniques
- Group validation with `traverse/2` and `traverse_a/2`
- Sequential vs comprehensive validation strategies

### `concat_map/2` - Apply Function and Collect Rights

Applies a function to each element, collecting only Right results:

### `traverse/2` - Apply Kleisli to List (First Error or All Success)

Applies a Kleisli function to each element, stopping at first Left:

```elixir
import Funx.Monad
import Funx.Foldable

# Kleisli function: String -> Either String Integer
parse_number = fn str ->
  case Integer.parse(str) do
    {num, ""} -> Either.right(num)
    _ -> Either.left("Invalid number: #{str}")
  end
end

# All succeed - get Either list
Either.traverse(["1", "2", "3"], parse_number)  # right([1, 2, 3])

# First failure stops processing
Either.traverse(["1", "invalid", "3"], parse_number)  
# left("Invalid number: invalid")
```

**Use `traverse` when:**

- All operations must succeed for meaningful result
- You want fail-fast behavior on lists
- Converting `[a]` to `Either e [b]` with validation

### `traverse_a/2` - Apply Kleisli to List (Collect All Errors)

Applies a Kleisli function to each element, collecting ALL errors:

```elixir
# Same Kleisli function as above, but returns error lists for accumulation
validate_number = fn str ->
  case Integer.parse(str) do
    {num, ""} -> Either.right(num)
    _ -> Either.left(["Invalid number: #{str}"])  # List for accumulation
  end
end

# Collect ALL errors
Either.traverse_a(["1", "invalid", "3", "bad"], validate_number)
# left(["Invalid number: invalid", "Invalid number: bad"])

# All succeed - get Right list
Either.traverse_a(["1", "2", "3"], validate_number)  # right([1, 2, 3])
```

**Use `traverse_a` when:**

- You want to collect ALL errors from validation
- You need comprehensive error reporting
- You're implementing validation that shows all problems at once

### `concat_map/2` - Apply Kleisli to List (Collect Successes)

Applies a Kleisli function to each element, collecting only successful results:

```elixir
# Collect only successes - get plain list
Either.concat_map(["1", "invalid", "3", "bad"], parse_number)  # [1, 3]

# All succeed - get all results
Either.concat_map(["1", "2", "3"], parse_number)  # [1, 2, 3]

# All fail - get empty list
Either.concat_map(["bad", "invalid", "error"], parse_number)  # []
```

**Use `concat_map` when:**

- Partial success is acceptable
- You want to collect all valid results
- You need resilient processing that continues on failure

### `sequence/1` - Convert List of Either to Either List

Converts `[Either e a]` to `Either e [a]` - equivalent to `traverse` with identity function:

```elixir
# All success - collect values
Either.sequence([
  Either.right(1),
  Either.right(2),
  Either.right(3)
])                              # right([1, 2, 3])

# First failure stops and returns that error
Either.sequence([
  Either.right(1),
  Either.left("error2"),
  Either.left("error3")
])                              # left("error2")

# Relationship to traverse
Either.sequence(either_list) == Either.traverse(either_list, fn x -> x end)
```

**Use `sequence` when:**

- You have a list of Either values from previous computations
- You want all to succeed, or the first failure
- You're collecting results from multiple operations

### Operation Comparison

```elixir
user_data = ["valid@email.com", "invalid-email", "another@valid.com", "bad-format"]

# traverse: Stop at first error
Either.traverse(user_data, &validate_email/1)
# left("Invalid email format: invalid-email")

# traverse_a: Collect all errors  
Either.traverse_a(user_data, &validate_email_with_list_error/1)
# left(["Invalid email format: invalid-email", "Invalid email format: bad-format"])

# concat_map: Collect successes, ignore failures
Either.concat_map(user_data, &validate_email/1)
# ["valid@email.com", "another@valid.com"]
```

## Validation

Validation is a specialized use of Either for comprehensive error collection.

See the `validate/2` function in the List Operations section above.

## Lifting

### `lift_predicate/3` - Convert Predicate to Either

Converts a predicate function into Either-returning validation:

```elixir
validate_positive = Either.lift_predicate(&(&1 > 0), "Must be positive")

validate_positive.(5)   # right(5)
validate_positive.(-1)  # left("Must be positive")
```

### `lift_maybe/2` - Convert Maybe to Either

Converts a Maybe to Either with error context:

```elixir
maybe_user = Maybe.just(%{name: "Alice"})
Either.lift_maybe(maybe_user, "User not found")  # right(%{name: "Alice"})

Maybe.nothing() |> Either.lift_maybe("User not found")  # left("User not found")
```

### `lift_eq/1` and `lift_ord/1` - Lift Comparison Functions

Lifts comparison functions for use in Either context:

```elixir
# Lift equality for Either values
Either.lift_eq(&==/2)

# Lift ordering for Either values  
Either.lift_ord(&compare/2)
```

## Elixir Interoperability

### `from_result/1` - Convert from Result Tuples

```elixir
# Convert from {:ok, value} | {:error, reason} tuples
Either.from_result({:ok, 42})         # right(42)
Either.from_result({:error, "fail"})  # left("fail")
```

### `to_result/1` - Convert to Result Tuples

```elixir
# Convert to {:ok, value} | {:error, reason} tuples
Either.to_result(Either.right(42))        # {:ok, 42}
Either.to_result(Either.left("fail"))     # {:error, "fail"}
```

### `from_try/1` - Safe Function Execution

```elixir
# Run function safely, catching exceptions
Either.from_try(fn -> 42 / 0 end)  # left(%ArithmeticError{})
Either.from_try(fn -> 42 / 2 end)  # right(21.0)
```

### `to_try!/1` - Unwrap or Raise

```elixir
Either.to_try!(Either.right(42))       # 42
Either.to_try!(Either.left("error"))   # raises RuntimeError: "error"
```

## Folding Either Values

**Core Concept**: Both `Left` and `Right` implement the `Funx.Foldable` protocol, providing `fold_l/3` for catamorphism (breaking down data structures).

### `fold_l/3` - Functional Case Analysis

The fundamental operation for handling Either values without pattern matching:

```elixir
import Funx.Foldable

# fold_l(either_value, right_function, left_function)
result = fold_l(either_value, 
  fn success_value -> "Success: #{success_value}" end,  # Right case
  fn error_value -> "Error: #{error_value}" end        # Left case
)

# Examples
fold_l(Either.right(42), 
  fn value -> value * 2 end,     # Runs this: 84
  fn error -> 0 end              # Never runs
)

fold_l(Either.left("failed"), 
  fn value -> value * 2 end,     # Never runs
  fn error -> "Got: #{error}" end # Runs this: "Got: failed"
)
```

**Use `fold_l` when:**

- You need to convert Either to a different type
- You want functional case analysis without pattern matching
- You're implementing higher-level combinators
- You need to handle both success and error cases

### Folding vs Pattern Matching

```elixir
# ❌ Imperative pattern matching
case either_result do
  %Right{right: value} -> "Success: #{value}"
  %Left{left: error} -> "Error: #{error}"
end

# ✅ Functional folding
fold_l(either_result,
  fn value -> "Success: #{value}" end,
  fn error -> "Error: #{error}" end
)
```

### Advanced Folding Patterns

```elixir
# Convert Either to Result tuple
to_result = fn either ->
  fold_l(either,
    fn value -> {:ok, value} end,
    fn error -> {:error, error} end
  )
end

# Extract value with default
get_or_default = fn either, default ->
  fold_l(either,
    fn value -> value end,
    fn _error -> default end
  )
end

# Conditional processing based on Either state
process_conditionally = fn either ->
  fold_l(either,
    fn value -> expensive_success_operation(value) end,
    fn error -> log_error_and_return_default(error) end
  )
end
```

**When pattern matching is still appropriate:**

```elixir
# Complex data destructuring that fold_l can't handle elegantly
case either_result do
  %Right{right: %User{name: name, role: :admin, permissions: perms}} -> 
    handle_admin(name, perms)
  %Right{right: %User{role: :user} = user} -> 
    handle_regular_user(user)
  %Left{left: %ValidationError{field: field, message: msg}} -> 
    handle_validation_error(field, msg)
  %Left{left: error} -> 
    handle_generic_error(error)
end
```

## Validation Patterns

### Error-handling (Fail Fast)

Use `bind/2` for operations that should stop on the first error:

```elixir
def process_payment(payment_data) do
  Either.right(payment_data)
  |> bind(&validate_card_number/1)     # Stop if card invalid
  |> bind(&validate_expiry_date/1)     # Stop if expiry invalid  
  |> bind(&validate_cvv/1)             # Stop if CVV invalid
  |> bind(&charge_card/1)              # Stop if charge fails
end
```

### Validation (Collect All Errors)

Use `traverse_a/2` to collect all validation errors:

```elixir
def validate_user_registration(data) do
  fields = [data.name, data.email, data.password, data.age]
  validators = [
    &validate_name/1,
    &validate_email/1, 
    &validate_password/1,
    &validate_age/1
  ]
  
  Either.traverse_a(fields, validators)
  |> fold_l(
    fn [name, email, password, age] -> 
      {:ok, %User{name: name, email: email, password: password, age: age}}
    end,
    fn errors -> {:error, List.flatten(errors)} end
  )
end
```

## Refinement

### `right?/1` and `left?/1` - Type Checks

```elixir
Either.right?(Either.right(42))      # true
Either.right?(Either.left("err"))    # false

Either.left?(Either.left("err"))     # true
Either.left?(Either.right(42))       # false
```

## Fallback and Extraction

### `get_or_else/2` - Extract Value with Default

```elixir
Either.right(42) |> Either.get_or_else(0)        # 42
Either.left("error") |> Either.get_or_else(0)    # 0
```

### `or_else/2` - Fallback on Left

```elixir
Either.right(42) |> Either.or_else(fn -> Either.right(0) end)     # right(42)
Either.left("error") |> Either.or_else(fn -> Either.right(0) end) # right(0)
```

### `map_left/2` - Transform Left Values

```elixir
# Transform error without affecting success
Either.right(42) |> Either.map_left(&String.upcase/1)     # right(42)
Either.left("error") |> Either.map_left(&String.upcase/1) # left("ERROR")
```

### `flip/1` - Swap Left and Right

```elixir
Either.flip(Either.right(42))           # left(42)
Either.flip(Either.left("error"))       # right("error")
```

### `filter_or_else/3` - Conditional Left Conversion

```elixir
# Convert Right to Left if predicate fails
Either.right(42) |> Either.filter_or_else(&(&1 > 50), "too small")  # left("too small")
Either.right(100) |> Either.filter_or_else(&(&1 > 50), "too small") # right(100)
```

### Combining Two Either Values with `ap/2`

Use the applicative pattern with `ap/2` to combine two Either values with a binary function:

```elixir
import Funx.Monad
import Funx.Foldable

# Combine two Either values using ap
add_fn = Either.right(&+/2)
ap(add_fn, Either.right(3)) |> ap(Either.right(4))     # right(7)
ap(add_fn, Either.right(3)) |> ap(Either.left("error"))   # left("error")
ap(add_fn, Either.left("error")) |> ap(Either.right(4))   # left("error")

# More concise with helper function
combine_either = fn ma, mb, f ->
  Either.right(f) |> ap(ma) |> ap(mb)
end

combine_either.(Either.right(3), Either.right(4), &+/2)         # right(7)
combine_either.(Either.right(3), Either.left("error"), &+/2)    # left("error")

# String concatenation
combine_either.(Either.right("Hello, "), Either.right("World!"), &<>/2)  # right("Hello, World!")

# Validation combining
combine_either.(
  validate_name("Alice"),
  validate_age(30),
  fn name, age -> %{name: name, age: age} end
)  # right(%{name: "Alice", age: 30}) or left(error)
```

**Use this pattern when:**

- You need to combine exactly two Either values with a binary function
- You want applicative-style combination that fails fast on first Left
- You're implementing patterns similar to liftA2 from other functional languages

## Common Patterns

### API Response Handling

```elixir
def fetch_user_profile(user_id) do
  Either.right(user_id)
  |> bind(&validate_user_id/1)        # Validate ID format
  |> bind(&fetch_from_database/1)     # Database lookup
  |> bind(&check_permissions/1)       # Authorization check
  |> bind(&format_profile/1)          # Format response
  |> fold_l(
    fn profile -> {:ok, profile} end,
    fn error -> {:error, error} end
  )
end
```

### Form Validation with Comprehensive Error Collection

```elixir
# Create individual field validators that work on the whole form
validate_name_field = fn form_data ->
  if String.length(form_data.name) > 0 do
    Either.right(form_data.name)
  else
    Either.left(["Name is required"])
  end
end

validate_email_field = fn form_data ->
  if String.contains?(form_data.email, "@") and String.length(form_data.email) > 5 do
    Either.right(form_data.email)
  else
    Either.left(["Email must be valid"])
  end
end

validate_password_field = fn form_data ->
  if String.length(form_data.password) >= 8 do
    Either.right(form_data.password)
  else
    Either.left(["Password must be at least 8 characters"])
  end
end

# Validate the entire form - collects ALL validation errors
def validate_registration_form(form_data) do
  validators = [
    validate_name_field,
    validate_email_field,
    validate_password_field
  ]
  
  Either.validate(form_data, validators)
  |> fold_l(
    fn validated_form ->
      {:ok, %{
        name: validated_form.name,
        email: validated_form.email,
        password: validated_form.password
      }}
    end,
    fn all_errors -> 
      {:error, "Registration failed: #{Enum.join(List.flatten(all_errors), ", ")}"}
    end
  )
end

# Example usage
form_data = %{name: "", email: "invalid", password: "123"}

validate_registration_form(form_data)
# {:error, "Registration failed: Name is required, Email must be valid, Password must be at least 8 characters"}

valid_form = %{name: "Alice", email: "alice@example.com", password: "securepass123"}
validate_registration_form(valid_form)
# {:ok, %{name: "Alice", email: "alice@example.com", password: "securepass123"}}
```

### Configuration Loading

```elixir
def load_config(config_path) do
  Either.right(config_path)
  |> bind(&read_config_file/1)         # File -> Either Error String
  |> bind(&parse_json/1)               # String -> Either Error Map
  |> bind(&validate_schema/1)          # Map -> Either Error ValidConfig
  |> bind(&apply_defaults/1)           # ValidConfig -> Either Error FinalConfig
end

defp read_config_file(path) do
  File.read(path)
  |> Either.from_result()
  |> Either.map_left(fn reason -> "Failed to read #{path}: #{reason}" end)
end

defp parse_json(content) do
  Jason.decode(content)
  |> Either.from_result()
  |> Either.map_left(fn %Jason.DecodeError{data: data} -> "Invalid JSON: #{data}" end)
end
```

## Integration with Other Modules

### With Funx.Utils

```elixir
# Curry validation functions
validate_range = Utils.curry(fn min, max, value ->
  cond do
    value < min -> Either.left("Value #{value} below minimum #{min}")
    value > max -> Either.left("Value #{value} above maximum #{max}")  
    true -> Either.right(value)
  end
end)

validate_age = validate_range.(0, 150)
validate_percentage = validate_range.(0, 100)

Either.right(25) |> bind(validate_age)        # right(25)
Either.right(-5) |> bind(validate_age)        # left("Value -5 below minimum 0")
```

### Conversion from Maybe

```elixir
# Convert Maybe to Either with error context
def maybe_to_either(maybe_value, error_message) do
  Maybe.fold_l(maybe_value, 
    fn value -> Either.right(value) end,
    fn -> Either.left(error_message) end
  )
end

# Usage in pipeline
def find_and_validate_user(user_id) do
  user_id
  |> find_user()                    # Returns Maybe User
  |> maybe_to_either("User not found")
  |> bind(&validate_user_active/1)  # Continue with Either validation
end
```

### With Predicate Logic

```elixir
# Convert predicates to Either validators
def predicate_to_either(predicate, error_message) do
  fn value ->
    if predicate.(value) do
      Either.right(value)
    else
      Either.left(error_message)
    end
  end
end

# Use with validation
is_adult = fn user -> user.age >= 18 end
validate_adult = predicate_to_either(is_adult, "Must be 18 or older")

Either.right(%{age: 25})
|> bind(validate_adult)             # right(%{age: 25})

Either.right(%{age: 16})
|> bind(validate_adult)             # left("Must be 18 or older")
```

## Advanced Patterns

### Error Recovery

```elixir
def process_with_fallback(data) do
  data
  |> process_primary_method()
  |> fold_l(
    fn result -> Either.right(result) end,
    fn _error -> data |> process_fallback_method() end
  )
end

# Or using a helper function
def either_or_else(either_result, fallback_fn) do
  fold_l(either_result, &Either.right/1, fn _error -> fallback_fn.() end)
end

data
|> process_primary_method()
|> either_or_else(fn -> process_fallback_method(data) end)
```

### Error Mapping

```elixir
def map_error(either_value, error_mapper) do
  fold_l(either_value, 
    &Either.right/1,
    fn error -> Either.left(error_mapper.(error)) end
  )
end

# Usage: Convert database errors to user-friendly messages
def friendly_database_error(db_error) do
  case db_error do
    {:constraint, _} -> "Data validation failed"
    {:connection, _} -> "Database temporarily unavailable"
    _ -> "An unexpected error occurred"
  end
end

database_operation()
|> map_error(&friendly_database_error/1)
```

## Testing Strategies

### Unit Testing Validation Logic

```elixir
defmodule ValidationTest do
  use ExUnit.Case
  import Funx.Monad

  test "email validation with detailed errors" do
    # Valid email
    assert validate_email("user@example.com") == Either.right("user@example.com")
    
    # Invalid formats
    assert validate_email("") == Either.left("Email cannot be empty")
    assert validate_email("invalid") == Either.left("Email must contain @")
    assert validate_email("user@") == Either.left("Invalid domain")
  end

  test "chaining validations with bind" do
    # Successful chain
    result = Either.right("123")
    |> bind(&parse_integer/1)
    |> bind(&validate_positive/1)
    
    assert result == Either.right(123)
    
    # Chain breaks on first error
    result = Either.right("invalid")
    |> bind(&parse_integer/1)        # Fails here
    |> bind(&validate_positive/1)    # Never runs
    
    assert {:left, _error} = result
  end

  test "collecting validation errors with traverse_a" do
    invalid_data = ["", "not-email", "invalid-age"]
    validators = [&validate_name/1, &validate_email/1, &validate_age/1]
    
    case Either.traverse_a(invalid_data, validators) do
      {:left, errors} ->
        assert length(errors) == 3  # All three validations failed
        assert "Name cannot be empty" in errors
      {:right, _} ->
        flunk("Expected validation errors")
    end
  end
end
```

## Performance Considerations

### Short-Circuiting

```elixir
# bind chains short-circuit on first Left
# This makes error-handling very efficient

expensive_validation = fn data ->
  # This never runs if earlier validation failed
  Process.sleep(1000)
  Either.right(data)
end

Either.left("early error")
|> bind(&some_validation/1)
|> bind(expensive_validation)      # Never executes
|> bind(&another_validation/1)
# Result: left("early error"), computed instantly
```

### Memory Usage

```elixir
# Either uses minimal memory overhead
# right(value) stores value plus small wrapper
# left(error) stores error plus small wrapper

# Efficient for error handling
validation_result = %{
  user: Either.right(%User{id: 1}),    # Small overhead
  error: Either.left("Validation failed")  # Small overhead
}
```

## Troubleshooting Common Issues

### Issue: Nested Either Values

```elixir
# ❌ Problem: Manual nesting creates Either (Either a)
result = Either.right(user_data)
|> map(&validate_user/1)  # validate_user returns Either
# Result: Either (Either User) - nested!

# ✅ Solution: Use bind for functions that return Either
result = Either.right(user_data)
|> bind(&validate_user/1)  # Automatically flattens to Either User
```

### Issue: Mixing Validation Strategies

```elixir
# ❌ Problem: Inconsistent error handling approach
def mixed_validation(data) do
  Either.right(data)
  |> bind(&validate_required_field/1)    # Stops on first error
  |> Either.validate([&validate_format/1])  # But this tries to collect all
end

# ✅ Solution: Pick one strategy consistently
def fail_fast_validation(data) do
  Either.right(data)
  |> bind(&validate_required_field/1)
  |> bind(&validate_format/1)
  |> bind(&validate_business_rules/1)
end

def collect_all_errors_validation(data) do
  fields = [data.field1, data.field2, data.field3]
  validators = [&validate_field1/1, &validate_field2/1, &validate_field3/1]
  Either.traverse_a(fields, validators)
end
```

### Issue: Pattern Matching Confusion

```elixir
# ❌ Problem: Imperative pattern matching instead of functional folding
case either_value do
  %Right{right: value} -> process_success(value)
  %Left{left: error} -> handle_error(error)
end

# ✅ Solution: Use functional folding instead  
either_value
|> fold_l(
  fn value -> process_success(value) end,
  fn error -> handle_error(error) end
)
```

### Issue: Over-using Pattern Matching

```elixir
# ❌ Problem: Manual unwrapping defeats the purpose
case either_value do
  %Right{right: value} ->
    new_value = transform(value)
    Either.right(new_value)
  %Left{left: error} -> Either.left(error)
end

# ✅ Solution: Use map to stay in Either context
either_value |> map(&transform/1)
```

## When Not to Use Either

### Use Maybe Instead When

```elixir
# ❌ Either with generic errors loses its advantage
def find_user(id) do
  case get_user(id) do
    nil -> Either.left("not found")  # Generic error
    user -> Either.right(user)
  end
end

# ✅ Maybe is simpler for basic presence/absence
def find_user(id) do
  case get_user(id) do
    nil -> Maybe.nothing()
    user -> Maybe.just(user)
  end
end
```

### Use Plain Values When

```elixir
# ❌ Either overhead for operations that can't fail
def calculate_tax(amount) do
  Either.right(amount)
  |> map(fn amt -> amt * 0.1 end)
end

# ✅ Plain calculation for guaranteed operations
def calculate_tax(amount) do
  amount * 0.1
end
```

### Use Exceptions When

```elixir
# ❌ Either for truly exceptional conditions
def divide(a, b) do
  if b == 0 do
    Either.left("Division by zero")
  else
    Either.right(a / b)
  end
end

# ✅ Exception for programmer errors
def divide(a, b) when b != 0 do
  a / b
end
# Let it crash on division by zero - it's a programming error
```

## Summary

Either provides error-safe computation with detailed failure context:

**Core Operations:**

- `right/1`: Wrap success values
- `left/1`: Wrap error values with context
- `map/2`: Transform success values, preserve errors
- `bind/2`: Chain Either-returning operations with fail-fast behavior
- `ap/2`: Apply functions across multiple Either values
- `traverse_a/2`: Validate with error accumulation
- `sequence/1`: Convert `[Either e a]` to `Either e [a]` with fail-fast

**Key Patterns:**

- Chain error-prone operations with `bind/2` for fail-fast
- Validate multiple fields with `traverse_a/2` for error collection
- Transform success values with `map/2`
- Pattern match for specific error handling and recovery
- Convert from {:ok, value} | {:error, reason} tuples

**Mathematical Properties:**

- **Functor**: `map` preserves structure (Right-biased)
- **Applicative**: `ap` applies functions in context (fails if any Left)
- **Monad**: `bind` enables dependent sequencing with error propagation

Remember: Either represents "success or detailed failure" - use it when error context matters for debugging, user feedback, or recovery strategies.
