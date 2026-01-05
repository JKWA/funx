defmodule Funx.Validator.LessThanOrEqual do
  @moduledoc """
  Validates that a number is less than or equal to a given threshold.

  `LessThanOrEqual` enforces an ordering constraint of the form:
  “value must be less than or equal to X”.

  Options

  - `:value` (required)
    The threshold value that the input must be less than or equal to.

  - `:message` (optional)
    A custom error message callback `(value -> String.t())` used to override the
    default error message on failure.

  Semantics

  - If the value is less than or equal to the threshold, validation succeeds.
  - If the value is greater than the threshold, validation fails.
  - `Nothing` values are preserved and treated as not applicable.
  - `Just` values are unwrapped before validation.
  - Non-numeric values result in a validation error.

  Examples

      iex> Funx.Validator.LessThanOrEqual.validate(5, value: 5)
      %Funx.Monad.Either.Right{right: 5}

      iex> Funx.Validator.LessThanOrEqual.validate(7, value: 5)
      %Funx.Monad.Either.Left{
        left: %Funx.Errors.ValidationError{
          errors: ["must be less than or equal to 5"]
        }
      }

      iex> Funx.Validator.LessThanOrEqual.validate(%Funx.Monad.Maybe.Nothing{}, value: 5)
      %Funx.Monad.Either.Right{right: %Funx.Monad.Maybe.Nothing{}}

      iex> Funx.Validator.LessThanOrEqual.validate(7,
      ...>   value: 5,
      ...>   message: fn v -> "\#{v} is too large" end
      ...> )
      %Funx.Monad.Either.Left{
        left: %Funx.Errors.ValidationError{
          errors: ["7 is too large"]
        }
      }
  """

  @behaviour Funx.Validation.Behaviour

  alias Funx.Errors.ValidationError
  alias Funx.Monad.Either
  alias Funx.Monad.Maybe.{Just, Nothing}

  @impl true
  def validate(value, opts)

  def validate(%Nothing{} = value, _opts) do
    Either.right(value)
  end

  def validate(%Just{value: number}, opts) when is_number(number) do
    validate_number(number, opts)
  end

  def validate(%Just{value: value}, opts) do
    message = build_message(opts, value, "must be a number")
    Either.left(ValidationError.new(message))
  end

  def validate(value, opts) when is_number(value) do
    validate_number(value, opts)
  end

  def validate(value, opts) do
    message = build_message(opts, value, "must be a number")
    Either.left(ValidationError.new(message))
  end

  defp validate_number(value, opts) do
    threshold = Keyword.fetch!(opts, :value)

    Either.lift_predicate(
      value,
      fn v -> v <= threshold end,
      fn v ->
        ValidationError.new(build_message(opts, v, "must be less than or equal to #{threshold}"))
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
