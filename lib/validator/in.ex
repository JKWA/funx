defmodule Funx.Validator.In do
  @moduledoc """
  Validates that a value is a member of a given list.

  ## Required Options

  - `:values` - List of allowed values

  ## Optional Options

  - `:message` - Custom error message callback `(value -> String.t())`

  ## Examples

      iex> Funx.Validator.In.validate("red", values: ["red", "green", "blue"])
      %Funx.Monad.Either.Right{right: "red"}

      iex> Funx.Validator.In.validate("yellow", values: ["red", "green", "blue"])
      %Funx.Monad.Either.Left{left: %Funx.Errors.ValidationError{errors: ["must be one of: red, green, blue"]}}
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

  # Handle Just(value) - extract and validate
  def validate(%Just{value: inner_value}, opts) do
    validate_value(inner_value, opts)
  end

  # Handle plain values (backward compatibility)
  def validate(value, opts) do
    validate_value(value, opts)
  end

  defp validate_value(value, opts) do
    values = Keyword.fetch!(opts, :values)

    Either.lift_predicate(
      value,
      fn v -> v in values end,
      fn v ->
        ValidationError.new(build_message(opts, v, "must be one of: #{Enum.join(values, ", ")}"))
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
