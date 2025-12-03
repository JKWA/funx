# `Funx.Monad.Maybe` Usage Rules

## LLM Functional Programming Foundation

**Key Concepts for LLMs:**

**CRITICAL Elixir Implementation**: All monadic operations are under `Funx.Monad` protocol

- **NO separate Functor/Applicative protocols** - Elixir protocols cannot be extended after definition
- Always use `Monad.map/2`, `Monad.bind/2`, `Monad.ap/2` or import `Funx.Monad`
- Different from Haskell's separate Functor, Applicative, Monad typeclasses

**Kleisli Function**: A function `a -> Maybe b` (takes unwrapped value, returns wrapped value)

- **Primary use**: `traverse/2` and `concat_map/2` for list operations
- **Individual use**: `Monad.bind/2` for single Maybe values
- Example: `find_user :: UserId -> Maybe User`

**Key List Operation Patterns:**

- `concat([Maybe a])` → `[a]` (extract all Just values, ignore Nothing)
- `concat_map([a], kleisli_fn)` → `[b]` (apply Kleisli, collect Just results)
- `traverse([a], kleisli_fn)` → `Maybe [b]` (apply Kleisli, all succeed or Nothing)
- `sequence([Maybe a])` → `Maybe [a]` (like traverse with identity function)

**Functor**: Something you can `map` over while preserving structure

- `Monad.map/2 :: (a -> b) -> Maybe a -> Maybe b`
- Transforms the present value, leaves Nothing unchanged

**Applicative**: Allows applying functions inside a context

- `Monad.ap/2 :: Maybe (a -> b) -> Maybe a -> Maybe b`  
- Can combine multiple Maybe values

**Monad**: Supports `bind` for chaining dependent computations

- `Monad.bind/2 :: Maybe a -> (a -> Maybe b) -> Maybe b`
- Flattens nested Maybe values automatically

**Sequence (Category Theory)**: Swap the order of two type constructors

- `[Maybe a]` → `Maybe [a]` (list of Maybe becomes Maybe of list)
- Not about sequential processing - about type transformation

**Maybe**: Represents immediate presence/absence of values

- **Presence**: Value exists and is usable (`just(value)`)
- **Absence**: Value is missing, incomplete, or unavailable (`nothing()`)
- **Immediate/Synchronous**: Values exist right now, no deferred execution
- **No concurrency**: All operations are synchronous - use Effect for async operations

## LLM Decision Guide: When to Use Maybe

**✅ Use Maybe when:**

- Simple presence/absence (user profile, config value)
- No error context needed ("not found" is sufficient)
- Chaining operations that should skip on absence
- Optional fields or nullable database columns
- User says: "optional", "might not exist", "could be missing"

**❌ Use Effect when:**

- Async operations (database calls, HTTP requests, file I/O)
- Need concurrency or deferred execution
- Operations that take significant time
- User says: "async", "concurrent", "fetch", "call API"

**❌ Use Either when:**

- Need specific error context ("user not found", "validation failed")
- Multiple error types or recovery strategies
- Business validation with detailed failure messages
- User says: "validate", "check requirements", "ensure valid"

**⚡ Maybe Strategy Decision:**

- **Simple presence check**: Use `just/1` and `nothing/0` constructors
- **Chain operations**: Use `bind/2` for individual Maybe sequencing
- **Transform present values**: Use `map/2` with regular functions
- **Combine multiple Maybe values**: Use `ap/2` for applicative pattern
- **Apply Kleisli to lists**: Use `traverse/2` (all must succeed) or `concat_map/2` (collect successes)
- **Convert lists**: Use `sequence/1` to flip `[Maybe a]` to `Maybe [a]`
- **Pattern match results**: Use `case` with `%Just{value: value}` and `%Nothing{}`

**⚙️ Function Choice Guide (Mathematical Purpose):**

