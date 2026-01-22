# `Funx.Validate` Usage Rules

## LLM Functional Programming Foundation

**Key Concepts for LLMs:**

**Validator**: A function that checks data and returns either success or accumulated errors

- **Type signature**: `(value, opts) -> Either.t(ValidationError.t(), value)`
- **Purpose**: Enable composable, declarative data validation with error accumulation
- **Mathematical foundation**: Applicative functor for parallel error collection
- **Composition**: Validators compose via optics-based field projection

**Optics-First Design**: Validators use optics (Lens, Prism, Traversal) for field projection

- **Prism by default**: `at :key` lowers to `Prism.key(:key)` - fields are optional
- **Required for presence**: Only `Required` validator runs on `Nothing`
- **Lens for structure**: Use `Lens.key(:key)` when key must exist (raises `KeyError`)
- **Traversal for relationships**: Validate across multiple related fields

**Applicative Error Accumulation**: All validators run, all errors collected

- **No short-circuiting**: Every validator executes regardless of earlier failures
- **Better UX**: Users see all validation errors at once
- **Sequential mode**: Default, uses Either for monadic composition
- **Parallel mode**: Explicit applicative execution via `mode: :parallel`

**Identity Preservation**: Validation returns original structure unchanged on success

- **No transformation**: Validators check data, they don't transform it
- **Structure preservation**: Extra fields are preserved
- **Empty validation**: `validate do end` always returns `Right(value)`

## LLM Decision Guide: When to Use Validate

**✅ Use Validate when:**

- Need declarative validation rules for data structures
- Want all errors at once (not just first failure)
- Building reusable, composable validation logic
- Validating nested structures with complex field access
- Need context-dependent validation (environment passing)
- User says: "validate", "check fields", "validation errors", "form validation"

**❌ Don't use Validate when:**

- Simple boolean checks (use Predicate instead)
- Single validation that returns boolean
- Need to transform data while validating (use separate steps)
- Performance is absolutely critical (slight overhead from optics)

**⚡ Validate vs. Predicate Decision:**

- **Validate**: Returns `Either.t(ValidationError.t(), value)`, accumulates all errors
- **Predicate**: Returns `boolean`, short-circuits on first false
- **Rule**: Use Validate when you need error messages, Predicate when you need boolean

**⚙️ Mode Choice Guide:**

- **Sequential (default)**: Standard mode, monadic composition
- **Parallel**: Explicit applicative, use when order independence matters

## LLM Context Clues

**User language → Validate patterns:**

- "validate user input" → Basic field validation with `at`
- "show all errors" → Applicative error accumulation (default behavior)
- "required field" → `at :field, Required`
- "optional field" → `at :field, Validator` (Prism by default)
- "nested validation" → List path syntax `at [:a, :b, :c], Validator`
- "validate relationship between fields" → Traversal with `Traversal.combine`
- "context-dependent validation" → Environment passing with `env` option
- "compose validators" → Nested validators in `at` clauses
- "whole-structure validation" → Root validators without `at`

## Quick Reference

- **Core concepts**: Optics-based field projection, applicative error accumulation
- **Main macro**: `validate do ... end` with optional `mode: :parallel`
- **Field projection**: `at :field, Validator` (Prism), `at Lens.key(:field), V` (Lens)
- **Multiple validators**: `at :field, [V1, V2]` or `at :field, [Required, {MinLength, min: 3}]`
- **Nested paths**: `at [:a, :b, :c], Validator` (converts to `Prism.path`)
- **Root validators**: Bare validator module runs on entire structure
- **Environment**: `Either.validate(data, validator, env: %{key: value})`

## Overview

`Funx.Validate` provides a declarative DSL for building composable validators. The DSL uses optics for field projection, accumulates all errors applicatively, and returns the original structure unchanged on success.

The module follows an optics-first design where `at :key` defaults to `Prism.key(:key)`, making fields optional by default. Use `Required` for presence validation or explicit `Lens.key(:key)` for structural requirements.

## DSL Syntax

### Basic Structure

```elixir
use Funx.Validate

validation =
  validate do
    at :name, Required
    at :email, [Required, Email]
    at :age, Positive
  end

Either.validate(%{name: "Alice", email: "alice@example.com", age: 30}, validation)
# => %Right{right: %{name: "Alice", email: "alice@example.com", age: 30}}
```

