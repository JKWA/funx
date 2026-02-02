defmodule Funx.Predicate.LessThan do
  @moduledoc """
  Predicate that checks if a value is strictly less than a reference value
  using an `Ord` comparator.

  Options

  - `:value` (required)
    The reference value to compare against.

  - `:ord` (optional)
    An ordering comparator. Defaults to `Funx.Ord.Protocol`.

  ## Examples

      use Funx.Predicate

      # Check if score is less than 100
      pred do
        check :score, {LessThan, value: 100}
      end

      # With custom Ord comparator
      pred do
        check :date, {LessThan, value: cutoff_date, ord: Date.Ord}
      end
  """

  @behaviour Funx.Predicate.Dsl.Behaviour

  alias Funx.Ord

  @impl true
  def pred(opts) do
    reference = Keyword.fetch!(opts, :value)
    ord = Keyword.get(opts, :ord, Ord.Protocol)

    fn value ->
      Ord.compare(value, reference, ord) == :lt
    end
  end
end