- **Chain dependent lookups**: `bind/2` with functions returning Maybe
- **Transform present values**: `map/2` with functions returning plain values  
- **Apply functions to multiple Maybe values**: `ap/2` for combining contexts
- **Handle missing values**: Pattern match or use `from_nil/1`, `to_nil/1`
- **Work with lists**: `sequence/1`, `traverse/2`, `traverse_a/2`

## LLM Context Clues

**User language → Maybe patterns:**

- "optional user profile" → `find_user/1` returning Maybe User
- "might not have email" → Maybe String for optional email field
- "chain lookups" → `bind/2` with multiple Maybe-returning functions
- "transform if present" → `map/2` to modify just the value
- "combine optional values" → `ap/2` to apply function across Maybe values
- "list of optional items" → `sequence/1` to collect all present values

## Quick Reference

- Use `just(value)` for present values, `nothing()` for absence
- Chain operations with `bind/2` - they skip automatically on `nothing`
- Transform values with `map/2` - leaves `nothing` unchanged
- Combine multiple Maybe values with `ap/2`
- Use `bind/2` with identity to flatten nested Maybes: `bind(nested_maybe, fn x -> x end)`
- Convert `[Maybe a]` to `Maybe [a]` with `sequence/1`
- **Prefer `fold_l/3` over pattern matching** for functional case analysis
- **Note**: Maybe values are structs `%Just{value: ...}` or `%Nothing{}`, not tagged tuples
- Import `Funx.Monad` for `map`, `bind`, `ap` and `Funx.Foldable` for `fold_l`

## Overview

`Funx.Monad.Maybe` handles presence and absence without explicit null checks.

Use Maybe for:

- Optional fields and nullable database columns
- Operations that might not return a value
- Chaining computations that should skip on missing data
- Simple presence/absence (no detailed error context needed)

**Key insight**: Maybe represents "optional" - either there's a value (`just`) or there isn't (`nothing`). All operations respect this, automatically skipping work when there's nothing to work with.

## Constructors

### `just/1` - Wrap a Present Value

Creates a Maybe containing a value:

```elixir
Maybe.just(42)        # Present: contains 42
Maybe.just("hello")   # Present: contains "hello"
Maybe.just([1, 2, 3]) # Present: contains [1, 2, 3]
```

### `nothing/0` - Represent Absence

Creates a Maybe representing absence:

```elixir
Maybe.nothing()       # Absent: contains no value
```

### `pure/1` - Alias for `just/1`

Alternative constructor for present values:

```elixir
Maybe.pure(42)    # Same as Maybe.just(42)
```

## Core Operations

### `map/2` - Transform Present Values

Applies a function to the value inside a `just`, leaves `nothing` unchanged:

```elixir
import Funx.Monad
import Funx.Foldable

Maybe.just(5)
|> map(fn x -> x * 2 end)    # just(10)

Maybe.nothing()
|> map(fn x -> x * 2 end)    # nothing() - function never runs
```

**Use `map` when:**

- You want to transform the value if it exists
- The transformation function returns a plain value (not wrapped in Maybe)
- You want to preserve the Maybe structure

### `bind/2` - Chain Dependent Operations

Chains operations that return Maybe values, automatically flattening nested Maybe:

```elixir
import Funx.Monad
import Funx.Foldable

# These functions return Maybe values
find_user = fn id -> if id > 0, do: Maybe.just(%{id: id}), else: Maybe.nothing() end
get_email = fn user -> if user.id == 1, do: Maybe.just("user@example.com"), else: Maybe.nothing() end

Maybe.just(1)
|> bind(find_user)    # just(%{id: 1})
|> bind(get_email)    # just("user@example.com")

Maybe.just(-1)
|> bind(find_user)    # nothing() - chain stops here
|> bind(get_email)    # nothing() - this never runs
```

**Use `bind` when:**

- You're chaining operations that each return Maybe
- Each step depends on the result of the previous step
- You want automatic short-circuiting on `nothing`

**Common bind pattern:**