### Projection Types

```elixir
# Atom (converts to Prism.key - optional field)
at :email, Email

# List path (converts to Prism.path - nested optional)
at [:user, :profile, :name], Required

# Explicit Prism (optional field)
at Prism.key(:age), Positive

# Explicit Lens (required field - raises KeyError if missing)
at Lens.key(:name), Required

# Traversal (multiple foci for relationship validation)
at Traversal.combine([Lens.key(:start_date), Lens.key(:end_date)]), DateRange
```

### Validator Forms

```elixir
# Module alias
at :name, Required

# Tuple with options
at :name, {MinLength, min: 3}

# List of validators
at :email, [Required, Email]

# Combined
at :name, [Required, {MinLength, min: 3}]

# Function (arity-2)
at :price, fn value, _opts -> Either.right(value) end

# Function (arity-3 with env)
at :price, fn value, _opts, env -> Either.right(value) end

# Composable validator (previously defined)
item_val = validate do
  at :name, Required
end

at :item, item_val
```

### Root Validators

```elixir
# Root validator runs on entire structure
validate do
  HasContactMethod  # Behaviour module validating whole structure
  at :name, Required
end
```

### Execution Modes

```elixir
# Sequential mode (default)
validate do
  at :name, Required
end

# Parallel mode (explicit applicative)
validate mode: :parallel do
  at :name, Required
  at :email, Email
end
```

## DSL Examples

### Basic Field Validation

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

# Success
Either.validate(%{name: "Alice", email: "alice@example.com", age: 30}, user_validation)
# => %Right{right: %{name: "Alice", email: "alice@example.com", age: 30}}

# All errors accumulated
Either.validate(%{name: "", email: "bad", age: -5}, user_validation)
# => %Left{left: %ValidationError{errors: ["is required", "must be at least 3 characters", "must be a valid email", "must be positive"]}}
```

### Optional vs Required Fields

```elixir
# Prism (default): Missing field is OK, validator skips Nothing
optional_age =
  validate do
    at :age, Positive  # at :age uses Prism.key(:age)
  end

Either.validate(%{name: "Alice"}, optional_age)
# => %Right{right: %{name: "Alice"}}  # Missing :age is fine

# Required: Must be present
required_age =
  validate do
    at :age, [Required, Positive]
  end

Either.validate(%{name: "Alice"}, required_age)
# => %Left{left: %ValidationError{errors: ["is required"]}}
```

### Nested Path Validation

```elixir
nested_validation =
  validate do
    at [:user, :profile, :name], Required
    at [:user, :profile, :age], Positive
  end

data = %{user: %{profile: %{name: "Alice", age: 30}}}
Either.validate(data, nested_validation)
# => %Right{right: %{user: %{profile: %{name: "Alice", age: 30}}}}
```

### Environment Passing

```elixir
defmodule UniqueEmail do
  @behaviour Funx.Validate.Behaviour
  alias Funx.Monad.Maybe.Nothing

  def validate(value, opts) when is_list(opts), do: validate(value, opts, %{})

  @impl true
  def validate(%Nothing{} = value, _opts, _env), do: Either.right(value)

  def validate(email, _opts, env) do
    existing = Map.get(env, :existing_emails, [])
    if email in existing do
      Either.left(ValidationError.new("email already taken"))
    else
      Either.right(email)
    end
  end
end

validation =
  validate do
    at :email, [Required, Email, UniqueEmail]
  end

env = %{existing_emails: ["taken@example.com"]}
Either.validate(%{email: "new@example.com"}, validation, env: env)
# => %Right{right: %{email: "new@example.com"}}

Either.validate(%{email: "taken@example.com"}, validation, env: env)
# => %Left{left: %ValidationError{errors: ["email already taken"]}}
```

### Traversal for Relationship Validation

```elixir
defmodule DateRange do
  @behaviour Funx.Validate.Behaviour

  def validate(value, opts) when is_list(opts), do: validate(value, opts, %{})

  @impl true
  def validate([start_date, end_date], _opts, _env) do
    if Date.compare(start_date, end_date) == :lt do
      Either.right([start_date, end_date])
    else
      Either.left(ValidationError.new("start_date must be before end_date"))
    end
  end
