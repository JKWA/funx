defmodule Funx.Validator.Integer do
  @moduledoc """
  Validates that a value is an integer.

  ## Optional Options

  - `:message` - Custom error message callback `(value -> String.t())`

  ## Examples

      iex> Funx.Validator.Integer.validate(5, [])
      %Funx.Monad.Either.Right{right: 5}

      iex> Funx.Validator.Integer.validate(5.5, [])
      %Funx.Monad.Either.Left{left: %Funx.Errors.ValidationError{errors: ["must be an integer"]}}
  """

  @behaviour Funx.Validation.Behaviour

  alias Funx.Errors.ValidationError
  alias Funx.Monad.Either
  alias Funx.Monad.Maybe.{Just, Nothing}

  @impl true
  def validate(value, opts \\ [])

  # Skip Nothing values (optional fields without value)
  def validate(%Nothing{}, _opts) do
    Either.right(%Nothing{})
  end

  # Handle Just(value) - extract and validate
  def validate(%Just{value: inner_value}, opts) do
    validate_value(inner_value, opts)
  end

  # Handle plain values (backward compatibility)
  def validate(value, opts) do
    validate_value(value, opts)
  end

  defp validate_value(value, opts) do
    Either.lift_predicate(
      value,
      fn v -> is_integer(v) end,
      fn v -> ValidationError.new(build_message(opts, v, "must be an integer")) end
    )
  end

  defp build_message(opts, value, default) do
    case Keyword.get(opts, :message) do
      nil -> default
      callback -> callback.(value)
    end
  end
end
