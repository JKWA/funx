defmodule Funx.Validator.Email do
  @moduledoc """
  Validates that a string is a valid email format.

  ## Basic Check

  This is a simple email validator that checks for the presence of an `@` symbol.
  For more robust email validation, use a dedicated library or custom validator.

  ## Optional Options

  - `:message` - Custom error message callback `(value -> String.t())`

  ## Examples

      iex> Funx.Validator.Email.validate("user@example.com", [])
      %Funx.Monad.Either.Right{right: "user@example.com"}

      iex> Funx.Validator.Email.validate("not-an-email", [])
      %Funx.Monad.Either.Left{left: %Funx.Errors.ValidationError{errors: ["must be a valid email"]}}
  """

  @behaviour Funx.Validation.Behaviour

  alias Funx.Errors.ValidationError
  alias Funx.Monad.Either
  alias Funx.Monad.Maybe.{Just, Nothing}

  @impl true
  def validate(value, opts \\ [])

  # Skip Nothing values (optional fields without value)
  def validate(%Nothing{}, _opts) do
    Either.right(%Nothing{})
  end

  # Handle Just(string) - extract and validate
  def validate(%Just{value: string}, opts) when is_binary(string) do
    validate_string(string, opts)
  end

  # Handle Just(non-string) - type error
  def validate(%Just{value: value}, opts) do
    message = build_message(opts, value, "must be a string")
    Either.left(ValidationError.new(message))
  end

  # Handle plain strings (backward compatibility)
  def validate(value, opts) when is_binary(value) do
    validate_string(value, opts)
  end

  # Handle non-string, non-Maybe values
  def validate(value, opts) do
    message = build_message(opts, value, "must be a string")
    Either.left(ValidationError.new(message))
  end

  defp validate_string(value, opts) do
    Either.lift_predicate(
      value,
      fn v -> String.contains?(v, "@") end,
      fn v -> ValidationError.new(build_message(opts, v, "must be a valid email")) end
    )
  end

  defp build_message(opts, value, default) do
    case Keyword.get(opts, :message) do
      nil -> default
      callback -> callback.(value)
    end
  end
end
