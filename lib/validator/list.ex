defmodule Funx.Validator.List do
  @moduledoc """
  Validates that a value is a list.

  ## Optional Options

  - `:message` - Custom error message callback `(value -> String.t())`

  ## Examples

      iex> Funx.Validator.List.validate([1, 2, 3])
      %Funx.Monad.Either.Right{right: [1, 2, 3]}

      iex> Funx.Validator.List.validate([])
      %Funx.Monad.Either.Right{right: []}

      iex> Funx.Validator.List.validate("not a list")
      %Funx.Monad.Either.Left{left: %Funx.Errors.ValidationError{errors: ["must be a list"]}}
  """

  use Funx.Validator

  alias Funx.Predicate

  @impl Funx.Validator
  def valid?(value, opts, _env) do
    predicate = Predicate.List.pred(opts)
    predicate.(value)
  end

  @impl Funx.Validator
  def default_message(_value, _opts) do
    "must be a list"
  end
end
