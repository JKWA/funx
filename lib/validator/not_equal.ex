defmodule Funx.Validator.NotEqual do
  @moduledoc """
  Validates that a value is not equal to a given reference value using an `Eq`
  comparator.

  `NotEqual` enforces an inequality constraint of the form:
  “value must not equal X”.

  Equality is defined by an `Eq` instance, not by structural equality.

  Options

  - `:value` (required)
    The reference value to compare against.

  - `:eq` (optional)
    An equality comparator. Defaults to `Funx.Eq.Protocol`.

  - `:message` (optional)
    A custom error message callback `(value -> String.t())` used to override the
    default error message on failure.

  Semantics

  - If the value does not equal the reference value under the given `Eq`,
    validation succeeds.
  - If the value equals the reference value, validation fails.
  - `Nothing` values are preserved and treated as not applicable.
  - `Just` values are unwrapped before comparison.
  """

  @behaviour Funx.Validation.Behaviour

  alias Funx.Eq
  alias Funx.Errors.ValidationError
  alias Funx.Monad.Either
  alias Funx.Monad.Maybe.{Just, Nothing}

  # Convenience overload for default opts (raises on missing required options)
  def validate(value) do
    validate(value, [])
  end

  # Convenience overload
  def validate(value, opts) when is_list(opts) do
    validate(value, opts, %{})
  end

  @impl true
  def validate(value, opts, env)

  def validate(%Nothing{} = value, _opts, _env) do
    Either.right(value)
  end

  def validate(%Just{value: value}, opts, _env) do
    validate_value(value, opts)
  end

  def validate(value, opts, _env) do
    validate_value(value, opts)
  end

  defp validate_value(value, opts) do
    reference = Keyword.fetch!(opts, :value)
    eq = Keyword.get(opts, :eq, Eq.Protocol)

    Either.lift_predicate(
      value,
      fn v -> Eq.not_eq?(v, reference, eq) end,
      fn v ->
        ValidationError.new(build_message(opts, v, "must not be equal to #{inspect(reference)}"))
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
