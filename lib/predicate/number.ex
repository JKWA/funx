defmodule Funx.Predicate.Number do
  @moduledoc """
  Predicate that checks if a value is a number (integer or float).

  Options

  None required.

  ## Examples

      use Funx.Predicate

      alias Funx.Predicate.Number

      # Check if age is a number
      pred do
        check :age, Number
      end

      # Combined with other predicates
      pred do
        check :score, Number
        check :score, {GreaterThanOrEqual, value: 0}
      end
  """

  @behaviour Funx.Predicate.Dsl.Behaviour

  @impl true
  def pred(_opts \\ []) do
    fn value -> is_number(value) end
  end
end