```elixir
def process_user_id(user_id) do
  Maybe.just(user_id)
  |> bind(&find_user/1)         # UserId -> Maybe User
  |> bind(&get_user_profile/1)  # User -> Maybe Profile  
  |> bind(&format_name/1)       # Profile -> Maybe String
end
```

### `ap/2` - Apply Functions Across Maybe Values

Applies a function in a Maybe to a value in a Maybe:

```elixir
import Funx.Monad
import Funx.Foldable

# Apply a wrapped function to wrapped values
Maybe.just(fn x -> x + 10 end)
|> ap(Maybe.just(5))          # just(15)

# Combine multiple Maybe values
add = fn x -> fn y -> x + y end end

Maybe.just(add)
|> ap(Maybe.just(3))          # just(fn y -> 3 + y end)
|> ap(Maybe.just(4))          # just(7)

# If any value is nothing, result is nothing
Maybe.just(add)
|> ap(Maybe.nothing())        # nothing()
|> ap(Maybe.just(4))          # nothing()
```

**Use `ap` when:**

- You want to apply a function to multiple Maybe values
- You need all values to be present for the operation to succeed
- You're implementing applicative patterns

### `tap/2` - Side Effects Without Changing Values

Executes a side-effect function on a Just value and returns the original Maybe unchanged. If the Maybe is Nothing, the function is not called:

```elixir
import Funx.Monad.Maybe

# Side effect on Just
Maybe.just(42)
|> Maybe.tap(&IO.inspect(&1, label: "debug"))  # prints "debug: 42"
# Returns: just(42)

# No side effect on Nothing
Maybe.nothing()
|> Maybe.tap(&IO.inspect(&1, label: "debug"))  # nothing printed
# Returns: nothing()
```

**Use `tap` when:**

- Debugging pipelines - inspect intermediate values without breaking the chain
- Logging - record values when present
- Metrics/telemetry - emit events for present values
- Side effects - perform actions (like notifications) only when value exists

**Common tap patterns:**

```elixir
# Debug a chain
find_user(user_id)
|> Maybe.tap(&IO.inspect(&1, label: "found user"))
|> bind(&get_profile/1)
|> Maybe.tap(&IO.inspect(&1, label: "got profile"))

# Conditional logging
fetch_optional_config("feature_flag")
|> Maybe.tap(fn flag -> Logger.info("Feature flag: #{flag}") end)
|> Maybe.map(&enable_feature/1)

# Analytics on optional values
user_search_query
|> Maybe.from_nil()
|> Maybe.tap(fn query ->
  :telemetry.execute([:app, :search], %{query: query})
end)
```

**Important notes:**

- The function's return value is discarded
- Only executes on Just values (when value is present)
- Does not affect the Maybe value
- Nothing values pass through untouched

## Folding Maybe Values

**Core Concept**: Both `Just` and `Nothing` implement the `Funx.Foldable` protocol, providing `fold_l/3` for catamorphism (breaking down data structures).

### `fold_l/3` - Functional Case Analysis

The fundamental operation for handling Maybe values without pattern matching:

```elixir
import Funx.Foldable

# fold_l(maybe_value, just_function, nothing_function)
result = fold_l(maybe_value, 
  fn value -> "Found: #{value}" end,  # Just case
  fn -> "Not found" end               # Nothing case
)

# Examples
fold_l(Maybe.just(42), 
  fn value -> value * 2 end,    # Runs this: 84
  fn -> 0 end                   # Never runs
)

fold_l(Maybe.nothing(), 
  fn value -> value * 2 end,    # Never runs
  fn -> "No value" end          # Runs this: "No value"
)
```

**Use `fold_l` when:**

- You need to convert Maybe to a different type
- You want functional case analysis without pattern matching
- You're implementing higher-level combinators
- You need to handle both present and absent cases

### Folding vs Pattern Matching

```elixir
# ❌ Imperative pattern matching
case maybe_value do
  %Just{value: value} -> "Found: #{value}"
  %Nothing{} -> "Not found"
end

# ✅ Functional folding
fold_l(maybe_value,
  fn value -> "Found: #{value}" end,
  fn -> "Not found" end
)
```

