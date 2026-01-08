defmodule Funx.Validator.Required do
  @moduledoc """
  Validates that a value is present (not nil, not empty string, not Nothing).

  ## Special Semantics

  **Required is the ONLY validator that runs on `Maybe.Nothing`.**

  All other validators skip `Nothing` values (from Prism projections).
  This makes fields optional-by-default with explicit presence checks.

  ## Failure Conditions

  - `nil`
  - `""` (empty string)
  - `%Maybe.Nothing{}` (from Prism projections)

  ## Success Conditions

  All other values, including:
  - `0`, `false`, `[]` (falsy but present values)

  ## Options

  - `:message` - Custom error message callback `(value -> String.t())`

  ## Examples

      iex> Funx.Validator.Required.validate("hello")
      %Funx.Monad.Either.Right{right: "hello"}

      iex> Funx.Validator.Required.validate(nil)
      %Funx.Monad.Either.Left{left: %Funx.Errors.ValidationError{errors: ["is required"]}}

      iex> Funx.Validator.Required.validate(0)
      %Funx.Monad.Either.Right{right: 0}
  """

  @behaviour Funx.Validation.Behaviour

  alias Funx.Errors.ValidationError
  alias Funx.Monad.Either
  alias Funx.Monad.Maybe.Nothing

  # Convenience overloads for easier direct usage
  def validate(value) do
    validate(value, [], %{})
  end

  def validate(value, opts) when is_list(opts) do
    validate(value, opts, %{})
  end

  # Behaviour implementation (arity-3)
  @impl true
  def validate(value, opts, env)

  def validate(%Nothing{}, opts, _env) do
    message = build_message(opts, nil, "is required")
    Either.left(ValidationError.new(message))
  end

  def validate(value, opts, _env) do
    Either.lift_predicate(
      value,
      fn v -> not is_nil(v) and v != "" end,
      fn v -> ValidationError.new(build_message(opts, v, "is required")) end
    )
  end

  defp build_message(opts, value, default) do
    case Keyword.get(opts, :message) do
      nil -> default
      callback -> callback.(value)
    end
  end
end
