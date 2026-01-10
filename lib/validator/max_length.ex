defmodule Funx.Validator.MaxLength do
  @moduledoc """
  Validates that a string does not exceed a maximum length.

  ## Required Options

  - `:max` - Maximum length (integer)

  ## Optional Options

  - `:message` - Custom error message callback `(value -> String.t())`

  ## Examples

      iex> Funx.Validator.MaxLength.validate("hi", [max: 5])
      %Funx.Monad.Either.Right{right: "hi"}

      iex> Funx.Validator.MaxLength.validate("hello world", [max: 5])
      %Funx.Monad.Either.Left{left: %Funx.Errors.ValidationError{errors: ["must be at most 5 characters"]}}

      iex> Funx.Validator.MaxLength.validate("hello world", [max: 5, message: fn val -> "'\#{val}' is too long" end])
      %Funx.Monad.Either.Left{left: %Funx.Errors.ValidationError{errors: ["'hello world' is too long"]}}
  """

  use Funx.Validator

  @impl Funx.Validator
  def valid?(string, opts, _env) when is_binary(string) do
    max = Keyword.fetch!(opts, :max)
    String.length(string) <= max
  end

  def valid?(_non_string, _opts, _env), do: false

  @impl Funx.Validator
  def default_message(value, opts) when is_binary(value) do
    max = Keyword.fetch!(opts, :max)
    "must be at most #{max} characters"
  end

  def default_message(_value, _opts) do
    "must be a string"
  end
end
