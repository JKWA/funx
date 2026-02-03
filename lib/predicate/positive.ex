defmodule Funx.Predicate.Positive do
  @moduledoc """
  Predicate that checks if a number is strictly positive (> 0).

  Returns false for non-numbers.

  Options

  None required.

  ## Examples

      use Funx.Predicate

      # Check if amount is positive
      pred do
        check :amount, Positive
      end

      # Combined with integer check
      pred do
        check :count, IsInteger
        check :count, Positive
      end
  """

  @behaviour Funx.Predicate.Dsl.Behaviour

  @impl true
  def pred(_opts \\ []) do
    fn
      number when is_number(number) -> number > 0
      _non_number -> false
    end
  end
end
