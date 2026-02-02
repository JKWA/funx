defmodule Funx.Predicate.Contains do
  @moduledoc """
  Predicate that checks if a collection contains a specific element using an
  `Eq` comparator.

  Options

  - `:value` (required)
    The element to search for in the collection.

  - `:eq` (optional)
    An equality comparator. Defaults to `Funx.Eq.Protocol`.

  ## Examples

      use Funx.Predicate

      # Check if grants list contains :poison_resistance
      pred do
        check [:blessing, :grants], {Contains, value: :poison_resistance}
      end

      # Check if tags contain a specific tag
      pred do
        check :tags, {Contains, value: "featured"}
      end

      # With custom Eq comparator
      pred do
        check :items, {Contains, value: target_item, eq: Item.Eq}
      end
  """

  @behaviour Funx.Predicate.Dsl.Behaviour

  alias Funx.List

  @impl true
  def pred(opts) do
    element = Keyword.fetch!(opts, :value)
    eq = Keyword.get(opts, :eq, Funx.Eq.Protocol)

    fn collection ->
      is_list(collection) and List.elem?(collection, element, eq)
    end
  end
end
