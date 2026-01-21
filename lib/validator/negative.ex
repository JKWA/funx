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

  use Funx.Validator

  @impl Funx.Validator
  def valid?(number, _opts, _env) when is_number(number) do
    number < 0
  end

  def valid?(_non_number, _opts, _env), do: false

  @impl Funx.Validator
  def default_message(value, _opts) when is_number(value) do
    "must be negative"
  end

  def default_message(_value, _opts) do
    "must be a number"
  end
end
