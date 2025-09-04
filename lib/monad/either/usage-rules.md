# `Funx.Monad.Either` Usage Rules

## LLM Functional Programming Foundation

**Key Concepts for LLMs:**

**CRITICAL Elixir Implementation**: All monadic operations are under `Funx.Monad` protocol

- **NO separate Functor/Applicative protocols** - Elixir protocols cannot be extended after definition
- Always use `Monad.map/2`, `Monad.bind/2`, `Monad.ap/2` or import `Funx.Monad`
- Different from Haskell's separate Functor, Applicative, Monad typeclasses

**Either**: Represents success/failure with detailed error context

- `left(error)` represents failure with error information
- `right(value)` represents success with the actual value
- **Right-biased**: Operations work on the Right (success) path

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

**Important**: Validation functions must return error lists for accumulation:

- ✅ `Either.left(["Error message"])` - List format for accumulation
- ❌ `Either.left("Error message")` - String format causes type errors

```elixir
# Create individual validators for each field
validate_name = fn name ->
  if String.length(name) > 0 do
    Either.right(name)
  else
    Either.left(["Name cannot be empty"])
  end
end

validate_email = fn email ->
  if String.contains?(email, "@") do
    Either.right(email) 
  else
    Either.left(["Invalid email format"])
  end
end

validate_age = fn age ->
  if is_integer(age) and age >= 0 do
    Either.right(age)
  else
    Either.left(["Age must be a positive integer"])
  end
end

# Validate a user record - collects ALL errors
user_data = %{name: "", email: "invalid-email", age: -5}

# Apply all validators to the user data
Either.validate(user_data, [
  fn user -> validate_name(user.name) end,
  fn user -> validate_email(user.email) end, 
  fn user -> validate_age(user.age) end
])
# left(["Name cannot be empty", "Invalid email format", "Age must be a positive integer"])

# Valid data returns the original value
valid_user = %{name: "Alice", email: "alice@example.com", age: 30}
Either.validate(valid_user, [
  fn user -> validate_name(user.name) end,
  fn user -> validate_email(user.email) end,
  fn user -> validate_age(user.age) end
])
# right(%{name: "Alice", email: "alice@example.com", age: 30})
```

**Use `validate` when:**

- You need comprehensive validation with ALL error details
- You're validating forms or user input
- You want to show users all validation problems at once
- You need to apply multiple validation rules to a single value


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
