defmodule Funx.Predicate.In do
  @moduledoc """
  Predicate that checks if a value is a member of a given collection using an
  `Eq` comparator.

  Options

  - `:values` (required)
    The list of allowed values to compare against.

  - `:eq` (optional)
    An equality comparator. Defaults to `Funx.Eq.Protocol`.

  ## Examples

      use Funx.Predicate

      # Check if status is one of allowed values
      pred do
        check :status, {In, values: [:active, :pending, :completed]}
      end

      # Check if struct type is in list
      pred do
        check :event, {In, values: [Click, Scroll, Submit]}
      end

      # With custom Eq comparator
      pred do
        check :item, {In, values: allowed_items, eq: Item.Eq}
      end
  """

  @behaviour Funx.Predicate.Dsl.Behaviour

  alias Funx.List

  @impl true
  def pred(opts) do
    values = Keyword.fetch!(opts, :values)
    eq = Keyword.get(opts, :eq, Funx.Eq.Protocol)
    module_values? = is_list(values) and Enum.all?(values, &is_atom/1)

    fn value ->
      case {value, module_values?} do
        {%{__struct__: mod}, true} ->
          mod in values

        _ ->
          List.elem?(values, value, eq)
      end
    end
  end
end
