defmodule Funx.Validation.Behaviour do
  @moduledoc """
  Behaviour for validation functions.

  All validators follow a consistent arity-3 signature, matching other DSL behaviours in Funx.

  ## Contract

  ```elixir
  @callback validate(value :: any(), opts :: keyword(), env :: map()) ::
    Funx.Monad.Either.t(any(), Funx.Errors.ValidationError.t())
    | :ok
    | {:ok, any()}
    | {:error, Funx.Errors.ValidationError.t()}
  ```

  ## Arguments

  - `value` - The value to validate (may be transformed by previous validators)
  - `opts` - Keyword list of options (validator-specific configuration)
  - `env` - Environment map (runtime context like database connections, session data)

  ## Return Values

  **Canonical (preferred)**:
  - `Either.right(value)` - Validation passed, return original or transformed value
  - `Either.left(ValidationError.t())` - Validation failed with error

  **Legacy (supported via normalization)**:
  - `:ok` - Validation passed, return original value
  - `{:ok, value}` - Validation passed with transformation
  - `{:error, ValidationError.t()}` - Validation failed

  ## Semantic Rules

  1. **Arguments strictly ordered**: value, opts, env
  2. **Either is canonical** (tagged tuples normalized by DSL)
  3. **Value transformation allowed** (sequential within focus)
  4. **Never raise for validation failure** (use Left/error tuple)
  5. **Return ValidationError** for errors (not raw strings)
  6. **Concurrency-safe** by contract

  ## Message Option

  All validators should support a `:message` option for custom error messages:

  - **String**: `[message: "custom error"]`
  - **Function**: `[message: fn value -> "got \#{inspect(value)}" end]`

  When a function is provided, it receives the current value being validated.

  ## Example

  ```elixir
  defmodule MyValidator do
    @behaviour Funx.Validation.Behaviour
    alias Funx.Monad.Either
    alias Funx.Errors.ValidationError

    @impl true
    def validate(value, opts, _env) do
      if valid?(value) do
        Either.right(value)
      else
        message = get_message(opts, value, "default error message")
        Either.left(ValidationError.new(message))
      end
    end

    defp get_message(opts, value, default) do
      case Keyword.get(opts, :message) do
        nil -> default
        msg when is_binary(msg) -> msg
        msg_fn when is_function(msg_fn, 1) -> msg_fn.(value)
      end
    end
  end
  ```
  """

  alias Funx.Errors.ValidationError
  alias Funx.Monad.Either

  @callback validate(value :: any(), opts :: keyword(), env :: map()) ::
              Either.t(any(), ValidationError.t())
              | :ok
              | {:ok, any()}
              | {:error, ValidationError.t()}
end