### Advanced Folding Patterns

```elixir
# Extract value with default
get_or_default = fn maybe, default ->
  fold_l(maybe,
    fn value -> value end,
    fn -> default end
  )
end

# Convert Maybe to result tuple
to_result = fn maybe ->
  fold_l(maybe,
    fn value -> {:ok, value} end,
    fn -> {:error, :not_found} end
  )
end

# Conditional processing
process_if_present = fn maybe ->
  fold_l(maybe,
    fn value -> expensive_operation(value) end,
    fn -> :skipped end
  )
end
```

### Flattening Nested Maybe Values with `bind`

Since there's no `join/1` function, use `bind/2` with the identity function to flatten nested Maybe values:

```elixir
import Funx.Monad

# Flatten nested Maybe using bind
nested = Maybe.just(Maybe.just(42))
bind(nested, fn inner -> inner end)    # just(42)

# Nothing in outer - stays nothing
outer_nothing = Maybe.nothing()
bind(outer_nothing, fn inner -> inner end)    # nothing()

# Nothing in inner - becomes nothing  
inner_nothing = Maybe.just(Maybe.nothing())
bind(inner_nothing, fn inner -> inner end)    # nothing()
```

**Use this pattern when:**

- You have nested Maybe values that need flattening
- You're implementing monadic operations manually
- You're working with higher-order Maybe computations

## Functional Error Handling

**Important**: Maybe values are structs `%Just{value: ...}` or `%Nothing{}`, not tagged tuples. Pattern matching must respect this shape.

Maybe values are best handled with functional folding:

```elixir
fold_l(maybe_value,
  fn value -> "Found: #{value}" end,
  fn -> "Not found" end
)
```

**Common patterns:**

```elixir
# Extract with default
value = fold_l(maybe_user,
  fn user -> user.name end,
  fn -> "Guest" end
)

# Process only if present
fold_l(maybe_config,
  fn config -> apply_config(config) end,
  fn -> :ok end
)
```

## Refinement

### `just?/1` and `nothing?/1` - Type Checks

```elixir
Maybe.just?(Maybe.just(42))      # true
Maybe.just?(Maybe.nothing())     # false

Maybe.nothing?(Maybe.nothing())  # true
Maybe.nothing?(Maybe.just(42))   # false
```

## Fallback and Extraction

### `get_or_else/2` - Extract Value with Default

```elixir
Maybe.just(42) |> Maybe.get_or_else(0)        # 42
Maybe.nothing() |> Maybe.get_or_else(0)       # 0
```

### `or_else/2` - Fallback on Nothing

```elixir
Maybe.just(42) |> Maybe.or_else(fn -> Maybe.just(0) end)     # just(42)
Maybe.nothing() |> Maybe.or_else(fn -> Maybe.just(0) end)    # just(0)
```

### Combining Two Maybe Values with `ap/2`

Use the applicative pattern with `ap/2` to combine two Maybe values with a binary function:

```elixir
import Funx.Monad

# Combine two Maybe values using ap
add_fn = Maybe.just(&+/2)
ap(add_fn, Maybe.just(3)) |> ap(Maybe.just(4))     # just(7)
ap(add_fn, Maybe.just(3)) |> ap(Maybe.nothing())   # nothing()
ap(add_fn, Maybe.nothing()) |> ap(Maybe.just(4))   # nothing()

# More concise with helper function
combine_maybe = fn ma, mb, f ->
  Maybe.just(f) |> ap(ma) |> ap(mb)
end

combine_maybe.(Maybe.just(3), Maybe.just(4), &+/2)         # just(7)
combine_maybe.(Maybe.just(3), Maybe.nothing(), &+/2)       # nothing()

# String concatenation
combine_maybe.(Maybe.just("Hello, "), Maybe.just("World!"), &<>/2)  # just("Hello, World!")

# Working with structs
combine_maybe.(
  Maybe.just(%{name: "Alice"}),
  Maybe.just(%{age: 30}),
  fn user, age_info -> Map.merge(user, age_info) end
)  # just(%{name: "Alice", age: 30})
```

