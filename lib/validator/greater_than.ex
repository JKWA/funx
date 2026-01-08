defmodule Funx.Validator.GreaterThan do
  @moduledoc """
  Validates that a number is strictly greater than a given threshold.

  `GreaterThan` enforces an ordering constraint of the form:
  “value must be greater than X”.

  This validator is useful for numeric comparisons where a strict lower bound
  must be enforced.

  Options

  - `:value` (required)
    The threshold value that the input must be greater than.

  - `:message` (optional)
    A custom error message callback `(value -> String.t())` used to override the
    default error message on failure.

  Semantics

  - If the value is greater than the given threshold, validation succeeds.
  - If the value is equal to or less than the threshold, validation fails.
  - `Nothing` values are preserved and treated as not applicable.
  - `Just` values are unwrapped before validation.
  - Non-numeric values result in a validation error.

  Examples

      iex> Funx.Validator.GreaterThan.validate(10, value: 5)
      %Funx.Monad.Either.Right{right: 10}

      iex> Funx.Validator.GreaterThan.validate(5, value: 5)
      %Funx.Monad.Either.Left{
        left: %Funx.Errors.ValidationError{
          errors: ["must be greater than 5"]
        }
      }

      iex> Funx.Validator.GreaterThan.validate(%Funx.Monad.Maybe.Nothing{}, value: 5)
      %Funx.Monad.Either.Right{right: %Funx.Monad.Maybe.Nothing{}}

      iex> Funx.Validator.GreaterThan.validate(3,
      ...>   value: 5,
      ...>   message: fn v -> "\#{v} is too small" end
      ...> )
      %Funx.Monad.Either.Left{
        left: %Funx.Errors.ValidationError{
          errors: ["3 is too small"]
        }
      }
  """

  @behaviour Funx.Validation.Behaviour

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

  def validate(%Nothing{} = value, _opts, _env) do
    Either.right(value)
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
    threshold = Keyword.fetch!(opts, :value)

    Either.lift_predicate(
      value,
      fn v -> v > threshold end,
      fn v ->
        ValidationError.new(build_message(opts, v, "must be greater than #{threshold}"))
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
