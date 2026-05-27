defmodule Funx.Validator.Boolean do
  @moduledoc """
  Validates that a value is a boolean (true or false).

  ## Optional Options

  - `:message` - Custom error message callback `(value -> String.t())`

  ## Examples

      iex> Funx.Validator.Boolean.validate(true)
      %Funx.Monad.Either.Right{right: true}

      iex> Funx.Validator.Boolean.validate(false)
      %Funx.Monad.Either.Right{right: false}

      iex> Funx.Validator.Boolean.validate("true")
      %Funx.Monad.Either.Left{left: %Funx.Errors.ValidationError{errors: ["must be a boolean"]}}
  """

  use Funx.Validator

  alias Funx.Predicate

  @impl Funx.Validator
  def valid?(value, opts, _env) do
    predicate = Predicate.Boolean.pred(opts)
    predicate.(value)
  end

  @impl Funx.Validator
  def default_message(_value, _opts) do
    "must be a boolean"
  end
end
