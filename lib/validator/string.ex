defmodule Funx.Validator.String do
  @moduledoc """
  Validates that a value is a string (binary).

  ## Optional Options

  - `:message` - Custom error message callback `(value -> String.t())`

  ## Examples

      iex> Funx.Validator.String.validate("hello")
      %Funx.Monad.Either.Right{right: "hello"}

      iex> Funx.Validator.String.validate(42)
      %Funx.Monad.Either.Left{left: %Funx.Errors.ValidationError{errors: ["must be a string"]}}
  """

  use Funx.Validator

  alias Funx.Predicate

  @impl Funx.Validator
  def valid?(value, opts, _env) do
    predicate = Predicate.String.pred(opts)
    predicate.(value)
  end

  @impl Funx.Validator
  def default_message(_value, _opts) do
    "must be a string"
  end
end
