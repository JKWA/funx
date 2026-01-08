defmodule Funx.Validator.Range do
  @moduledoc """
  Validates that a number falls within an inclusive range.

  ## Optional Options

  - `:min` - Minimum value (inclusive)
  - `:max` - Maximum value (inclusive)
  - `:message` - Custom error message callback `(value -> String.t())`

  At least one of `:min` or `:max` must be provided.

  ## Examples

      iex> Funx.Validator.Range.validate(5, min: 1, max: 10)
      %Funx.Monad.Either.Right{right: 5}

      iex> Funx.Validator.Range.validate(15, min: 1, max: 10)
      %Funx.Monad.Either.Left{left: %Funx.Errors.ValidationError{errors: ["must be between 1 and 10"]}}

      iex> Funx.Validator.Range.validate(5, min: 10)
      %Funx.Monad.Either.Left{left: %Funx.Errors.ValidationError{errors: ["must be at least 10"]}}

      iex> Funx.Validator.Range.validate(15, max: 10)
      %Funx.Monad.Either.Left{left: %Funx.Errors.ValidationError{errors: ["must be at most 10"]}}
  """

  @behaviour Funx.Validate.Behaviour

  alias Funx.Errors.ValidationError
  alias Funx.Monad.Either
  alias Funx.Monad.Maybe.{Just, Nothing}

  # Convenience overload for default opts (raises on missing required options)
  def validate(value) do
    validate(value, [])
  end

  # Convenience overload for easier direct usage
  def validate(value, opts) when is_list(opts) do
    validate(value, opts, %{})
  end

  # Behaviour implementation (arity-3)
  @impl true
  def validate(value, opts, env)

  def validate(%Nothing{}, _opts, _env) do
    Either.right(%Nothing{})
  end

  def validate(%Just{value: number}, opts, _env) when is_number(number) do
    validate_number(number, opts)
  end

  def validate(%Just{value: value}, opts, _env) do
    message = build_message(opts, value, "must be a number")
    Either.left(ValidationError.new(message))
  end

  def validate(value, opts, _env) when is_number(value) do
    validate_number(value, opts)
  end

  def validate(value, opts, _env) do
    message = build_message(opts, value, "must be a number")
    Either.left(ValidationError.new(message))
  end

  defp validate_number(value, opts) do
    min = Keyword.get(opts, :min)
    max = Keyword.get(opts, :max)

    if is_nil(min) and is_nil(max) do
      raise ArgumentError, "Range validator requires at least :min or :max option"
    end

    Either.lift_predicate(
      value,
      fn v -> in_range?(v, min, max) end,
      fn v -> ValidationError.new(build_message(opts, v, default_message(min, max))) end
    )
  end

  defp in_range?(value, nil, max), do: value <= max
  defp in_range?(value, min, nil), do: value >= min
  defp in_range?(value, min, max), do: value >= min and value <= max

  defp default_message(min, max) when not is_nil(min) and not is_nil(max) do
    "must be between #{min} and #{max}"
  end

  defp default_message(min, nil) when not is_nil(min) do
    "must be at least #{min}"
  end

  defp default_message(nil, max) when not is_nil(max) do
    "must be at most #{max}"
  end

  defp build_message(opts, value, default) do
    case Keyword.get(opts, :message) do
      nil -> default
      callback -> callback.(value)
    end
  end
end
