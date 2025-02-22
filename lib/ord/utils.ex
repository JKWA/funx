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
  @spec contramap((any() -> any()), module() | map()) :: %{
          lt?: (any(), any() -> boolean()),
          le?: (any(), any() -> boolean()),
          gt?: (any(), any() -> boolean()),
          ge?: (any(), any() -> boolean())
        }
  def contramap(f, ord) when is_atom(ord) do
    %{
      lt?: fn a, b -> ord.lt?(f.(a), f.(b)) end,
      le?: fn a, b -> ord.le?(f.(a), f.(b)) end,
      gt?: fn a, b -> ord.gt?(f.(a), f.(b)) end,
      ge?: fn a, b -> ord.ge?(f.(a), f.(b)) end
    }
  end

  def contramap(f, ord) when is_map(ord) do
    %{
      lt?: fn a, b -> ord[:lt?].(f.(a), f.(b)) end,
      le?: fn a, b -> ord[:le?].(f.(a), f.(b)) end,
      gt?: fn a, b -> ord[:gt?].(f.(a), f.(b)) end,
      ge?: fn a, b -> ord[:ge?].(f.(a), f.(b)) end
    }
  end

  def contramap(f), do: contramap(f, Ord)

  @doc """
  Returns the maximum of two values, with an optional custom `Ord`.

  ## Examples

      iex> Monex.Ord.Utils.max(3, 5)
      5

      iex> ord = Monex.Ord.Utils.contramap(&String.length/1, Monex.Ord.Any)
      iex> Monex.Ord.Utils.max("cat", "zebra", ord)
      "zebra"
  """
  @spec max(any(), any()) :: any()
  def max(a, b, ord \\ Ord) do
    if (is_atom(ord) && ord.ge?(a, b)) || (is_map(ord) && ord[:ge?].(a, b)), do: a, else: b
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
  @spec min(any(), any()) :: any()
  def min(a, b, ord \\ Ord) do
    if (is_atom(ord) && ord.le?(a, b)) || (is_map(ord) && ord[:le?].(a, b)), do: a, else: b
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
  @spec clamp(any(), any(), any(), module() | map()) :: any()
  def clamp(value, min, max, ord \\ Ord) do
    lt? = if is_atom(ord), do: &ord.lt?/2, else: ord[:lt?]
    gt? = if is_atom(ord), do: &ord.gt?/2, else: ord[:gt?]

    cond do
      lt?.(value, min) -> min
      gt?.(value, max) -> max
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
  @spec between(any(), any(), any(), module() | map()) :: boolean()
  def between(value, min, max, ord \\ Ord) do
    (is_atom(ord) && ord.ge?(value, min) && ord.le?(value, max)) ||
      (is_map(ord) && ord[:ge?].(value, min) && ord[:le?].(value, max))
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
  @spec compare(any(), any(), module() | map()) :: :lt | :eq | :gt
  def compare(a, b, ord \\ Ord) do
    lt? = if is_atom(ord), do: &ord.lt?/2, else: ord[:lt?]
    gt? = if is_atom(ord), do: &ord.gt?/2, else: ord[:gt?]

    cond do
      lt?.(a, b) -> :lt
      gt?.(a, b) -> :gt
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
  @spec reverse(module() | ord_map()) :: ord_map()
  def reverse(ord \\ Ord)

  def reverse(ord) when is_atom(ord) do
    %{
      lt?: fn a, b -> ord.gt?(a, b) end,
      le?: fn a, b -> ord.ge?(a, b) end,
      gt?: fn a, b -> ord.lt?(a, b) end,
      ge?: fn a, b -> ord.le?(a, b) end
    }
  end

  def reverse(%{lt?: lt?, le?: le?, gt?: gt?, ge?: ge?}) do
    %{
      lt?: gt?,
      le?: ge?,
      gt?: lt?,
      ge?: le?
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
  @spec comparator(module() | map()) :: (any(), any() -> boolean())
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
  @spec to_eq(Monex.Ord.t()) :: Monex.Eq.t()
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
end
