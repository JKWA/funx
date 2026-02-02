defmodule Funx.Validator.Contains do
  @moduledoc """
  Validates that a collection contains a specific element using an `Eq`
  comparator.

  `Contains` enforces a membership constraint of the form:
  "collection must contain X".

  Membership is defined by an `Eq` instance, not by structural equality or
  Elixir's `in` operator.

  Options

  - `:value` (required)
    The element that must be present in the collection.

  - `:eq` (optional)
    An equality comparator. Defaults to `Funx.Eq.Protocol`.

  - `:message` (optional)
    A custom error message callback `(value -> String.t())`.

  Semantics

  - Succeeds if the collection is a list and contains the element under `Eq`.
  - Fails if the collection does not contain the element or is not a list.
  - `Nothing` values pass unchanged.
  - `Just` values are unwrapped before validation.
  """

  use Funx.Validator

  alias Funx.Predicate

  @impl Funx.Validator
  def valid?(value, opts, _env) do
    predicate = Predicate.Contains.pred(opts)
    predicate.(value)
  end

  @impl Funx.Validator
  def default_message(_value, opts) do
    element = Keyword.fetch!(opts, :value)
    "must contain #{inspect(element)}"
  end
end
