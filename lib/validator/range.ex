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

  use Funx.Validator

  @impl Funx.Validator
  def valid?(number, opts, _env) when is_number(number) do
    min = Keyword.get(opts, :min)
    max = Keyword.get(opts, :max)

    if is_nil(min) and is_nil(max) do
      raise ArgumentError, "Range validator requires at least :min or :max option"
    end

    in_range?(number, min, max)
  end

  def valid?(_non_number, _opts, _env), do: false

  @impl Funx.Validator
  def default_message(value, opts) when is_number(value) do
    min = Keyword.get(opts, :min)
    max = Keyword.get(opts, :max)
    build_range_message(min, max)
  end

  def default_message(_value, _opts) do
    "must be a number"
  end

  defp in_range?(value, nil, max), do: value <= max
  defp in_range?(value, min, nil), do: value >= min
  defp in_range?(value, min, max), do: value >= min and value <= max

  defp build_range_message(min, max) when not is_nil(min) and not is_nil(max) do
    "must be between #{min} and #{max}"
  end

  defp build_range_message(min, nil) when not is_nil(min) do
    "must be at least #{min}"
  end

  defp build_range_message(nil, max) when not is_nil(max) do
    "must be at most #{max}"
  end
end
