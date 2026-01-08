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

  @behaviour Funx.Validate.Behaviour

  alias Funx.Errors.ValidationError
  alias Funx.Monad.Either
  alias Funx.Monad.Maybe.{Just, Nothing}

  # Convenience overloads for easier direct usage
  def validate(value) do
    validate(value, [], %{})
  end

  def validate(value, opts) when is_list(opts) do
    validate(value, opts, %{})
  end

  # Behaviour implementation (arity-3)
  @impl true
  def validate(value, opts, env)

  def validate(%Nothing{}, _opts, _env) do
    Either.right(%Nothing{})
  end

  def validate(%Just{value: string}, opts, _env) when is_binary(string) do
    validate_string(string, opts)
  end

  def validate(%Just{value: value}, opts, _env) do
    message = build_message(opts, value, "must be a string")
    Either.left(ValidationError.new(message))
  end

  def validate(value, opts, _env) when is_binary(value) do
    validate_string(value, opts)
  end

  def validate(value, opts, _env) do
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
