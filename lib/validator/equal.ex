defmodule Funx.Validator.Equal do
  @moduledoc """
  Validates that a value is equal to a given expected value using an `Eq`
  comparator.

  `Equal` enforces an equality constraint of the form:
  “value must equal X”.

  Equality is defined by an `Eq` instance, not by structural equality.

  Options

  - `:value` (required)
    The expected value to compare against.

  - `:eq` (optional)
    An equality comparator. Defaults to `Funx.Eq.Protocol`.

  - `:message` (optional)
    A custom error message callback `(value -> String.t())` used to override the
    default error message on failure.

  Semantics

  - If the value equals the expected value under the given `Eq`, validation
    succeeds.
  - If the expected value is a module and the value is a struct, validation
    succeeds when `value.__struct__ == expected`.
  - If the value does not equal the expected value, validation fails.
  - `Nothing` values are preserved and treated as not applicable.
  - `Just` values are unwrapped before comparison.
  """

  @behaviour Funx.Validate.Behaviour

  alias Funx.Eq
  alias Funx.Errors.ValidationError
  alias Funx.Monad.Either
  alias Funx.Monad.Maybe.{Just, Nothing}

  def validate(value) do
    validate(value, [])
  end

  def validate(value, opts) when is_list(opts) do
    validate(value, opts, %{})
  end

  @impl true
  def validate(value, opts, _env)

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
    expected = Keyword.fetch!(opts, :value)
    eq = Keyword.get(opts, :eq, Eq.Protocol)
    expected_is_module = is_atom(expected)

    Either.lift_predicate(
      value,
      fn v ->
        case {v, expected_is_module} do
          {%{__struct__: mod}, true} ->
            mod == expected

          _ ->
            Eq.eq?(v, expected, eq)
        end
      end,
      fn v ->
        ValidationError.new(build_message(opts, v, "must be equal to #{inspect(expected)}"))
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
