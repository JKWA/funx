defmodule Funx.Predicate.Negative do
  @moduledoc """
  Predicate that checks if a number is strictly negative (< 0).

  Returns false for non-numbers.

  Options

  None required.

  ## Examples

      use Funx.Predicate

      # Check if balance is negative
      pred do
        check :balance, Negative
      end

      # Combined with other predicates
      pred do
        check :adjustment, IsInteger
        check :adjustment, Negative
      end
  """

  @behaviour Funx.Predicate.Dsl.Behaviour

  @impl true
  def pred(_opts \\ []) do
    fn
      number when is_number(number) -> number < 0
      _non_number -> false
    end
  end
end
