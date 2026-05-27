defmodule Funx.Predicate.Boolean do
  @moduledoc """
  Predicate that checks if a value is a boolean (true or false).

  Options

  None required.

  ## Examples

      use Funx.Predicate

      alias Funx.Predicate.Boolean

      # Check if active is a boolean
      pred do
        check :active, Boolean
      end

      # Combined with other predicates
      pred do
        check :enabled, Boolean
        check :enabled, IsTrue
      end
  """

  @behaviour Funx.Predicate.Dsl.Behaviour

  @impl true
  def pred(_opts \\ []) do
    fn value -> is_boolean(value) end
  end
end
