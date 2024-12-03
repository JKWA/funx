defmodule Monex.Eq.Utils do
  @moduledoc """
  Utility functions for working with the `Monex.Eq` protocol.
  These functions assume that types passed in either support Elixir's equality operator
  or implement the `Monex.Eq` protocol.
  """

  alias Monex.Eq

  @doc """
  Transforms an equality check by applying a function `f` to values before comparison.

  The `eq` parameter can be an `Eq` module or a custom comparator map with an `:eq?` function.
  If an `Eq` module is provided, it wraps the module’s function to apply `f` to each value before invoking the equality check.
  If a custom comparator map is provided, it wraps the function in the map to apply `f` to each value.
  """
  def contramap(f, module) when is_atom(module) do
    %{
      eq?: fn a, b -> module.eq?(f.(a), f.(b)) end,
      not_eq?: fn a, b -> module.not_eq?(f.(a), f.(b)) end
    }
  end

  def contramap(f, %{} = custom_map) do
    %{
      eq?: fn a, b -> custom_map[:eq?].(f.(a), f.(b)) end,
      not_eq?: fn a, b -> custom_map[:not_eq?].(f.(a), f.(b)) end
    }
  end

  def contramap(f), do: contramap(f, Eq)

  @doc """
  Checks equality of values by applying a projection function, using a specified or default `Eq`.

  The `eq` parameter can be an `Eq` module or a custom comparator map with an `:eq?` function.
  """
  def eq_by?(f, a, b, module) when is_atom(module) do
    module.eq?(f.(a), f.(b))
  end

  def eq_by?(f, a, b, %{} = custom_map) do
    custom_map[:eq?].(f.(a), f.(b))
  end

  def eq_by?(f, a, b), do: eq_by?(f, a, b, Eq)

  @doc """
  Returns `true` if values are not equal, using a specified or default `Eq`.

  The `eq` parameter can be an `Eq` module or a custom comparator map with an `:eq?` function.
  """
  def not_eq?(a, b, eq \\ Eq) do
    case eq do
      module when is_atom(module) -> not module.eq?(a, b)
      %{} = custom_map -> not custom_map[:eq?].(a, b)
    end
  end

  @doc """
  Returns true if two values are equal, using a specified or default `Eq`.
  """
  def eq?(a, b, module) when is_atom(module) do
    module.eq?(a, b)
  end

  def eq?(a, b, %{} = custom_map) do
    custom_map[:eq?].(a, b)
  end

  def eq?(a, b), do: eq?(a, b, Eq)

  @doc """
  Converts an `Eq` comparator into a single-argument predicate function for use in `Enum` functions.

  The resulting predicate takes a single element and returns `true` if it matches the `target`
  based on the specified `Eq`. If no custom `Eq` is provided, it defaults to `Monex.Eq`.
  """
  @spec to_predicate(any(), module() | map()) :: (any() -> boolean())
  def to_predicate(target, eq \\ Eq) do
    fn elem ->
      case eq do
        module when is_atom(module) -> module.eq?(elem, target)
        %{} = custom_map -> custom_map[:eq?].(elem, target)
      end
    end
  end
end
