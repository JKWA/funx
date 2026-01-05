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
    regex = Keyword.fetch!(opts, :regex)

    Either.lift_predicate(
      value,
      fn v -> Regex.match?(regex, v) end,
      fn v -> ValidationError.new(build_message(opts, v, "has invalid format")) end
    )
  end

  defp build_message(opts, value, default) do
    case Keyword.get(opts, :message) do
      nil -> default
      callback -> callback.(value)
    end
  end
end
