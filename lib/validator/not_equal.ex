defmodule Funx.Validator.NotEqual do
  @moduledoc """
  Validates that a value is not equal to a given reference value using an `Eq`
  comparator.

  `NotEqual` enforces an inequality constraint of the form:
  "value must not equal X".

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

  use Funx.Validator

  alias Funx.Predicate

  @impl Funx.Validator
  def valid?(value, opts, _env) do
    predicate = Predicate.NotEq.pred(opts)
    predicate.(value)
  end

  @impl Funx.Validator
  def default_message(_value, opts) do
    reference = Keyword.fetch!(opts, :value)
    "must not be equal to #{inspect(reference)}"
  end
end
