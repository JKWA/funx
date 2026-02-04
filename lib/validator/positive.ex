defmodule Funx.Validator.Positive do
  @moduledoc """
  Validates that a number is strictly positive (> 0).

  ## Optional Options

  - `:message` - Custom error message callback `(value -> String.t())`

  ## Examples

      iex> Funx.Validator.Positive.validate(5)
      %Funx.Monad.Either.Right{right: 5}

      iex> Funx.Validator.Positive.validate(0)
      %Funx.Monad.Either.Left{left: %Funx.Errors.ValidationError{errors: ["must be positive"]}}

      iex> Funx.Validator.Positive.validate(-5)
      %Funx.Monad.Either.Left{left: %Funx.Errors.ValidationError{errors: ["must be positive"]}}
  """

  use Funx.Validator

  alias Funx.Predicate

  @impl Funx.Validator
  def valid?(value, opts, _env) do
    predicate = Predicate.Positive.pred(opts)
    predicate.(value)
  end

  @impl Funx.Validator
  def default_message(value, _opts) when is_number(value) do
    "must be positive"
  end

  def default_message(_value, _opts) do
    "must be a number"
  end
end
