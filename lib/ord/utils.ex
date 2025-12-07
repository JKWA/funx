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

  import Funx.Monoid.Utils, only: [m_append: 3, m_concat: 2]

  alias Funx.Optics.Lens
  alias Funx.Ord

  @doc """
  Transforms an ordering by applying a projection before comparison.

  The `projection` can take several forms:

    * a function `(a -> b)`
      The projection is applied directly.

    * a `Lens`
      The lens’s `get/2` function is used as the projection.

    * an atom
      Treated as a key and converted into a lens with `Lens.key/1`.

    * a list of keys
      Treated as a nested path and converted into a lens with `Lens.path/1`.

  The `ord` parameter may be an `Ord` module or a custom comparator map
  with `:lt?`, `:le?`, `:gt?`, and `:ge?` functions. The projection is applied
  to both inputs before invoking the underlying comparator.

  ## Examples

  Using a projection function:

      iex> ord = Funx.Ord.Utils.contramap(&String.length/1)
      iex> ord.lt?.("cat", "zebra")
      true
      iex> ord.gt?.("zebra", "cat")
      true

  Using a key (automatically lifted into a lens):

      iex> ord = Funx.Ord.Utils.contramap(:age)
      iex> ord.gt?.(%{age: 40}, %{age: 30})
      true
      iex> ord.lt?.(%{age: 30}, %{age: 40})
      true

  Using a path (nested access):

      iex> ord = Funx.Ord.Utils.contramap([:stats, :wins])
      iex> ord.lt?.(%{stats: %{wins: 2}}, %{stats: %{wins: 5}})
      true
      iex> ord.gt?.(%{stats: %{wins: 5}}, %{stats: %{wins: 2}})
      true

  Using a lens explicitly:

      iex> lens = Funx.Optics.Lens.key(:score)
      iex> ord = Funx.Ord.Utils.contramap(lens)
      iex> ord.gt?.(%{score: 10}, %{score: 3})
      true
      iex> ord.lt?.(%{score: 3}, %{score: 10})
      true
  """

  @spec contramap(
          (a -> b)
          | Lens.t()
          | atom
          | [term()],
          ord_t()
        ) :: ord_map()
        when a: any, b: any
  def contramap(projection, ord \\ Ord)

  # Lens
  def contramap(%Lens{} = lens, ord) do
    contramap(fn a -> Lens.view(a, lens) end, ord)
  end

  # Atom key → lens
  def contramap(key, ord) when is_atom(key) do
    lens = Lens.key(key)
    contramap(lens, ord)
  end

  # Path → lens
  def contramap(path, ord) when is_list(path) do
    lens = Lens.path(path)
    contramap(lens, ord)
  end

  # Function
  def contramap(f, ord) when is_function(f, 1) do
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
    m_append(%Funx.Monoid.Ord{}, a, b)
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
    m_concat(%Funx.Monoid.Ord{}, ord_list)
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
