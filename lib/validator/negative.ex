defmodule Funx.Validator.Negative do
  @moduledoc """
  Validates that a number is strictly negative (< 0).

  ## Optional Options

  - `:message` - Custom error message callback `(value -> String.t())`

  ## Examples

      iex> Funx.Validator.Negative.validate(-5, [])
      %Funx.Monad.Either.Right{right: -5}

      iex> Funx.Validator.Negative.validate(0, [])
      %Funx.Monad.Either.Left{left: %Funx.Errors.ValidationError{errors: ["must be negative"]}}

      iex> Funx.Validator.Negative.validate(5, [])
      %Funx.Monad.Either.Left{left: %Funx.Errors.ValidationError{errors: ["must be negative"]}}
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

  # Handle Just(number) - extract and validate
  def validate(%Just{value: number}, opts) when is_number(number) do
    validate_number(number, opts)
  end

  # Handle Just(non-number) - type error
  def validate(%Just{value: value}, opts) do
    message = build_message(opts, value, "must be a number")
    Either.left(ValidationError.new(message))
  end

  # Handle plain numbers (backward compatibility)
  def validate(value, opts) when is_number(value) do
    validate_number(value, opts)
  end

  # Handle non-number, non-Maybe values
  def validate(value, opts) do
    message = build_message(opts, value, "must be a number")
    Either.left(ValidationError.new(message))
  end

  defp validate_number(value, opts) do
    Either.lift_predicate(
      value,
      fn v -> v < 0 end,
      fn v -> ValidationError.new(build_message(opts, v, "must be negative")) end
    )
  end

  defp build_message(opts, value, default) do
    case Keyword.get(opts, :message) do
      nil -> default
      callback -> callback.(value)
    end
  end
end
