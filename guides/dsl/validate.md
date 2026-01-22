# Validate

The Validate DSL is a builder DSL that constructs validators for later use. See the [DSL Overview](overview.md) for the distinction between builder and pipeline DSLs.

## Structure

A `validate` block compiles at compile time to quoted AST that builds a validator function. The validator takes a value and options, projects into fields using optics, runs validators, and accumulates all errors applicatively.

## Internal Representation

The Validate DSL uses a single structure type to represent validation steps:

* `Step` - Contains optic AST (optional), validators list, and metadata

Each Step describes a single validation target: either a root validator (no optic) or a field validator (with optic projection). The compiler pattern-matches on these structs to generate the final quoted AST.

```text
Compilation
    ├── Step (root validator - no optic)
    ├── Step (at :name, [Required, MinLength])
    ├── Step (at [:user, :email], [Required, Email])
    └── Step (at Traversal.combine([...]), DateRange)
```

## Parser

The parser converts the DSL block into a list of Step structures. It normalizes all syntax into canonical forms:

### Root Validators

* Module implementing `Funx.Validate.Behaviour` - Validates entire structure
* `{Module, opts}` - Behaviour with options
* Function (arity-2 or arity-3) - Custom validator function
* Previously defined validator - Composable validator

### Field Validators (at directive)

The `at` directive composes an optic projection with validators. All projection syntax normalizes to one of:

* `Prism.t()` - Optional field projection (default for atoms)
* `Lens.t()` - Required field projection (raises on missing)
* `Traversal.t()` - Multiple foci projection
* `(a -> b)` - Projection function

Syntax sugar for projections:

* `:atom` → `Prism.key(:atom)`
* `[:a, :b]` → `Prism.path([:a, :b])` (supports nested keys and structs)
* `Lens.key(...)` → `Lens.key(...)` (pass through)
* `Prism.key(...)` → `Prism.key(...)` (pass through)
* `Traversal.combine(...)` → `Traversal.combine(...)` (pass through)
* `fn -> ... end` → `fn -> ... end` (pass through)

### Validator Forms

* Module alias → `Module`
* Tuple with options → `{Module, opts}`
* List of validators → `[V1, V2, V3]`
* Function (arity-2) → `fn value, opts -> ... end`
* Function (arity-3) → `fn value, opts, env -> ... end`
* Composable validator → Previously defined validator function

The parser validates projections and validators, raising compile-time errors for unsupported syntax (literals, empty lists, nested lists).

## Transformers

The Validate DSL does not currently support transformers. All compilation is handled by the parser and executor without intermediate rewriting stages.

## Execution

The executor runs at compile time and generates quoted AST. It processes the list of steps:

1. Take normalized steps from the parser
2. For each Step:
   * If root validator (no optic) → generate validator call on entire structure
   * If field validator (with optic) → project with optic, run validators on projected value
3. Combine all validators using applicative composition
4. Return `Either.t(ValidationError.t(), value)`

### Execution Modes

The DSL supports two execution modes:

**Sequential (default):**

```elixir
validate do
  at :name, Required
  at :email, Email
end
```

Uses `Either.traverse_a` for monadic composition. All validators still run and accumulate errors.

**Parallel:**

```elixir
validate mode: :parallel do
  at :name, Required
  at :email, Email
end
```

Uses `Effect.traverse_a` for explicit applicative composition. Semantically equivalent but makes the applicative nature explicit.

### Execution Model

An empty `validate` block compiles to a validator that always returns `Right(value)` (identity element).

Each directive compiles to:

* Root validator → `validator.validate(value, opts, env)`
* `at optic, validators` → Project value, run validators on projected result, accumulate errors
* Multiple validators → All run, all errors accumulated via `Appendable`

### Optic Projection

The `at` directive projects into the structure before validation:

**With Prism (default for atoms):**

```elixir
at :email, Email
```

Projects using `Prism.preview/2`. Missing keys result in `Nothing`, which most validators skip. Only `Required` validates on `Nothing`.

**With Lens:**

```elixir
at Lens.key(:name), Required
```

Projects using `Lens.view/2`. Missing keys raise `KeyError`. Use when field must structurally exist.

**With list path:**

```elixir
at [:user, :profile, :name], Required
```

Converts to `Prism.path([:user, :profile, :name])`. Supports nested keys and struct modules.

**With Traversal:**

```elixir
at Traversal.combine([Lens.key(:start_date), Lens.key(:end_date)]), DateRange
```

Collects multiple foci into a list for relationship validation.

### Compilation Example

```elixir
validate do
  HasContactMethod
  at :name, [Required, {MinLength, min: 3}]
  at :email, [Required, Email]
end
```

Compiles to a function equivalent to:

```elixir
fn value, opts ->
  env = Keyword.get(opts, :env, %{})

  validators = [
    fn v -> HasContactMethod.validate(v, [], env) end,
    fn v ->
      projected = Prism.preview(v, Prism.key(:name))
      run_validators(projected, [Required, {MinLength, min: 3}], env)
    end,
    fn v ->
      projected = Prism.preview(v, Prism.key(:email))
      run_validators(projected, [Required, Email], env)
    end
  ]

  validators
  |> Enum.map(& &1.(value))
  |> accumulate_results(value)
end
```

Where `accumulate_results` combines all `Either` results applicatively, returning `Right(original_value)` on success or `Left(accumulated_errors)` on failure.

## Behaviours

Modules participating in the Validate DSL implement `Funx.Validate.Behaviour`. The callback receives the value, options, and environment.

The `validate/3` callback receives:

* `value` - The value to validate (may be `Nothing` from Prism projection)
* `opts` - Keyword list of options passed in the DSL
* `env` - Environment map passed via `Either.validate(data, validator, env: env)`

Example:

```elixir
defmodule Positive do
  @behaviour Funx.Validate.Behaviour
  alias Funx.Monad.Maybe.Nothing
  alias Funx.Errors.ValidationError
  alias Funx.Monad.Either

  def validate(value, opts) when is_list(opts), do: validate(value, opts, %{})

  @impl true
  def validate(%Nothing{} = value, _opts, _env), do: Either.right(value)

  def validate(value, _opts, _env) when is_number(value) and value > 0,
    do: Either.right(value)

  def validate(_, _opts, _env),
    do: Either.left(ValidationError.new("must be positive"))
end
```

### Return Value Normalization

The DSL normalizes various return formats:

* `Either.t()` → Used directly
* `:ok` → Converted to `Right(value)`
* `{:ok, value}` → Converted to `Right(value)`
* `{:error, ValidationError.t()}` → Converted to `Left(error)`

## Error Accumulation

The Validate DSL uses applicative composition for error accumulation:

### Applicative Semantics

All validators run regardless of earlier failures. Errors are accumulated via `Appendable`:

```elixir
validate do
  at :name, Required      # Fails: "is required"
  at :email, Email        # Fails: "must be a valid email"
  at :age, Positive       # Fails: "must be positive"
end
```

Result: `Left(%ValidationError{errors: ["is required", "must be a valid email", "must be positive"]})`

### ValidationError Accumulation

`ValidationError` implements `Appendable`, allowing errors to be concatenated:

```elixir
ValidationError.append(
  ValidationError.new("error 1"),
  ValidationError.new("error 2")
)
# => %ValidationError{errors: ["error 1", "error 2"]}
```

## Identity Preservation

The Validate DSL preserves the original structure on success:

```elixir
validation =
  validate do
    at :name, Required
  end

input = %{name: "Alice", extra: "field", nested: %{data: 123}}
Either.validate(input, validation)
# => %Right{right: %{name: "Alice", extra: "field", nested: %{data: 123}}}
```

The original structure is returned unchanged. Validators check data; they do not transform it.

## Compile-Time Validation

The parser validates at compile time, rejecting invalid forms:

**Rejected:**

* Literal numbers: `at :name, 123`
* Literal strings: `at :name, "string"`
* Literal atoms: `at :name, :atom`
* Empty lists: `at :name, []`
* Nested lists: `at :name, [Required, [Email]]`

**Accepted:**

* Module aliases: `Required`, `Email`
* Tuples with options: `{MinLength, min: 3}`
* Lists of validators: `[Required, Email]`
* Function captures: `&my_validator/2`
* Anonymous functions: `fn x, opts -> ... end`
* Variables: `my_validator`
* Function calls: `my_validator()`, `Module.validator()`

## Composable Validators

Validators created with `validate` can be used inside other validators:

```elixir
item_validation =
  validate do
    at :name, Required
    at :price, Positive
  end

order_validation =
  validate do
    at :item, item_validation  # Nested validator
    at :quantity, Positive
  end
```

The nested validator runs on the projected value and its errors are accumulated with the parent's errors.

## Environment Passing

Validators can receive context via the environment:

```elixir
validation =
  validate do
    at :email, UniqueEmail  # Uses env[:existing_emails]
  end

Either.validate(data, validation, env: %{existing_emails: ["taken@example.com"]})
```

The environment is passed to all validators via the third argument of the `validate/3` callback.

## Integration with Either

Validators are executed via `Either.validate/3`:

```elixir
Either.validate(data, validator)
Either.validate(data, validator, env: %{key: value})
```

The result is `Either.t(ValidationError.t(), value)`:

* `%Right{right: value}` - Validation passed, original value returned
* `%Left{left: %ValidationError{errors: [...]}}` - Validation failed, all errors accumulated