**Use this pattern when:**

- You need to combine exactly two Maybe values with a binary function
- You want applicative-style combination that fails fast on first Nothing
- You're implementing patterns similar to liftA2 from other functional languages

## Common Patterns

### Safe Navigation

Instead of nested null checks:

```elixir
# Imperative style with null checks
def get_user_city(user_id) do
  fold_l(find_user(user_id),
    fn user ->
      fold_l(get_address(user),
        fn address -> address.city end,
        fn -> nil end
      )
    end,
    fn -> nil end
  )
end

# Functional style with Maybe
def get_user_city(user_id) do
  Maybe.just(user_id)
  |> bind(&find_user_maybe/1)     # Returns Maybe User
  |> bind(&get_address_maybe/1)   # Returns Maybe Address  
  |> map(& &1.city)               # Extract city if present
end
```

### Optional Field Processing

```elixir
# Process optional email field
def send_welcome_email(user) do
  user.email
  |> Maybe.from_nil()
  |> map(&normalize_email/1)
  |> bind(&validate_email/1)      # Returns Maybe valid_email
  |> map(&send_email/1)           # Send if valid
  |> Either.lift_maybe("No valid email")
end
```

### Collecting Optional Values

```elixir
# Gather optional settings
def load_user_preferences(user_id) do
  preferences = [
    get_theme_preference(user_id),      # Maybe String
    get_language_preference(user_id),   # Maybe String  
    get_timezone_preference(user_id)    # Maybe String
  ]
  
  Maybe.sequence(preferences)
  |> map(fn [theme, lang, tz] -> 
    %{theme: theme, language: lang, timezone: tz}
  end)
end
```

## Integration with Other Modules

### With Funx.Utils

```elixir
# Curry functions for Maybe operations
find_by_id = Utils.curry(&find_user/1)
user_finder = find_by_id.(42)

Maybe.just(database)
|> bind(user_finder)

# Compose Maybe-returning functions
compose_maybe = Utils.compose([
  &Maybe.from_nil/1,
  &get_user_profile/1,  # Returns Maybe
  &format_display_name/1
])
```

### With Predicate Logic

```elixir
# Convert predicates to Maybe values
def predicate_to_maybe(predicate, value) do
  if predicate.(value) do
    Maybe.just(value)
  else
    Maybe.nothing()
  end
end

# Use with validation
is_adult = fn user -> user.age >= 18 end

Maybe.just(user)
|> bind(fn u -> predicate_to_maybe(is_adult, u) end)
|> map(&process_adult_user/1)
```

## Conversions Between Types

### Conversion to Either

```elixir
# Convert Maybe to Either with error context using the built-in function
Either.lift_maybe(maybe_value, "Error message")

# Usage in validation pipeline
Maybe.just(user_input)
|> bind(&parse_user_id/1)
|> maybe_to_either("Invalid user ID")
|> Either.bind(&detailed_validation/1)
```

## List Operations

### `concat/1` - Extract All Just Values

Removes all Nothing values and unwraps Just values from a list:

```elixir
Maybe.concat([
  Maybe.just(1),
  Maybe.nothing(),
  Maybe.just(3),
  Maybe.nothing()
])                              # [1, 3]
```

### `concat_map/2` - Apply Function and Collect Just Results

### `traverse/2` - Apply Kleisli to List (All Must Succeed)

Applies a Kleisli function to each element, requiring all operations to succeed:

```elixir
import Funx.Monad
import Funx.Foldable

# Kleisli function: String -> Maybe Integer
parse_number = fn str ->
  case Integer.parse(str) do
    {num, ""} -> Maybe.just(num)
    _ -> Maybe.nothing()
  end
end

# All succeed - get Maybe list
Maybe.traverse(["1", "2", "3"], parse_number)  # just([1, 2, 3])

# Any fail - get Nothing
Maybe.traverse(["1", "invalid", "3"], parse_number)  # nothing()
```

