defmodule Funx.Predicate.List do
  @moduledoc """
  Predicate that checks if a value is a list.

  Options

  None required.

  ## Examples

      use Funx.Predicate

      alias Funx.Predicate.List

      # Check if tags is a list
      pred do
        check :tags, List
      end

      # Combined with other predicates
      pred do
        check :items, List
        check :items, {MinLength, min: 1}
      end
  """

  @behaviour Funx.Predicate.Dsl.Behaviour

  @impl true
  def pred(_opts \\ []) do
    fn value -> is_list(value) end
  end
end
