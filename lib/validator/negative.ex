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

  alias Funx.Predicate

  @impl Funx.Validator
  def valid?(value, opts, _env) do
    predicate = Predicate.Negative.pred(opts)
    predicate.(value)
  end

  @impl Funx.Validator
  def default_message(value, _opts) when is_number(value) do
    "must be negative"
  end

  def default_message(_value, _opts) do
    "must be a number"
  end
end