end

booking_validation =
  validate do
    at Traversal.combine([Lens.key(:start_date), Lens.key(:end_date)]), DateRange
  end

Either.validate(%{start_date: ~D[2024-01-01], end_date: ~D[2024-01-31]}, booking_validation)
# => %Right{right: %{start_date: ~D[2024-01-01], end_date: ~D[2024-01-31]}}
```

### Composable Validators

```elixir
item_validation =
  validate do
    at :name, Required
    at :price, [Required, Positive]
  end

order_validation =
  validate do
    at :item, item_validation
    at :quantity, Positive
  end

Either.validate(%{item: %{name: "Widget", price: 10}, quantity: 5}, order_validation)
# => %Right{right: %{item: %{name: "Widget", price: 10}, quantity: 5}}
```

### Root Validators

```elixir
defmodule HasContactMethod do
  @behaviour Funx.Validate.Behaviour

  def validate(value, opts) when is_list(opts), do: validate(value, opts, %{})

  @impl true
  def validate(%{email: email} = value, _opts, _env) when is_binary(email) and email != "",
    do: Either.right(value)

  def validate(%{phone: phone} = value, _opts, _env) when is_binary(phone) and phone != "",
    do: Either.right(value)

  def validate(_, _opts, _env),
    do: Either.left(ValidationError.new("must have email or phone"))
end

validation =
  validate do
    HasContactMethod
    at :name, Required
  end

Either.validate(%{name: "Alice", email: "alice@example.com"}, validation)
# => %Right{right: %{name: "Alice", email: "alice@example.com"}}
```

## Built-in Validators

| Validator | Purpose | Options |
|-----------|---------|---------|
| `Required` | Presence validation | None |
| `Email` | Email format | None |
| `MinLength` | Minimum string length | `min: integer` |
| `MaxLength` | Maximum string length | `max: integer` |
| `Pattern` | Regex pattern match | `pattern: regex` |
| `Positive` | Number > 0 | None |
| `Negative` | Number < 0 | None |
| `Integer` | Must be integer | None |
| `GreaterThan` | Number > value | `value: number` |
| `LessThan` | Number < value | `value: number` |
| `GreaterThanOrEq` | Number >= value | `value: number` |
| `LessThanOrEq` | Number <= value | `value: number` |
| `In` | Value in set | `values: list` |
| `NotIn` | Value not in set | `values: list` |
| `Range` | Value in range | `min: number, max: number` |
| `Each` | Validate each item | `validator: validator` |
| `Confirmation` | Matches another field | `field: atom` |
| `Not` | Negate validator | `validator: validator` |

## Creating Custom Validators

### Behaviour Module

```elixir
defmodule MyValidator do
  @behaviour Funx.Validate.Behaviour
  alias Funx.Errors.ValidationError
  alias Funx.Monad.Either
  alias Funx.Monad.Maybe.Nothing

  # Handle 2-arity calls
  def validate(value, opts) when is_list(opts), do: validate(value, opts, %{})

  @impl true
  def validate(value, opts, env)

  # Skip Nothing (Prism returned Nothing for missing key)
  def validate(%Nothing{} = value, _opts, _env), do: Either.right(value)

  # Actual validation logic
  def validate(value, opts, _env) do
    if valid?(value, opts) do
      Either.right(value)
    else
      Either.left(ValidationError.new("validation failed"))
    end
  end

  defp valid?(value, opts), do: # ... validation logic
end
```

### Function Validator

```elixir
# Arity-2 function
my_validator = fn value, _opts ->
  if valid?(value) do
    Either.right(value)
  else
    Either.left(ValidationError.new("validation failed"))
  end
end

# Arity-3 function (with environment)
env_validator = fn value, _opts, env ->
  max = Map.get(env, :max_value, 100)
  if value <= max do
    Either.right(value)
  else
    Either.left(ValidationError.new("exceeds maximum"))
  end
end
```

## Correct Usage Patterns

### Field Validation Pipeline

```elixir
use Funx.Validate
alias Funx.Monad.Either
alias Funx.Validator.{Required, Email, MinLength, Positive}

