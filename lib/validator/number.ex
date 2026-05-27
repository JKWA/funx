defmodule Funx.Validator.Number do
  @moduledoc """
  Validates that a value is a number (integer or float).

  ## Optional Options

  - `:message` - Custom error message callback `(value -> String.t())`

  ## Examples

      iex> Funx.Validator.Number.validate(42)
      %Funx.Monad.Either.Right{right: 42}

      iex> Funx.Validator.Number.validate(3.14)
      %Funx.Monad.Either.Right{right: 3.14}

      iex> Funx.Validator.Number.validate("42")
      %Funx.Monad.Either.Left{left: %Funx.Errors.ValidationError{errors: ["must be a number"]}}
  """

  use Funx.Validator

  alias Funx.Predicate

  @impl Funx.Validator
  def valid?(value, opts, _env) do
    predicate = Predicate.Number.pred(opts)
    predicate.(value)
  end

  @impl Funx.Validator
  def default_message(_value, _opts) do
    "must be a number"
  end
end
