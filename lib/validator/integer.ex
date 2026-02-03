defmodule Funx.Validator.Integer do
  @moduledoc """
  Validates that a value is an integer.

  ## Optional Options

  - `:message` - Custom error message callback `(value -> String.t())`

  ## Examples

      iex> Funx.Validator.Integer.validate(5)
      %Funx.Monad.Either.Right{right: 5}

      iex> Funx.Validator.Integer.validate(5.5)
      %Funx.Monad.Either.Left{left: %Funx.Errors.ValidationError{errors: ["must be an integer"]}}
  """

  use Funx.Validator

  alias Funx.Predicate

  @impl Funx.Validator
  def valid?(value, opts, _env) do
    predicate = Predicate.Integer.pred(opts)
    predicate.(value)
  end

  @impl Funx.Validator
  def default_message(_value, _opts) do
    "must be an integer"
  end
end
