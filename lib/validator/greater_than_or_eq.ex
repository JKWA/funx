defmodule Funx.Validator.GreaterThanOrEqual do
  @moduledoc """
  Validates that a value is greater than or equal to a given reference value
  using an `Ord` comparator.

  Options

  - `:value` (required) - The reference value to compare against
  - `:ord` (optional) - An ordering comparator. Defaults to `Funx.Ord.Protocol`
  - `:message` (optional) - Custom error message callback `(value -> String.t())`

  Semantics

  - If the value compares as `:gt` or `:eq` relative to the reference, validation succeeds.
  - If the value compares as `:lt`, validation fails.
  - `Nothing` values pass unchanged.
  - `Just` values are unwrapped before comparison.
  """

  use Funx.Validator

  alias Funx.Ord

  @impl Funx.Validator
  def valid?(value, opts, _env) do
    reference = Keyword.fetch!(opts, :value)
    ord = Keyword.get(opts, :ord, Ord.Protocol)
    Ord.compare(value, reference, ord) in [:gt, :eq]
  end

  @impl Funx.Validator
  def default_message(_value, opts) do
    reference = Keyword.fetch!(opts, :value)
    "must be greater than or equal to #{inspect(reference)}"
  end
end
