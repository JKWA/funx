defmodule Funx.Validator.Map do
  @moduledoc """
  Validates that a value is a map.

  ## Optional Options

  - `:message` - Custom error message callback `(value -> String.t())`

  ## Examples

      iex> Funx.Validator.Map.validate(%{key: "value"})
      %Funx.Monad.Either.Right{right: %{key: "value"}}

      iex> Funx.Validator.Map.validate(%{})
      %Funx.Monad.Either.Right{right: %{}}

      iex> Funx.Validator.Map.validate([key: "value"])
      %Funx.Monad.Either.Left{left: %Funx.Errors.ValidationError{errors: ["must be a map"]}}
  """

  use Funx.Validator

  alias Funx.Predicate

  @impl Funx.Validator
  def valid?(value, opts, _env) do
    predicate = Predicate.Map.pred(opts)
    predicate.(value)
  end

  @impl Funx.Validator
  def default_message(_value, _opts) do
    "must be a map"
  end
end