# Define validation
user_validation =
  validate do
    at :name, [Required, {MinLength, min: 2}]
    at :email, [Required, Email]
    at :age, Positive
  end

# Use in processing pipeline
def process_user(params) do
  params
  |> Either.validate(user_validation)
  |> Either.map(&create_user/1)
  |> Either.map_left(&format_errors/1)
end
```

### Nested Structure Validation

```elixir
# Validate deeply nested structures
address_validation =
  validate do
    at :street, Required
    at :city, Required
    at :zip, [Required, {Pattern, pattern: ~r/^\d{5}$/}]
  end

user_validation =
  validate do
    at :name, Required
    at :address, address_validation
  end
```

### Context-Dependent Validation

```elixir
# Pass context via environment
validation =
  validate do
    at :email, UniqueEmail  # Checks against env[:existing_emails]
    at :role, ValidRole     # Checks against env[:allowed_roles]
  end

env = %{
  existing_emails: ["taken@example.com"],
  allowed_roles: [:user, :admin]
}

Either.validate(params, validation, env: env)
```

## Compositional Guidelines

Follow these patterns when generating or working with validators:

- **Use descriptive validators**: Name custom validators clearly
- **Compose from simple parts**: Build complex validation from simple validators
- **Handle Nothing**: Custom validators should handle `Nothing` from Prism
- **Accumulate errors**: Return `ValidationError.new/1` for failures
- **Preserve identity**: Return `Either.right(value)` on success, not transformed value
- **Use appropriate optics**: Prism for optional, Lens for required, Traversal for relationships

## Stability Contract

Ensure that validators maintain:

- **Identity preservation**: Return original value unchanged on success
- **Error accumulation**: All validators run, all errors collected
- **Nothing handling**: Handle `Nothing` from Prism projections
- **Type consistency**: Validators should accept the projected value type
- **Environment propagation**: Pass env to validators that need context

## Anti-Patterns

Avoid generating or emitting:

- **Transforming values**: Validators should check, not transform
- **Short-circuiting manually**: Let the DSL handle error accumulation
- **Ignoring Nothing**: Always handle `Nothing` in custom validators
- **Raising exceptions**: Return `Either.left` instead of raising
- **Side effects in validators**: Keep validation pure
- **Using Lens for optional fields**: Use Prism (default) for optional fields

## Good Patterns

Encourage completions like:

```elixir
# Proper custom validator with Nothing handling
defmodule Positive do
  @behaviour Funx.Validate.Behaviour
  alias Funx.Monad.Maybe.Nothing

  def validate(value, opts) when is_list(opts), do: validate(value, opts, %{})

  @impl true
  def validate(%Nothing{} = value, _opts, _env), do: Either.right(value)

  def validate(value, _opts, _env) when is_number(value) and value > 0,
    do: Either.right(value)

  def validate(_, _opts, _env),
    do: Either.left(ValidationError.new("must be positive"))
end
```

```elixir
# Composable validation structure
base_validation =
  validate do
    at :name, [Required, {MinLength, min: 2}]
  end

extended_validation =
  validate do
    base_validation
    at :email, [Required, Email]
  end
```

```elixir
# Environment-aware validation
validation =
  validate do
    at :username, [Required, UniqueUsername]
  end

# Process with context
def validate_user(params, existing_usernames) do
  Either.validate(params, validation, env: %{existing_usernames: existing_usernames})
end
```

## LLM Code Templates

### Basic Form Validation Template

```elixir
defmodule UserValidation do
  use Funx.Validate
  alias Funx.Monad.Either
  alias Funx.Validator.{Required, Email, MinLength, Positive}

  def user_validation do
    validate do
      at :name, [Required, {MinLength, min: 2}]
      at :email, [Required, Email]
      at :age, Positive
    end
  end

  def validate_user(params) do
    Either.validate(params, user_validation())
  end

  def validate_user_with_context(params, env) do
    Either.validate(params, user_validation(), env: env)
  end
