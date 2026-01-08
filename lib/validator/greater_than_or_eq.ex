defmodule Funx.Validator.GreaterThanOrEqual do
  @moduledoc """
  Validates that a value is greater than or equal to a given reference value
  using an `Ord` comparator.

  `GreaterThanOrEqual` enforces an ordering constraint of the form:
  “value must be greater than or equal to X”.

  Ordering is defined by an `Ord` instance, not by numeric comparison or
  structural operators.

  Options

  - `:value` (required)
    The reference value to compare against.

  - `:ord` (optional)
    An ordering comparator. Defaults to `Funx.Ord.Protocol`.

  - `:message` (optional)
    A custom error message callback `(value -> String.t())` used to override the
    default error message on failure.

  Semantics

  - If the value compares as `:gt` or `:eq` relative to the reference value under
    the given `Ord`, validation succeeds.
  - If the value compares as `:lt`, validation fails.
  - `Nothing` values are preserved and treated as not applicable.
  - `Just` values are unwrapped before comparison.

  Examples

      iex> Funx.Validator.GreaterThanOrEqual.validate(7, value: 5)
      %Funx.Monad.Either.Right{right: 7}

      iex> Funx.Validator.GreaterThanOrEqual.validate("b", value: "a")
      %Funx.Monad.Either.Right{right: "b"}

      iex> Funx.Validator.GreaterThanOrEqual.validate("a", value: "b")
      %Funx.Monad.Either.Left{
        left: %Funx.Errors.ValidationError{
          errors: ["must be greater than or equal to \\\"b\\\""]
        }
      }

      iex> Funx.Validator.GreaterThanOrEqual.validate(%Funx.Monad.Maybe.Nothing{}, value: 5)
      %Funx.Monad.Either.Right{right: %Funx.Monad.Maybe.Nothing{}}
  """

  @behaviour Funx.Validate.Behaviour

  alias Funx.Errors.ValidationError
  alias Funx.Monad.Either
  alias Funx.Monad.Maybe.{Just, Nothing}
  alias Funx.Ord

  def validate(value) do
    validate(value, [])
  end

  def validate(value, opts) when is_list(opts) do
    validate(value, opts, %{})
  end

  @impl true
  def validate(value, opts, env)

  def validate(%Nothing{} = value, _opts, _env) do
    Either.right(value)
  end

  def validate(%Just{value: v}, opts, _env) do
    validate_value(v, opts)
  end

  def validate(value, opts, _env) do
    validate_value(value, opts)
  end

  defp validate_value(value, opts) do
    reference = Keyword.fetch!(opts, :value)
    ord = Keyword.get(opts, :ord, Ord.Protocol)

    Either.lift_predicate(
      value,
      fn v -> Ord.compare(v, reference, ord) in [:gt, :eq] end,
      fn v ->
        ValidationError.new(
          build_message(opts, v, "must be greater than or equal to #{inspect(reference)}")
        )
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
