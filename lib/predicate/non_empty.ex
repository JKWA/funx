defmodule Funx.Predicate.NonEmpty do
  @moduledoc """
  Predicate that checks if a value is a non-empty list.

  Options

  None required.

  ## Examples

      use Funx.Predicate

      alias Funx.Predicate.NonEmpty

      # Check if tags is a non-empty list
      pred do
        check :tags, NonEmpty
      end

      # Combined with other predicates
      pred do
        check :items, NonEmpty
        check :items, {MaxLength, max: 10}
      end
  """

  @behaviour Funx.Predicate.Dsl.Behaviour

  @impl true
  def pred(_opts \\ []) do
    fn value -> is_list(value) && value != [] end
  end
end
