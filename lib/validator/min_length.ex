defmodule Funx.Validator.MinLength do
  @moduledoc """
  Validates that a string meets a minimum length requirement.

  ## Required Options

  - `:min` - Minimum length (integer)

  ## Optional Options

  - `:message` - Custom error message callback `(value -> String.t())`

  ## Examples

      iex> Funx.Validator.MinLength.validate("hello", min: 3)
      %Funx.Monad.Either.Right{right: "hello"}

      iex> Funx.Validator.MinLength.validate("hi", min: 5)
      %Funx.Monad.Either.Left{left: %Funx.Errors.ValidationError{errors: ["must be at least 5 characters"]}}
  """

  use Funx.Validator

  @impl Funx.Validator
  def valid?(string, opts, _env) when is_binary(string) do
    min = Keyword.fetch!(opts, :min)
    String.length(string) >= min
  end

  def valid?(_non_string, _opts, _env), do: false

  @impl Funx.Validator
  def default_message(value, opts) when is_binary(value) do
    min = Keyword.fetch!(opts, :min)
    "must be at least #{min} characters"
  end

  def default_message(_value, _opts) do
    "must be a string"
  end
end
