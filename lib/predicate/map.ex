defmodule Funx.Predicate.Map do
  @moduledoc """
  Predicate that checks if a value is a map.

  Options

  None required.

  ## Examples

      use Funx.Predicate

      alias Funx.Predicate.Map

      # Check if user is a map
      pred do
        check :user, Map
      end

      # Combined with other predicates
      pred do
        check :config, Map
        check :config, Required
      end
  """

  @behaviour Funx.Predicate.Dsl.Behaviour

  @impl true
  def pred(_opts \\ []) do
    fn value -> is_map(value) end
  end
end
