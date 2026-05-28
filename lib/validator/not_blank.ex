defmodule Funx.Validator.NotBlank do
  @moduledoc """
  Validates that a string is not blank (has content after trimming whitespace).

  ## Optional Options

  - `:message` - Custom error message callback `(value -> String.t())`

  ## Examples

      iex> Funx.Validator.NotBlank.validate("hello")
      %Funx.Monad.Either.Right{right: "hello"}

      iex> Funx.Validator.NotBlank.validate("  hello  ")
      %Funx.Monad.Either.Right{right: "  hello  "}

      iex> Funx.Validator.NotBlank.validate("")
      %Funx.Monad.Either.Left{left: %Funx.Errors.ValidationError{errors: ["must not be blank"]}}

      iex> Funx.Validator.NotBlank.validate("   ")
      %Funx.Monad.Either.Left{left: %Funx.Errors.ValidationError{errors: ["must not be blank"]}}

      iex> Funx.Validator.NotBlank.validate(42)
      %Funx.Monad.Either.Left{left: %Funx.Errors.ValidationError{errors: ["must not be blank"]}}
  """

  use Funx.Validator

  alias Funx.Predicate

  @impl Funx.Validator
  def valid?(value, opts, _env) do
    predicate = Predicate.NotBlank.pred(opts)
    predicate.(value)
  end

  @impl Funx.Validator
  def default_message(_value, _opts) do
    "must not be blank"
  end
end
