defmodule Funx.Validator.IsTrue do
  @moduledoc """
  Validates that a value is `true`.

  Uses strict equality (`== true`), not truthiness.
  This is useful for validating boolean flags like acceptance checkboxes.

  ## Optional Options

  - `:message` - Custom error message callback `(value -> String.t())`

  ## Examples

      iex> Funx.Validator.IsTrue.validate(true)
      %Funx.Monad.Either.Right{right: true}

      iex> Funx.Validator.IsTrue.validate(false)
      %Funx.Monad.Either.Left{left: %Funx.Errors.ValidationError{errors: ["must be true"]}}

      iex> Funx.Validator.IsTrue.validate(1)
      %Funx.Monad.Either.Left{left: %Funx.Errors.ValidationError{errors: ["must be true"]}}
  """

  use Funx.Validator

  alias Funx.Predicate

  @impl Funx.Validator
  def valid?(value, opts, _env) do
    predicate = Predicate.IsTrue.pred(opts)
    predicate.(value)
  end

  @impl Funx.Validator
  def default_message(_value, _opts) do
    "must be true"
  end
end
