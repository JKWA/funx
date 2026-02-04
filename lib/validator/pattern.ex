defmodule Funx.Validator.Pattern do
  @moduledoc """
  Validates that a string matches a regular expression pattern.

  ## Required Options

  - `:regex` - Regular expression pattern (Regex.t())

  ## Optional Options

  - `:message` - Custom error message callback `(value -> String.t())`

  ## Examples

      iex> Funx.Validator.Pattern.validate("ABC123", regex: ~r/^[A-Z0-9]+$/)
      %Funx.Monad.Either.Right{right: "ABC123"}

      iex> Funx.Validator.Pattern.validate("abc", regex: ~r/^[A-Z0-9]+$/)
      %Funx.Monad.Either.Left{left: %Funx.Errors.ValidationError{errors: ["has invalid format"]}}
  """

  use Funx.Validator

  alias Funx.Predicate

  @impl Funx.Validator
  def valid?(value, opts, _env) do
    predicate = Predicate.Pattern.pred(opts)
    predicate.(value)
  end

  @impl Funx.Validator
  def default_message(value, _opts) when is_binary(value) do
    "has invalid format"
  end

  def default_message(_value, _opts) do
    "must be a string"
  end
end
