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
    max = Keyword.fetch!(opts, :max)

    Either.lift_predicate(
      value,
      fn v -> String.length(v) <= max end,
      fn v ->
        ValidationError.new(build_message(opts, v, "must be at most #{max} characters"))
      end
    )
  end

  defp build_message(opts, value, default) do
    case Keyword.get(opts, :message) do
      nil -> default
      callback -> callback.(value)
    end
  end
end
