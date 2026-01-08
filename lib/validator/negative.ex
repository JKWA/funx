defmodule Funx.Validator.Negative do
  @moduledoc """
  Validates that a number is strictly negative (< 0).

  ## Optional Options

  - `:message` - Custom error message callback `(value -> String.t())`

  ## Examples

      iex> Funx.Validator.Negative.validate(-5)
      %Funx.Monad.Either.Right{right: -5}

      iex> Funx.Validator.Negative.validate(0)
      %Funx.Monad.Either.Left{left: %Funx.Errors.ValidationError{errors: ["must be negative"]}}

      iex> Funx.Validator.Negative.validate(5)
      %Funx.Monad.Either.Left{left: %Funx.Errors.ValidationError{errors: ["must be negative"]}}
  """

  @behaviour Funx.Validation.Behaviour

  alias Funx.Errors.ValidationError
  alias Funx.Monad.Either
  alias Funx.Monad.Maybe.{Just, Nothing}

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

  def validate(%Nothing{}, _opts, _env) do
    Either.right(%Nothing{})
  end

  def validate(%Just{value: number}, opts, _env) when is_number(number) do
    validate_number(number, opts)
  end

  def validate(%Just{value: value}, opts, _env) do
    message = build_message(opts, value, "must be a number")
    Either.left(ValidationError.new(message))
  end

  def validate(value, opts, _env) when is_number(value) do
    validate_number(value, opts)
  end

  def validate(value, opts, _env) do
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