**Use `traverse` when:**

- All operations must succeed for meaningful result
- You need fail-fast behavior on lists
- Converting `[a]` to `Maybe [b]` with validation

### `concat_map/2` - Apply Kleisli to List (Collect Successes)

Applies a Kleisli function to each element, collecting only successful results:

```elixir
# Same Kleisli function as above
parse_number = fn str ->
  case Integer.parse(str) do
    {num, ""} -> Maybe.just(num)
    _ -> Maybe.nothing()
  end
end

# Collect only successes - get plain list
Maybe.concat_map(["1", "invalid", "3", "bad"], parse_number)  # [1, 3]

# All succeed - get all results
Maybe.concat_map(["1", "2", "3"], parse_number)  # [1, 2, 3]

# All fail - get empty list
Maybe.concat_map(["bad", "invalid", "error"], parse_number)  # []
```

**Use `concat_map` when:**

- Partial success is acceptable
- You want to collect all valid results
- You need resilient processing that continues on failure

### `sequence/1` - Convert List of Maybe to Maybe List

Converts `[Maybe a]` to `Maybe [a]` - equivalent to `traverse` with identity function:

```elixir
# All present - success
Maybe.sequence([
  Maybe.just(1),
  Maybe.just(2), 
  Maybe.just(3)
])                            # just([1, 2, 3])

# Any absent - failure  
Maybe.sequence([
  Maybe.just(1),
  Maybe.nothing(),
  Maybe.just(3)  
])                            # nothing()

# Relationship to traverse  
Maybe.sequence(maybe_list) == Maybe.traverse(maybe_list, fn x -> x end)
```

**Use `sequence` when:**

- You have a list of Maybe values from previous computations
- You want all values to be present, or nothing at all
- You're collecting results from multiple optional operations

### List Operations Comparison

```elixir
user_ids = [1, 2, 999, 4]  # 999 is invalid ID

# traverse: All must succeed or nothing
Maybe.traverse(user_ids, &find_user/1)
# nothing() - because user 999 doesn't exist

# concat_map: Collect successes, ignore failures  
Maybe.concat_map(user_ids, &find_user/1)
# [user1, user2, user4] - got the valid users

# sequence: All existing values must be present
existing_maybes = [Maybe.just(user1), Maybe.nothing(), Maybe.just(user3)]
Maybe.sequence(existing_maybes)  # nothing() - because one is Nothing
```

## Lifting

### `lift_predicate/2` - Convert Value Based on Predicate

Converts a value to Just if it meets a predicate, otherwise Nothing:

```elixir
validate_positive = Maybe.lift_predicate(&(&1 > 0))

validate_positive.(5)   # just(5)
validate_positive.(-1)  # nothing()
```

### `lift_either/1` - Convert Either to Maybe

Converts an Either to Maybe, discarding Left error information:

```elixir
Maybe.lift_either(Either.right(42))    # just(42)
Maybe.lift_either(Either.left("error")) # nothing()
```

### `lift_identity/1` - Convert Identity to Maybe

Converts an Identity monad to Maybe:

```elixir
Maybe.lift_identity(Identity.pure(42))  # just(42)
```

### `lift_eq/1` and `lift_ord/1` - Lift Comparison Functions

Lifts comparison functions for use in Maybe context:

```elixir
# Lift equality for Maybe values
Maybe.lift_eq(&==/2)

# Lift ordering for Maybe values  
Maybe.lift_ord(&compare/2)
```

## Elixir Interoperability

### `from_nil/1` - Convert Nil to Maybe

```elixir
Maybe.from_nil(42)      # just(42)
Maybe.from_nil(nil)     # nothing()
```

### `to_nil/1` - Convert Maybe to Nil

```elixir
Maybe.to_nil(Maybe.just(42))    # 42
Maybe.to_nil(Maybe.nothing())   # nil
```

