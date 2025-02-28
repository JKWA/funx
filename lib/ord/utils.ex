defmodule Monex.Ord.Utils do
  @moduledoc """
  Utility functions for working with the `Monex.Ord` protocol.
  These functions assume that types passed in either support Elixir's comparison operators
  or implement the `Monex.Ord` protocol.
  """

  @type ord_map() :: %{
          lt?: (any(), any() -> boolean()),
          le?: (any(), any() -> boolean()),
          gt?: (any(), any() -> boolean()),
          ge?: (any(), any() -> boolean())
        }

  @type ord_t() :: Monex.Ord.t() | ord_map()

  alias Monex.Monoid
  alias Monex.Ord

  @doc """
  Transforms an ordering by applying a function `f` to values before comparison.

  The `ord` parameter can be an `Ord` module or a custom comparator map with comparison functions (`:lt?`, `:le?`, `:gt?`, and `:ge?`).
  When an `Ord` module is provided, it wraps the module’s functions to apply `f` to each value before invoking the comparison.
  If a custom comparator map is provided, it wraps the functions in the map to apply `f` to each value.

  ## Examples

      iex> ord = Monex.Ord.Utils.contramap(&String.length/1, Monex.Ord.Any)
      iex> ord[:lt?].("cat", "zebra")
      true
  """
  @spec contramap((a -> b), ord_t()) :: ord_map()
        when a: any, b: any
  def contramap(f, ord \\ Ord) do
    ord = to_ord_map(ord)

    %{
      lt?: fn a, b -> ord[:lt?].(f.(a), f.(b)) end,
      le?: fn a, b -> ord[:le?].(f.(a), f.(b)) end,
      gt?: fn a, b -> ord[:gt?].(f.(a), f.(b)) end,
      ge?: fn a, b -> ord[:ge?].(f.(a), f.(b)) end
    }
  end

  @doc """
  Returns the maximum of two values, with an optional custom `Ord`.

  ## Examples

      iex> Monex.Ord.Utils.max(3, 5)
      5

      iex> ord = Monex.Ord.Utils.contramap(&String.length/1, Monex.Ord.Any)
      iex> Monex.Ord.Utils.max("cat", "zebra", ord)
      "zebra"
  """
  @spec max(a, a, ord_t()) :: a
        when a: any
  def max(a, b, ord \\ Ord) do
    ord = to_ord_map(ord)

    if ord[:ge?].(a, b), do: a, else: b
  end

  @doc """
  Returns the minimum of two values, with an optional custom `Ord`.

  ## Examples

      iex> Monex.Ord.Utils.min(10, 7)
      7

      iex> ord = Monex.Ord.Utils.contramap(&String.length/1, Monex.Ord.Any)
      iex> Monex.Ord.Utils.min("apple", "kiwi", ord)
      "kiwi"
  """
  @spec min(a, a, ord_t()) :: a
        when a: any
  def min(a, b, ord \\ Ord) do
    ord = to_ord_map(ord)

    if ord[:le?].(a, b), do: a, else: b
  end

  @doc """
  Clamps a value between `min` and `max`, with an optional custom `Ord`.

  ## Examples

      iex> Monex.Ord.Utils.clamp(5, 1, 10)
      5

      iex> Monex.Ord.Utils.clamp(0, 1, 10)
      1

      iex> Monex.Ord.Utils.clamp(15, 1, 10)
      10
  """
  @spec clamp(a, a, a, ord_t()) :: a
        when a: any
  def clamp(value, min, max, ord \\ Ord) do
    ord = to_ord_map(ord)

    cond do
      ord[:lt?].(value, min) -> min
      ord[:gt?].(value, max) -> max
      true -> value
    end
  end

  @doc """
  Checks if `value` is between `min` and `max`, inclusive, with an optional custom `Ord`.

  ## Examples

      iex> Monex.Ord.Utils.between(5, 1, 10)
      true

      iex> Monex.Ord.Utils.between(0, 1, 10)
      false

      iex> Monex.Ord.Utils.between(11, 1, 10)
      false
  """
  @spec between(a, a, a, ord_t()) :: boolean()
        when a: any
  def between(value, min, max, ord \\ Ord) do
    ord = to_ord_map(ord)

    ord[:ge?].(value, min) && ord[:le?].(value, max)
  end

  @doc """
  Compares two values and returns `:lt`, `:eq`, or `:gt`, with an optional custom `Ord`.

  ## Examples

      iex> Monex.Ord.Utils.compare(3, 5)
      :lt

      iex> Monex.Ord.Utils.compare(7, 7)
      :eq

      iex> Monex.Ord.Utils.compare(9, 4)
      :gt
  """
  @spec compare(a, a, ord_t()) :: :lt | :eq | :gt
        when a: any
  def compare(a, b, ord \\ Ord) do
    ord = to_ord_map(ord)

    cond do
      ord[:lt?].(a, b) -> :lt
      ord[:gt?].(a, b) -> :gt
      true -> :eq
    end
  end

  @doc """
  Reverses the ordering logic.

  ## Examples

      iex> ord = Monex.Ord.Utils.reverse(Monex.Ord.Any)
      iex> ord[:lt?].(10, 5)
      true
  """
  @spec reverse(ord_t()) :: ord_map()
  def reverse(ord \\ Ord) do
    ord = to_ord_map(ord)

    %{
      lt?: ord[:gt?],
      le?: ord[:ge?],
      gt?: ord[:lt?],
      ge?: ord[:le?]
    }
  end

  @doc """
  Creates a comparator function from the given `Ord` module, returning `true`
  if `a` is less than or equal to `b` according to the module’s ordering.

  Useful for sorting with `Enum.sort/2` or similar functions.

  ## Examples

      iex> comparator = Monex.Ord.Utils.comparator(Monex.Ord.Any)
      iex> Enum.sort([3, 1, 2], comparator)
      [1, 2, 3]
  """
  @spec comparator(ord_t()) :: (any(), any() -> boolean())
  def comparator(ord_module) do
    fn a, b -> compare(a, b, ord_module) != :gt end
  end

  @doc """
  Converts an `Ord` instance into an equality comparator.

  This function creates a map containing two functions:
    - `eq?/2`: Returns `true` if `a` and `b` are considered equal by the given `Ord`.
    - `not_eq?/2`: Returns `true` if `a` and `b` are not considered equal by the given `Ord`.

  ## Examples

      iex> eq = Monex.Ord.Utils.to_eq(Monex.Ord.Any)
      iex> eq[:eq?].(5, 5)
      true
  """
  @spec to_eq(ord_t()) :: Monex.Eq.Utils.eq_map()
  def to_eq(ord \\ Ord) do
    ord = to_ord_map(ord)

    %{
      eq?: fn a, b -> compare(a, b, ord) == :eq end,
      not_eq?: fn a, b -> compare(a, b, ord) != :eq end
    }
  end

  @doc """
  Appends two `Ord` instances, combining their comparison logic.

  If the first `Ord` comparator determines an order, that result is used.
  If not, the second comparator is used as a fallback.

  ## Examples

      iex> ord1 = Monex.Ord.Utils.contramap(& &1.age, Monex.Ord.Any)
      iex> ord2 = Monex.Ord.Utils.contramap(& &1.name, Monex.Ord.Any)
      iex> combined = Monex.Ord.Utils.append(ord1, ord2)
      iex> combined[:lt?].(%{age: 30, name: "Alice"}, %{age: 30, name: "Bob"})
      true
  """
  @spec append(Monex.Monoid.Ord.t(), Monex.Monoid.Ord.t()) :: Monex.Monoid.Ord.t()
  def append(a, b) do
    Monoid.Utils.append(%Monex.Monoid.Ord{}, a, b)
  end

  @doc """
  Concatenates a list of `Ord` instances into a single composite comparator.

  This function reduces a list of `Ord` comparators into a single `Ord`,
  applying them in sequence until an order is determined.

  ## Examples

      iex> ord_list = [
      ...>   Monex.Ord.Utils.contramap(& &1.age, Monex.Ord.Any),
      ...>   Monex.Ord.Utils.contramap(& &1.name, Monex.Ord.Any)
      ...> ]
      iex> combined = Monex.Ord.Utils.concat(ord_list)
      iex> combined[:gt?].(%{age: 25, name: "Charlie"}, %{age: 25, name: "Bob"})
      true
  """
  @spec concat([Monex.Monoid.Ord.t()]) :: Monex.Monoid.Ord.t()
  def concat(ord_list) when is_list(ord_list) do
    Monoid.Utils.concat(%Monex.Monoid.Ord{}, ord_list)
  end

  defp to_ord_map(%{lt?: lt_fun, le?: le_fun, gt?: gt_fun, ge?: ge_fun} = ord_map)
       when is_function(lt_fun, 2) and
              is_function(le_fun, 2) and
              is_function(gt_fun, 2) and
              is_function(ge_fun, 2),
       do: ord_map

  defp to_ord_map(module) when is_atom(module) do
    %{
      lt?: &module.lt?/2,
      le?: &module.le?/2,
      gt?: &module.gt?/2,
      ge?: &module.ge?/2
    }
  end
end
