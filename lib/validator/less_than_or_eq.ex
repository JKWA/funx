defmodule Funx.Validator.LessThanOrEqual do
  @moduledoc """
  Validates that a value is less than or equal to a given reference value
  using an `Ord` comparator.

  Options

  - `:value` (required) - The reference value to compare against
  - `:ord` (optional) - An ordering comparator. Defaults to `Funx.Ord.Protocol`
  - `:message` (optional) - Custom error message callback `(value -> String.t())`

  Semantics

  - If the value compares as `:lt` or `:eq` relative to the reference, validation succeeds.
  - If the value compares as `:gt`, validation fails.
  - `Nothing` values pass unchanged.
  - `Just` values are unwrapped before comparison.
  """

  use Funx.Validator

  alias Funx.Predicate

  @impl Funx.Validator
  def valid?(value, opts, _env) do
    predicate = Predicate.LessThanOrEqual.pred(opts)
    predicate.(value)
  end

  @impl Funx.Validator
  def default_message(_value, opts) do
    reference = Keyword.fetch!(opts, :value)
    "must be less than or equal to #{inspect(reference)}"
  end
end