### `from_result/1` - Convert Result Tuple to Maybe

```elixir
Maybe.from_result({:ok, 42})        # just(42)
Maybe.from_result({:error, "fail"}) # nothing()
```

### `to_result/1` - Convert Maybe to Result Tuple

```elixir
Maybe.to_result(Maybe.just(42))    # {:ok, 42}
Maybe.to_result(Maybe.nothing())   # {:error, nil}
```

### `from_try/1` - Safe Function Execution

```elixir
# Run function safely, returning Nothing on exception
Maybe.from_try(fn -> 42 / 0 end)  # nothing()
Maybe.from_try(fn -> 42 / 2 end)  # just(21.0)
```

### `to_try!/2` - Unwrap or Raise with Custom Error

```elixir
Maybe.to_try!(Maybe.just(42), "No value")     # 42
Maybe.to_try!(Maybe.nothing(), "No value")   # raises RuntimeError: "No value"
```

## Testing Strategies

### Property-Based Testing

```elixir
defmodule MaybePropertyTest do
  use ExUnit.Case
  use StreamData

  property "map preserves just structure" do
    check all value <- term(),
              f <- StreamData.constant(fn x -> x + 1 end) do
      result = Maybe.just(value) |> Monad.map(f)
      assert Maybe.just?(result)
    end
  end

  property "map on nothing returns nothing" do
    check all f <- StreamData.constant(fn x -> x + 1 end) do
      result = Maybe.nothing() |> Monad.map(f)
      assert result == Maybe.nothing()
    end
  end

  property "bind with just applies function" do
    check all value <- integer(),
              result_value <- integer() do
      f = fn _x -> Maybe.just(result_value) end
      result = Maybe.just(value) |> Monad.bind(f)
      assert result == Maybe.just(result_value)
    end
  end
end
```

### Unit Testing Common Patterns

```elixir
defmodule MaybeTest do
  use ExUnit.Case
  import Funx.Monad

  test "chaining operations with bind" do
    # Successful chain
    result = Maybe.just(5)
    |> bind(fn x -> Maybe.just(x * 2) end)
    |> bind(fn x -> Maybe.just(x + 1) end)
    
    assert result == Maybe.just(11)
    
    # Chain breaks on nothing
    result = Maybe.just(5)
    |> bind(fn _x -> Maybe.nothing() end)
    |> bind(fn x -> Maybe.just(x + 1) end)  # Never executed
    
    assert result == Maybe.nothing()
  end

  test "combining values with ap" do
    add = fn x -> fn y -> x + y end end
    
    result = Maybe.just(add)
    |> ap(Maybe.just(10))
    |> ap(Maybe.just(5))
    
    assert result == Maybe.just(15)
    
    # Fails if any value is nothing
    result = Maybe.just(add)
    |> ap(Maybe.nothing())
    |> ap(Maybe.just(5))
    
    assert result == Maybe.nothing()
  end

  test "sequence converts list of Maybe to Maybe list" do
    # All present
    result = Maybe.sequence([
      Maybe.just(1),
      Maybe.just(2),
      Maybe.just(3)
    ])
    assert result == Maybe.just([1, 2, 3])
    
    # Any absent
    result = Maybe.sequence([
      Maybe.just(1),
      Maybe.nothing(),
      Maybe.just(3)
    ])
    assert result == Maybe.nothing()
  end
end
```

## Performance Considerations

### Lazy Evaluation

```elixir
# Operations on nothing are essentially no-ops
# This makes Maybe chains very efficient when they short-circuit early

expensive_computation = fn x ->
  # This never runs if we start with nothing
  Process.sleep(1000)
  x * 2
end

Maybe.nothing()
|> map(expensive_computation)    # Returns immediately
|> bind(fn x -> Maybe.just(x + 1) end)
# Result: nothing(), computed instantly
```

### Memory Usage

