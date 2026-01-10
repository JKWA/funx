defmodule Funx.Validator do
  @moduledoc """
  Macro for building custom validators with minimal boilerplate.

  Users creating custom validators (e.g., database checks, API validations) can use
  this macro to avoid reimplementing the standard validator pattern. The macro
  generates all the boilerplate including arity overloads, Maybe handling, message
  building, and Either wrapping.

  ## Two Behaviours

  This module defines two separate behaviours:

  1. **`Funx.Validate.Behaviour`** - The public contract for all validators.
     Defines `validate/3` which returns `Either.t(value, ValidationError.t())`.
     This is what the validation DSL and consumers interact with.

  2. **`Funx.Validator`** - The callback contract for users of this macro.
     Defines `validate_value/3` (returns boolean) and `default_message/1` (returns string).
     This is the simplified API for implementing custom validation logic.

  The macro generates the `Funx.Validate.Behaviour` implementation from your
  `Funx.Validator` callbacks.

  ## User API

  Users implement one required callback (and optionally a second):

  - `valid?/3` - Predicate function that returns `true` or `false` (required)
  - `default_message/2` - Returns a plain string error message (optional)

  If `default_message/2` is not implemented, a generic "is invalid" message is used.

  No need to know about `Either`, `ValidationError`, or `Maybe` - the macro
  handles all functional programming complexity.

  ## Examples

      # Minimal - just implement valid?/3
      defmodule MyApp.Validators.UniqueEmail do
        use Funx.Validator

        @impl Funx.Validator
        def valid?(email, _opts, _env) do
          not MyApp.Repo.exists?(User, email: email)
        end
        # Uses default "is invalid" message
      end

      # With custom message
      defmodule MyApp.Validators.UniqueEmailWithMessage do
        use Funx.Validator

        @impl Funx.Validator
        def valid?(email, _opts, _env) do
          not MyApp.Repo.exists?(User, email: email)
        end

        @impl Funx.Validator
        def default_message(_value, _opts) do
          "email is already taken"
        end
      end

      # With custom type checking (if needed)
      defmodule MyApp.Validators.CustomNumber do
        use Funx.Validator

        @impl Funx.Validator
        def valid?(num, _opts, _env) when is_number(num) do
          custom_number_check(num)
        end

        def valid?(_non_number, _opts, _env), do: false

        @impl Funx.Validator
        def default_message(_value), do: "must be a valid number"
      end

  ## Generated Code

  The macro generates:
  - `@behaviour Funx.Validate.Behaviour` implementation
  - Convenience helpers `validate/1`, `validate/2` (delegate to `validate/3`)
  - Maybe handling at the validation boundary (see Maybe Semantics below)
  - Message handling via `build_message/3` (supports `:message` option)
  - Either wrapping using `Either.lift_predicate`

  ## Maybe Semantics

  **Critical design rule**: `Nothing` always passes through unchanged.

  - `Nothing` → `Either.right(Nothing)` (validation skipped)
  - `Just(value)` → unwraps to `value`, calls your `validate_value/3`, re-wraps result
  - Raw value → calls your `validate_value/3` directly

  **Why `Nothing` passes**: In Funx's validation model, absence is handled by Prism
  optics. `Nothing` represents "value not present" (e.g., optional field missing).
  Only `Funx.Validator.Required` fails on absence - all other validators assume presence.

  **What you validate**: Your `validate_value/3` callback receives the **unwrapped value**,
  never `Nothing` or `Just`. The macro handles the Maybe boundary for you.

  ## Message Customization

  All generated validators support the `:message` option to override the default error:

      MyValidator.validate(value, message: fn v -> "custom error for \#{v}" end)

  The `:message` option accepts a **function** `(value -> String.t())` that receives
  the invalid value and returns an error message string. The macro wraps this in
  `ValidationError.new/1` automatically.

  **Note**: Only function callbacks are supported (not raw strings), consistent with
  all built-in Funx validators.

  ## Custom Message Override

  Users of your validator can override the default message using the `:message` option:

      MyApp.Validators.UniqueEmail.validate(
        "test@example.com",
        message: fn email -> "\#{email} is already registered" end
      )

  ## Built-in Validators

  Funx provides built-in validators for common scenarios:

  ### Presence and Structure
  - `Funx.Validator.Required` – Validates presence (not `nil`, not empty, not `Nothing`)
  - `Funx.Validator.Confirmation` – Validates that a value matches another field using `Eq`

  ### String Validators
  - `Funx.Validator.Email` – Validates basic email format
  - `Funx.Validator.MinLength` – Validates minimum string length
  - `Funx.Validator.MaxLength` – Validates maximum string length
  - `Funx.Validator.Pattern` – Validates against a regular expression

  ### Numeric Validators
  - `Funx.Validator.Integer` – Validates that the value is an integer
  - `Funx.Validator.Negative` – Validates number < 0
  - `Funx.Validator.Positive` – Validates number > 0
  - `Funx.Validator.Range` – Validates number within inclusive bounds

  ### Equality (Eq based)
  - `Funx.Validator.Equal` – Validates that a value equals an expected value using `Eq`
  - `Funx.Validator.NotEqual` – Validates that a value does not equal an expected value using `Eq`
  - `Funx.Validator.AllEqual` – Validates that all elements in a collection are equal using `Eq`

  ### Ordering (Ord based)
  - `Funx.Validator.GreaterThan` – Validates value > threshold
  - `Funx.Validator.GreaterThanOrEqual` – Validates value ≥ threshold
  - `Funx.Validator.LessThan` – Validates value < threshold
  - `Funx.Validator.LessThanOrEqual` – Validates value ≤ threshold

  ### Membership (Eq based)
  - `Funx.Validator.In` – Validates membership in a set of allowed values using `Eq`
  - `Funx.Validator.NotIn` – Validates non-membership in a set of disallowed values using `Eq`

  ### Combinators
  - `Funx.Validator.Any` – Validates that at least one of several validators succeeds (OR logic)
  - `Funx.Validator.Not` – Negates the result of another validator

  ### Predicate Lifting
  - `Funx.Validator.LiftPredicate` – Lifts a predicate function into a validator

  ## Validator Contract

  When implementing a validator with this macro, you must follow this contract:

  ### Input Handling

  - Your `valid?/3` receives the **unwrapped value** (never `Nothing` or `Just`)
  - `Nothing` is handled by the macro (always passes through)
  - You only validate **present values**
  - You can pattern match on type, structure, etc. in `valid?/3` clauses

  ### Return Values

  - Return `true` if validation passes
  - Return `false` if validation fails (triggers `default_message/1`)
  - The macro wraps your boolean in `Either` and `ValidationError` automatically

  ### Options and Environment

  - `opts` - Configuration for your validator (e.g., `[threshold: 100]`)
  - `env` - Runtime context (database, session, etc.) - currently unused by convention
  - If you need `opts` or `env`, pattern match them; otherwise use `_opts`, `_env`

  ### Error Messages

  - Implement `default_message/1` to return a plain string
  - You can pattern match on value to customize the message
  - Users can override with `:message` option (function callback)
  """

  @doc """
  Callback for custom validation predicate.

  Your implementation receives the **unwrapped value** (never `Nothing` or `Just`).

  ## Arguments

  - `value` - The value to validate (unwrapped from Just if applicable)
  - `opts` - Keyword list of options passed to the validator
  - `env` - Environment map (runtime context like database connections, session data)

  ## Returns

  - `true` - Validation passed
  - `false` - Validation failed (will use default_message/1)

  ## Example

      @impl Funx.Validator
      def valid?(num, opts, _env) when is_number(num) do
        threshold = Keyword.get(opts, :min, 0)
        num >= threshold
      end

      def valid?(_non_number, _opts, _env), do: false
  """
  alias Funx.Errors.ValidationError

  @callback valid?(value :: any(), opts :: keyword(), env :: map()) :: boolean()

  @doc """
  Callback for default error message.

  Returns a plain string that will be wrapped in `ValidationError.new/1`.

  **This callback is optional.** If not implemented, a generic "is invalid" message is used.

  ## Arguments

  - `value` - The value that failed validation
  - `opts` - Keyword list of options (for accessing configuration in error messages)

  ## Returns

  A plain string error message (will be wrapped in `ValidationError.new/1`)

  ## Example

      @impl Funx.Validator
      def default_message(value, opts) when is_binary(value) do
        min = Keyword.get(opts, :min, 0)
        "must be at least \#{min} characters"
      end

      def default_message(_value, _opts) do
        "must be a string"
      end
  """
  @callback default_message(value :: any(), opts :: keyword()) :: String.t()

  @optional_callbacks default_message: 2

  @doc """
  Helper function to build error messages with :message option support.

  This can be used by validators that don't use the macro but want consistent
  message handling.

  ## Arguments

  - `opts` - Keyword list that may contain a `:message` callback
  - `value` - The value that failed validation
  - `default` - The default message to use if no `:message` option provided

  ## Returns

  A string message - either from the `:message` callback or the default

  ## Example

      defp validate_something(value, opts) do
        if valid?(value) do
          Either.right(value)
        else
          message = Funx.Validator.build_message(opts, value, "default error")
          Either.left(ValidationError.new(message))
        end
      end
  """
  def build_message(opts, value, default) do
    case Keyword.get(opts, :message) do
      nil -> default
      callback -> callback.(value)
    end
  end

  @doc """
  Helper function to build a ValidationError with message option support.

  Combines `build_message/3` and `ValidationError.new/1` into a single call.
  This is the most common pattern for validators.

  ## Arguments

  - `opts` - Keyword list that may contain a `:message` callback
  - `value` - The value that failed validation
  - `default` - The default message to use if no `:message` option provided

  ## Returns

  A `ValidationError` struct

  ## Example

      defp validate_something(value, opts) do
        if valid?(value) do
          Either.right(value)
        else
          error = Funx.Validator.validation_error(opts, value, "default error")
          Either.left(error)
        end
      end
  """
  def validation_error(opts, value, default) do
    message = build_message(opts, value, default)
    ValidationError.new(message)
  end

  defmacro __using__(_opts) do
    quote location: :keep do
      @behaviour Funx.Validate.Behaviour
      @behaviour Funx.Validator

      alias Funx.Errors.ValidationError
      alias Funx.Monad.Either
      alias Funx.Monad.Maybe.{Just, Nothing}

      # Convenience overload for easier direct usage
      def validate(value) do
        validate(value, [], %{})
      end

      def validate(value, opts) when is_list(opts) do
        validate(value, opts, %{})
      end

      # Behaviour implementation (arity-3)
      @impl Funx.Validate.Behaviour
      def validate(value, opts, env)

      # Nothing always passes through
      def validate(%Nothing{}, _opts, _env) do
        Either.right(%Nothing{})
      end

      # Just - unwrap and validate
      def validate(%Just{value: val}, opts, env) do
        do_validate(val, opts, env)
      end

      # Raw value - validate directly
      def validate(value, opts, env) do
        do_validate(value, opts, env)
      end

      def default_message(_value, _opts) do
        "is invalid"
      end

      defoverridable default_message: 2

      defp do_validate(value, opts, env) do
        Either.lift_predicate(
          value,
          fn v -> valid?(v, opts, env) end,
          fn v -> Funx.Validator.validation_error(opts, v, default_message(v, opts)) end
        )
      end
    end
  end
end