end
```

### Nested Validation Template

```elixir
defmodule OrderValidation do
  use Funx.Validate
  alias Funx.Monad.Either
  alias Funx.Validator.{Required, Positive}

  def item_validation do
    validate do
      at :name, Required
      at :price, [Required, Positive]
      at :quantity, [Required, Positive]
    end
  end

  def order_validation do
    validate do
      at :customer_id, Required
      at :items, {Each, validator: item_validation()}
      at :total, Positive
    end
  end

  def validate_order(order) do
    Either.validate(order, order_validation())
  end
end
```

### Custom Validator Template

```elixir
defmodule CustomValidators do
  @moduledoc "Custom validators for domain-specific validation"

  alias Funx.Errors.ValidationError
  alias Funx.Monad.Either
  alias Funx.Monad.Maybe.Nothing

  defmodule UniqueEmail do
    @behaviour Funx.Validate.Behaviour

    def validate(value, opts) when is_list(opts), do: validate(value, opts, %{})

    @impl true
    def validate(%Nothing{} = value, _opts, _env), do: Either.right(value)

    def validate(email, _opts, env) do
      existing = Map.get(env, :existing_emails, [])

      if email in existing do
        Either.left(ValidationError.new("email already taken"))
      else
        Either.right(email)
      end
    end
  end

  defmodule ValidDateRange do
    @behaviour Funx.Validate.Behaviour

    def validate(value, opts) when is_list(opts), do: validate(value, opts, %{})

    @impl true
    def validate(%Nothing{} = value, _opts, _env), do: Either.right(value)

    def validate([start_date, end_date], _opts, _env) do
      if Date.compare(start_date, end_date) == :lt do
        Either.right([start_date, end_date])
      else
        Either.left(ValidationError.new("start date must be before end date"))
      end
    end
  end
end
```

### API Request Validation Template

```elixir
defmodule APIValidation do
  use Funx.Validate
  alias Funx.Monad.Either
  alias Funx.Monad.Either.{Left, Right}
  alias Funx.Validator.{Required, Email, MinLength, In}

  def create_user_validation do
    validate do
      at :name, [Required, {MinLength, min: 2}]
      at :email, [Required, Email]
      at :role, {In, values: [:user, :admin, :moderator]}
    end
  end

  def validate_request(params) do
    case Either.validate(params, create_user_validation()) do
      %Right{right: validated} ->
        {:ok, validated}

      %Left{left: %{errors: errors}} ->
        {:error, %{validation_errors: errors}}
    end
  end
end
```

## LLM Testing Guidance

### Test Basic Validation

```elixir
defmodule ValidationTest do
  use ExUnit.Case
  use Funx.Validate
  alias Funx.Monad.Either
  alias Funx.Monad.Either.{Left, Right}
  alias Funx.Errors.ValidationError
  alias Funx.Validator.{Required, Email, Positive}

  test "validates valid data" do
    validation =
      validate do
        at :name, Required
        at :email, Email
      end

    result = Either.validate(%{name: "Alice", email: "alice@example.com"}, validation)

    assert %Right{right: %{name: "Alice", email: "alice@example.com"}} = result
  end

  test "accumulates all errors" do
    validation =
      validate do
        at :name, Required
        at :email, [Required, Email]
        at :age, Positive
      end

    result = Either.validate(%{name: "", email: "bad", age: -5}, validation)

    assert %Left{left: %ValidationError{errors: errors}} = result
    assert length(errors) >= 3
  end

  test "preserves original structure on success" do
    validation =
      validate do
        at :name, Required
      end

    input = %{name: "Alice", extra: "field"}
    result = Either.validate(input, validation)

    assert %Right{right: ^input} = result
  end
end
```

### Test Optional Fields

```elixir
test "optional fields skip validation when missing" do
  validation =
    validate do
      at :age, Positive  # at :age uses Prism - optional
    end

  # Missing :age is fine
  result = Either.validate(%{name: "Alice"}, validation)
  assert %Right{} = result
end

test "optional fields validate when present" do
  validation =
    validate do
      at :age, Positive
    end

  # Present but invalid
  result = Either.validate(%{age: -5}, validation)
  assert %Left{} = result
