defmodule Funx.Ord.Utils do
  @moduledoc """
  Utility functions for working with the `Funx.Ord` protocol.
  These functions assume that types passed in either support Elixir's comparison operators
  or implement the `Funx.Ord` protocol.
  """

  @type ord_map() :: %{
          lt?: (any(), any() -> boolean()),
          le?: (any(), any() -> boolean()),
          gt?: (any(), any() -> boolean()),
          ge?: (any(), any() -> boolean())
        }

  @type ord_t() :: Funx.Ord.t() | ord_map()

  alias Funx.Monoid
  alias Funx.Ord

  @doc """
  Transforms an ordering by applying a function `f` to values before comparison.

  The `ord` parameter can be an `Ord` module or a custom comparator map with comparison functions (`:lt?`, `:le?`, `:gt?`, and `:ge?`).
  When an `Ord` module is provided, it wraps the module’s functions to apply `f` to each value before invoking the comparison.
  If a custom comparator map is provided, it wraps the functions in the map to apply `f` to each value.

  ## Examples

      iex> ord = Funx.Ord.Utils.contramap(&String.length/1, Funx.Ord.Any)
      iex> ord.lt?.("cat", "zebra")
      true
  """
  @spec contramap((a -> b), ord_t()) :: ord_map()
        when a: any, b: any
  def contramap(f, ord \\ Ord) do
    ord = to_ord_map(ord)

    %{
      lt?: fn a, b -> ord.lt?.(f.(a), f.(b)) end,
      le?: fn a, b -> ord.le?.(f.(a), f.(b)) end,
      gt?: fn a, b -> ord.gt?.(f.(a), f.(b)) end,
      ge?: fn a, b -> ord.ge?.(f.(a), f.(b)) end
    }
  end

  @doc """
  Returns the maximum of two values, with an optional custom `Ord`.

  ## Examples

      iex> Funx.Ord.Utils.max(3, 5)
      5

      iex> ord = Funx.Ord.Utils.contramap(&String.length/1, Funx.Ord.Any)
      iex> Funx.Ord.Utils.max("cat", "zebra", ord)
      "zebra"
  """
  @spec max(a, a, ord_t()) :: a
        when a: any
  def max(a, b, ord \\ Ord) do
    case compare(a, b, ord) do
      :lt -> b
      _ -> a
    end
  end

  @doc """
  Returns the minimum of two values, with an optional custom `Ord`.

  ## Examples

      iex> Funx.Ord.Utils.min(10, 7)
      7

      iex> ord = Funx.Ord.Utils.contramap(&String.length/1, Funx.Ord.Any)
      iex> Funx.Ord.Utils.min("apple", "kiwi", ord)
      "kiwi"
  """
  @spec min(a, a, ord_t()) :: a
        when a: any
  def min(a, b, ord \\ Ord) do
    case compare(a, b, ord) do
      :gt -> b
      _ -> a
    end
  end

  @doc """
  Clamps a value between `min` and `max`, with an optional custom `Ord`.

  ## Examples

      iex> Funx.Ord.Utils.clamp(5, 1, 10)
      5

      iex> Funx.Ord.Utils.clamp(0, 1, 10)
      1

      iex> Funx.Ord.Utils.clamp(15, 1, 10)
      10
  """
  @spec clamp(a, a, a, ord_t()) :: a
        when a: any
  def clamp(value, min, max, ord \\ Ord) do
    value
    |> max(min, ord)
    |> min(max, ord)
  end

  @doc """
  Checks if `value` is between `min` and `max`, inclusive, with an optional custom `Ord`.

  ## Examples

      iex> Funx.Ord.Utils.between(5, 1, 10)
      true

      iex> Funx.Ord.Utils.between(0, 1, 10)
      false

      iex> Funx.Ord.Utils.between(11, 1, 10)
      false
  """
  @spec between(a, a, a, ord_t()) :: boolean()
        when a: any
  def between(value, min, max, ord \\ Ord) do
    compare(value, min, ord) != :lt && compare(value, max, ord) != :gt
  end

  @doc """
  Compares two values and returns `:lt`, `:eq`, or `:gt`, with an optional custom `Ord`.

  ## Examples

      iex> Funx.Ord.Utils.compare(3, 5)
      :lt

      iex> Funx.Ord.Utils.compare(7, 7)
      :eq

      iex> Funx.Ord.Utils.compare(9, 4)
      :gt
  """
  @spec compare(a, a, ord_t()) :: :lt | :eq | :gt
        when a: any
  def compare(a, b, ord \\ Ord) do
    ord = to_ord_map(ord)

    cond do
      ord.lt?.(a, b) -> :lt
      ord.gt?.(a, b) -> :gt
      true -> :eq
    end
  end

  @doc """
  Reverses the ordering logic.

  ## Examples

      iex> ord = Funx.Ord.Utils.reverse(Funx.Ord.Any)
      iex> ord.lt?.(10, 5)
      true
  """
  @spec reverse(ord_t()) :: ord_map()
  def reverse(ord \\ Ord) do
    ord = to_ord_map(ord)

    %{
      lt?: ord.gt?,
      le?: ord.ge?,
      gt?: ord.lt?,
      ge?: ord.le?
    }
  end

  @doc """
  Creates a comparator function from the given `Ord` module, returning `true`
  if `a` is less than or equal to `b` according to the module’s ordering.

  Useful for sorting with `Enum.sort/2` or similar functions.

  ## Examples

      iex> comparator = Funx.Ord.Utils.comparator(Funx.Ord.Any)
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

      iex> eq = Funx.Ord.Utils.to_eq(Funx.Ord.Any)
      iex> eq.eq?.(5, 5)
      true
  """
  @spec to_eq(ord_t()) :: Funx.Eq.Utils.eq_map()
  def to_eq(ord \\ Ord) do
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

      iex> ord1 = Funx.Ord.Utils.contramap(& &1.age, Funx.Ord.Any)
      iex> ord2 = Funx.Ord.Utils.contramap(& &1.name, Funx.Ord.Any)
      iex> combined = Funx.Ord.Utils.append(ord1, ord2)
      iex> combined.lt?.(%{age: 30, name: "Alice"}, %{age: 30, name: "Bob"})
      true
  """
  @spec append(Funx.Monoid.Ord.t(), Funx.Monoid.Ord.t()) :: Funx.Monoid.Ord.t()
  def append(a, b) do
    Monoid.Utils.append(%Funx.Monoid.Ord{}, a, b)
  end

  @doc """
  Concatenates a list of `Ord` instances into a single composite comparator.

  This function reduces a list of `Ord` comparators into a single `Ord`,
  applying them in sequence until an order is determined.

  ## Examples

      iex> ord_list = [
      ...>   Funx.Ord.Utils.contramap(& &1.age, Funx.Ord.Any),
      ...>   Funx.Ord.Utils.contramap(& &1.name, Funx.Ord.Any)
      ...> ]
      iex> combined = Funx.Ord.Utils.concat(ord_list)
      iex> combined.gt?.(%{age: 25, name: "Charlie"}, %{age: 25, name: "Bob"})
      true
  """
  @spec concat([Funx.Monoid.Ord.t()]) :: Funx.Monoid.Ord.t()
  def concat(ord_list) when is_list(ord_list) do
    Monoid.Utils.concat(%Funx.Monoid.Ord{}, ord_list)
  end

  def to_ord_map(%{lt?: lt_fun, le?: le_fun, gt?: gt_fun, ge?: ge_fun} = ord_map)
      when is_function(lt_fun, 2) and
             is_function(le_fun, 2) and
             is_function(gt_fun, 2) and
             is_function(ge_fun, 2),
      do: ord_map

  def to_ord_map(module) when is_atom(module) do
    %{
      lt?: &module.lt?/2,
      le?: &module.le?/2,
      gt?: &module.gt?/2,
      ge?: &module.ge?/2
    }
  end
end
