defmodule Funx.Validator.Email do
  @moduledoc """
  Validates that a string is a valid email format.

  ## Basic Check

  This is a simple email validator that checks for the presence of an `@` symbol.
  For more robust email validation, use a dedicated library or custom validator.

  ## Optional Options

  - `:message` - Custom error message callback `(value -> String.t())`

  ## Examples

      iex> Funx.Validator.Email.validate("user@example.com")
      %Funx.Monad.Either.Right{right: "user@example.com"}

      iex> Funx.Validator.Email.validate("not-an-email")
      %Funx.Monad.Either.Left{left: %Funx.Errors.ValidationError{errors: ["must be a valid email"]}}
  """

  use Funx.Validator

  @impl Funx.Validator
  def valid?(string, _opts, _env) when is_binary(string) do
    String.contains?(string, "@")
  end

  def valid?(_non_string, _opts, _env), do: false

  @impl Funx.Validator
  def default_message(value, _opts) when is_binary(value) do
    "must be a valid email"
  end

  def default_message(_value, _opts) do
    "must be a string"
  end
end