end
```

### Test Environment Passing

```elixir
test "passes environment to validators" do
  defmodule TestUniqueEmail do
    @behaviour Funx.Validate.Behaviour
    alias Funx.Monad.Maybe.Nothing

    def validate(value, opts) when is_list(opts), do: validate(value, opts, %{})

    @impl true
    def validate(%Nothing{} = v, _, _), do: Either.right(v)
    def validate(email, _opts, env) do
      if email in Map.get(env, :existing, []) do
        Either.left(ValidationError.new("taken"))
      else
        Either.right(email)
      end
    end
  end

  validation =
    validate do
      at :email, TestUniqueEmail
    end

  env = %{existing: ["taken@example.com"]}

  assert %Right{} = Either.validate(%{email: "new@example.com"}, validation, env: env)
  assert %Left{} = Either.validate(%{email: "taken@example.com"}, validation, env: env)
end
```

## LLM Common Mistakes to Avoid

### ❌ Don't Forget to Handle Nothing

```elixir
# ❌ Wrong: ignores Nothing from Prism
defmodule BadValidator do
  @behaviour Funx.Validate.Behaviour

  def validate(value, opts) when is_list(opts), do: validate(value, opts, %{})

  @impl true
  def validate(value, _opts, _env) do
    if value > 0, do: Either.right(value), else: Either.left(ValidationError.new("error"))
  end
end

# ✅ Correct: handles Nothing
defmodule GoodValidator do
  @behaviour Funx.Validate.Behaviour
  alias Funx.Monad.Maybe.Nothing

  def validate(value, opts) when is_list(opts), do: validate(value, opts, %{})

  @impl true
  def validate(%Nothing{} = value, _opts, _env), do: Either.right(value)

  def validate(value, _opts, _env) do
    if value > 0, do: Either.right(value), else: Either.left(ValidationError.new("error"))
  end
end
```

### ❌ Don't Use Lens for Optional Fields

```elixir
# ❌ Wrong: Lens raises KeyError for missing fields
validation =
  validate do
    at Lens.key(:age), Positive  # Will raise if :age is missing!
  end

# ✅ Correct: use default Prism (via atom) for optional fields
validation =
  validate do
    at :age, Positive  # at :age uses Prism.key(:age) - safe for missing
  end
```

### ❌ Don't Assume Required is Automatic

```elixir
# ❌ Wrong: assumes field must be present
validation =
  validate do
    at :email, Email  # Missing :email will pass! (Prism returns Nothing, Email skips)
  end

# ✅ Correct: use Required for presence validation
validation =
  validate do
    at :email, [Required, Email]  # Required catches Nothing
  end
```

### ❌ Don't Transform Values in Validators

```elixir
# ❌ Wrong: transforms value
defmodule TransformingValidator do
  @behaviour Funx.Validate.Behaviour

  @impl true
  def validate(email, _opts, _env) do
    Either.right(String.downcase(email))  # Don't transform!
  end
end

# ✅ Correct: return original value
defmodule CheckingValidator do
  @behaviour Funx.Validate.Behaviour

  @impl true
  def validate(email, _opts, _env) do
    if valid_email?(email) do
      Either.right(email)  # Return original value
    else
      Either.left(ValidationError.new("invalid"))
    end
  end
end
```

## Summary

`Funx.Validate` provides declarative, composable data validation with applicative error accumulation. It uses optics for field projection and returns the original structure unchanged on success.

**Key capabilities:**

- **Optics-first design**: Prism by default, Lens for structure, Traversal for relationships
- **Applicative accumulation**: All validators run, all errors collected
- **Identity preservation**: Returns original structure unchanged on success
- **Composable validators**: Build complex validation from simple parts
- **Environment passing**: Context-dependent validation via `env` option

**Core patterns:**

- Use `at :field, Validator` for optional fields (Prism)
- Use `at :field, [Required, V]` for required fields
- Use `at Lens.key(:field), V` only when key must structurally exist
- Use `at [:a, :b], V` for nested paths
- Use `at Traversal.combine([...]), V` for relationship validation

**Integration points:**

- **Either**: `Either.validate(data, validator, opts)` executes validation
- **ValidationError**: Accumulated errors via `ValidationError.new/1`
- **Optics**: Lens, Prism, Traversal for field projection
- **Custom validators**: Implement `Funx.Validate.Behaviour`

**Canon**: Project with optics, validate with behaviours, accumulate errors applicatively, preserve identity on success.
