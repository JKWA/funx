defmodule Funx.Validator.NonEmpty do
  @moduledoc """
  Validates that a value is a non-empty list.

  ## Optional Options

  - `:message` - Custom error message callback `(value -> String.t())`

  ## Examples

      iex> Funx.Validator.NonEmpty.validate([1, 2, 3])
      %Funx.Monad.Either.Right{right: [1, 2, 3]}

      iex> Funx.Validator.NonEmpty.validate([1])
      %Funx.Monad.Either.Right{right: [1]}

      iex> Funx.Validator.NonEmpty.validate([])
      %Funx.Monad.Either.Left{left: %Funx.Errors.ValidationError{errors: ["must be a non-empty list"]}}

      iex> Funx.Validator.NonEmpty.validate("not a list")
      %Funx.Monad.Either.Left{left: %Funx.Errors.ValidationError{errors: ["must be a non-empty list"]}}
  """

  use Funx.Validator

  alias Funx.Predicate

  @impl Funx.Validator
  def valid?(value, opts, _env) do
    predicate = Predicate.NonEmpty.pred(opts)
    predicate.(value)
  end

  @impl Funx.Validator
  def default_message(_value, _opts) do
    "must be a non-empty list"
  end
end
