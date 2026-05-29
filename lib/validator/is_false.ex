defmodule Funx.Validator.IsFalse do
  @moduledoc """
  Validates that a value is `false`.

  Uses strict equality (`== false`), not falsiness.
  This is useful for validating boolean flags like confirmation that something is not set.

  ## Optional Options

  - `:message` - Custom error message callback `(value -> String.t())`

  ## Examples

      iex> Funx.Validator.IsFalse.validate(false)
      %Funx.Monad.Either.Right{right: false}

      iex> Funx.Validator.IsFalse.validate(true)
      %Funx.Monad.Either.Left{left: %Funx.Errors.ValidationError{errors: ["must be false"]}}

      iex> Funx.Validator.IsFalse.validate(nil)
      %Funx.Monad.Either.Left{left: %Funx.Errors.ValidationError{errors: ["must be false"]}}
  """

  use Funx.Validator

  alias Funx.Predicate

  @impl Funx.Validator
  def valid?(value, opts, _env) do
    predicate = Predicate.IsFalse.pred(opts)
    predicate.(value)
  end

  @impl Funx.Validator
  def default_message(_value, _opts) do
    "must be false"
  end
end
