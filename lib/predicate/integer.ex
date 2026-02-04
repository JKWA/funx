defmodule Funx.Predicate.Integer do
  @moduledoc """
  Predicate that checks if a value is an integer.

  Options

  None required.

  ## Examples

      use Funx.Predicate

      alias Funx.Predicate.Integer

      # Check if count is an integer
      pred do
        check :count, Integer
      end

      # Combined with other predicates
      pred do
        check :quantity, Integer
        check :quantity, {GreaterThan, value: 0}
      end
  """

  @behaviour Funx.Predicate.Dsl.Behaviour

  @impl true
  def pred(_opts \\ []) do
    fn value -> is_integer(value) end
  end
end
