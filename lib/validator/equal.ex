defmodule Funx.Validator.Equal do
  @moduledoc """
  Validates that a value is equal to a given expected value using an `Eq`
  comparator.

  `Equal` enforces an equality constraint of the form:
  "value must equal X".

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

  use Funx.Validator

  alias Funx.Eq

  @impl Funx.Validator
  def valid?(value, opts, _env) do
    expected = Keyword.fetch!(opts, :value)
    eq = Keyword.get(opts, :eq, Eq.Protocol)
    expected_is_module = is_atom(expected)

    case {value, expected_is_module} do
      {%{__struct__: mod}, true} ->
        mod == expected

      _ ->
        Eq.eq?(value, expected, eq)
    end
  end

  @impl Funx.Validator
  def default_message(_value, opts) do
    expected = Keyword.fetch!(opts, :value)
    "must equal #{inspect(expected)}"
  end
end
