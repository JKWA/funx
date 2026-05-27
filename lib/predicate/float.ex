defmodule Funx.Predicate.Float do
  @moduledoc """
  Predicate that checks if a value is a float.

  Options

  None required.

  ## Examples

      use Funx.Predicate

      alias Funx.Predicate.Float

      # Check if price is a float
      pred do
        check :price, Float
      end

      # Combined with other predicates
      pred do
        check :amount, Float
        check :amount, {GreaterThan, value: 0.0}
      end
  """

  @behaviour Funx.Predicate.Dsl.Behaviour

  @impl true
  def pred(_opts \\ []) do
    fn value -> is_float(value) end
  end
end
