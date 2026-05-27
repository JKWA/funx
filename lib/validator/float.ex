defmodule Funx.Validator.Float do
  @moduledoc """
  Validates that a value is a float.

  ## Optional Options

  - `:message` - Custom error message callback `(value -> String.t())`

  ## Examples

      iex> Funx.Validator.Float.validate(3.14)
      %Funx.Monad.Either.Right{right: 3.14}

      iex> Funx.Validator.Float.validate(5)
      %Funx.Monad.Either.Left{left: %Funx.Errors.ValidationError{errors: ["must be a float"]}}
  """

  use Funx.Validator

  alias Funx.Predicate

  @impl Funx.Validator
  def valid?(value, opts, _env) do
    predicate = Predicate.Float.pred(opts)
    predicate.(value)
  end

  @impl Funx.Validator
  def default_message(_value, _opts) do
    "must be a float"
  end
end
