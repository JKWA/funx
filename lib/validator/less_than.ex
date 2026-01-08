defmodule Funx.Validator.LessThan do
  @moduledoc """
  Validates that a value is strictly less than a given reference value
  using an `Ord` comparator.

  `LessThan` enforces an ordering constraint of the form:
  “value must be less than X”.

  Ordering is defined by an `Ord` instance.

  Options

  - `:value` (required)
    The reference value to compare against.

  - `:ord` (optional)
    An ordering comparator. Defaults to `Funx.Ord.Protocol`.

  - `:message` (optional)
    A custom error message callback `(value -> String.t())`.

  Semantics

  - If the value compares as `:lt` relative to the reference, validation succeeds.
  - If the value compares as `:eq` or `:gt`, validation fails.
  - `Nothing` values pass unchanged.
  - `Just` values are unwrapped before comparison.
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
      fn v -> Ord.compare(v, reference, ord) == :lt end,
      fn v ->
        ValidationError.new(build_message(opts, v, "must be less than #{inspect(reference)}"))
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