```elixir
# Maybe uses minimal memory overhead
# just(value) stores the value plus a small wrapper
# nothing() is a singleton, shared across all nothing instances

# Efficient for optional fields
user = %{
  id: 1,
  name: "Alice",
  email: Maybe.just("alice@example.com"),  # Small overhead
  phone: Maybe.nothing()                   # Shared singleton
}
```

## Troubleshooting Common Issues

### Issue: Nested Maybe Values

```elixir
# ❌ Problem: Manual nesting creates Maybe Maybe a
result = Maybe.just(user_id)
|> map(&find_user/1)  # find_user returns Maybe User
# Result: Maybe (Maybe User) - nested!

# ✅ Solution: Use bind for functions that return Maybe
result = Maybe.just(user_id) 
|> bind(&find_user/1)  # Automatically flattens to Maybe User
```

### Issue: Mixing Maybe with Nil

```elixir
# ❌ Problem: Inconsistent nil/Maybe usage
def process_data(data) do
  fold_l(get_user(data),
    fn user -> Maybe.just(user) end,
    fn -> Maybe.nothing() end
  )
  |> map(&transform_user/1)
end

# ✅ Solution: Convert early, stay in Maybe context
def process_data(data) do
  get_user(data)
  |> Maybe.from_nil()      # Convert nil -> Maybe early
  |> map(&transform_user/1)
end
```

### Issue: Pattern Matching Confusion

```elixir
# ❌ Problem: Imperative pattern matching instead of functional folding
case maybe_user do
  %Just{value: user} -> process_user(user)
  %Nothing{} -> handle_missing()
end

# ✅ Solution: Use functional folding
fold_l(maybe_user,
  fn user -> process_user(user) end,
  fn -> handle_missing() end
)
```

### Issue: Over-using Pattern Matching

```elixir
# ❌ Problem: Manual unwrapping defeats the purpose
fold_l(maybe_value,
  fn value -> 
    new_value = transform(value)
    Maybe.just(new_value)
  end,
  fn -> Maybe.nothing() end
)

# ✅ Solution: Use map to stay in Maybe context
maybe_value |> map(&transform/1)
```

## When Not to Use Maybe

### Use Either Instead When

```elixir
# ❌ Maybe loses error context
def validate_email(email) do
  if valid_email_format?(email) do
    Maybe.just(email)
  else
    Maybe.nothing()  # Lost: why did validation fail?
  end
end

# ✅ Either preserves error context  
def validate_email(email) do
  cond do
    String.length(email) == 0 -> Either.left("Email cannot be empty")
    not String.contains?(email, "@") -> Either.left("Email must contain @")
    not valid_domain?(email) -> Either.left("Invalid email domain")
    true -> Either.right(email)
  end
end
```

### Use Plain Values When

```elixir
# ❌ Maybe overhead for always-present values
def calculate_tax(amount) do
  # Tax rate is always known, no need for Maybe
  Maybe.just(amount)
  |> map(fn amt -> amt * 0.1 end)
end

# ✅ Plain calculation for guaranteed values
def calculate_tax(amount) do
  amount * 0.1
end
```

## Summary

Maybe provides null-safe computation for optional values:

**Core Operations:**

- `just/1`: Wrap present values
- `nothing/0`: Represent absence  
- `map/2`: Transform present values, skip absent
- `bind/2`: Chain Maybe-returning operations with automatic flattening
- `ap/2`: Apply functions across multiple Maybe values
- `sequence/1`: Convert `[Maybe a]` to `Maybe [a]`

**Key Patterns:**

- Chain dependent lookups with `bind/2`
- Transform values with `map/2`
- Combine multiple optional values with `ap/2`
- Collect all-or-nothing results with `sequence/1`
- Pattern match for final handling

**Mathematical Properties:**

- **Functor**: `map` preserves structure
- **Applicative**: `ap` applies functions in context
- **Monad**: `bind` enables dependent sequencing with flattening

Remember: Maybe represents "optional" - use it when absence is a valid state that should be handled gracefully, without needing specific error information.
