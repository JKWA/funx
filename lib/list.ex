defmodule Funx.List do
  @moduledoc """
  [![Run in Livebook](https://livebook.dev/badge/v1/black.svg)](https://livebook.dev/run?url=https%3A%2F%2Fgithub.com%2FJKWA%2Ffunx%2Fblob%2Fmain%2Flivebooks%2Flist%2Flist.livemd)

  The `Funx.List` module provides utility functions for working with lists while respecting `Eq` and `Ord` instances. This allows for set-like operations, uniqueness constraints, and sorted collections that align with functional programming principles.

  ## Features

  - **Equality-based Operations**: Use `Eq` instances to compare elements for uniqueness, intersection, and difference.
  - **Ordering Functions**: Leverage `Ord` instances to sort and enforce uniqueness in sorted collections.
  - **Set Operations**: Perform union, intersection, difference, and symmetric difference while preserving custom equality logic.
  - **Subset & Superset Checks**: Verify relationships between lists in terms of inclusion.
  - **Functional Constructs**: Implements `Monad` and `Foldable` protocols for lists, supporting mapping, binding, and folding.

  ### Usage Overview

  1. **Deduplicate**: Use `uniq/1` to remove duplicates based on `Eq`.
  2. **Combine**: Use `union/2` to merge lists without duplicates.
  3. **Filter**: Use `intersection/2` or `difference/2` for set operations.
  4. **Sort**: Use `sort/2` or `strict_sort/2` with `Ord` instances.
  5. **Check Membership**: Use `subset?/2` or `superset?/2` to verify inclusion relationships.
  6. **Find Extremes**: Use `min/2`, `max/2` for safe min/max, or `min!/2`, `max!/2` to raise on empty.

  ### Equality-Based Operations

  - `uniq/1`: Removes duplicates using `Eq`.
  - `union/2`: Merges lists while preserving uniqueness.
  - `intersection/2`: Returns elements common to both lists.
  - `difference/2`: Returns elements from the first list not in the second.
  - `symmetric_difference/2`: Returns elements unique to each list.

  ### Ordering Functions

  - `sort/2`: Sorts a list using `Ord`.
  - `strict_sort/2`: Sorts while ensuring uniqueness.

  ### Set Operations

  - `subset?/2`: Checks if one list is a subset of another.
  - `superset?/2`: Checks if one list is a superset of another.

  ### Min/Max Operations

  - `min/2`: Returns the minimum element wrapped in `Maybe`.
  - `min!/2`: Returns the minimum element, raises on empty list.
  - `max/2`: Returns the maximum element wrapped in `Maybe`.
  - `max!/2`: Returns the maximum element, raises on empty list.

  ### Monad Implementation

  - `map/2`: Transforms list elements.
  - `bind/2`: Applies a function returning lists and flattens the result.
  - `ap/2`: Applies functions in a list to elements in another list.

  ### Foldable Implementation

  - `fold_l/3`: Performs left-associative folding.
  - `fold_r/3`: Performs right-associative folding.
  """
  import Kernel, except: [max: 2, min: 2]
  import Funx.Foldable, only: [fold_l: 3]
  import Funx.Filterable, only: [filter: 2]
  import Funx.Monoid.Utils, only: [m_concat: 2]

  alias Funx.Monad.Maybe
  alias Funx.Monoid.ListConcat

  @doc """
  Removes duplicate elements from a list based on the given equality module.

  ## Examples

      iex> Funx.List.uniq([1, 2, 2, 3, 1, 4, 5])
      [1, 2, 3, 4, 5]
  """
  @spec uniq([term()], Funx.Eq.eq_t()) :: [term()]
  def uniq(list, eq \\ Funx.Eq.Protocol) when is_list(list) do
    list
    |> fold_l([], fn item, acc ->
      if Enum.any?(acc, &Funx.Eq.eq?(item, &1, eq)), do: acc, else: [item | acc]
    end)
    |> :lists.reverse()
  end

  @doc """
  Returns the union of two lists, removing duplicates.

  ## Examples

      iex> Funx.List.union([1, 2, 3], [3, 4, 5])
      [1, 2, 3, 4, 5]
  """
  @spec union([term()], [term()], Funx.Eq.eq_t()) :: [term()]
  def union(list1, list2, eq \\ Funx.Eq.Protocol) when is_list(list1) and is_list(list2) do
    (list1 ++ list2) |> uniq(eq)
  end

  @doc """
  Returns the intersection of two lists.

  ## Examples

      iex> Funx.List.intersection([1, 2, 3, 4], [3, 4, 5])
      [3, 4]
  """
  @spec intersection([term()], [term()], Funx.Eq.eq_t()) :: [term()]
  def intersection(list1, list2, eq \\ Funx.Eq.Protocol) when is_list(list1) and is_list(list2) do
    list1
    |> filter(fn item -> Enum.any?(list2, &Funx.Eq.eq?(item, &1, eq)) end)
    |> uniq(eq)
  end

  @doc """
  Returns the difference of two lists.

  ## Examples

      iex> Funx.List.difference([1, 2, 3, 4], [3, 4, 5])
      [1, 2]
  """
  @spec difference([term()], [term()], Funx.Eq.eq_t()) :: [term()]
  def difference(list1, list2, eq \\ Funx.Eq.Protocol) when is_list(list1) and is_list(list2) do
    list1
    |> Enum.reject(fn item -> Enum.any?(list2, &Funx.Eq.eq?(item, &1, eq)) end)
    |> uniq(eq)
  end

  @doc """
  Returns the symmetric difference of two lists.

  ## Examples

      iex> Funx.List.symmetric_difference([1, 2, 3], [3, 4, 5])
      [1, 2, 4, 5]
  """
  @spec symmetric_difference([term()], [term()], Funx.Eq.eq_t()) :: [term()]
  def symmetric_difference(list1, list2, eq \\ Funx.Eq.Protocol)
      when is_list(list1) and is_list(list2) do
    (difference(list1, list2, eq) ++ difference(list2, list1, eq))
    |> uniq(eq)
  end

  @doc """
  Returns true if the given value is an element of the list under the provided `Eq`.

  This is the Eq-based equivalent of Haskell's `elem`.

  ## Examples

      iex> Funx.List.elem?([1, 2, 3], 1)
      true

      iex> Funx.List.elem?([1, 3], 2)
      false
  """
  @spec elem?(term(), [term()], Funx.Eq.eq_t()) :: boolean()
  def elem?(list, value, eq \\ Funx.Eq.Protocol) when is_list(list) do
    Enum.any?(list, &Funx.Eq.eq?(value, &1, eq))
  end

  @doc """
  Checks if the first list is a subset of the second.

  ## Examples

      iex> Funx.List.subset?([1, 2], [1, 2, 3, 4])
      true

      iex> Funx.List.subset?([1, 5], [1, 2, 3, 4])
      false
  """
  @spec subset?([term()], [term()], Funx.Eq.eq_t()) :: boolean()
  def subset?(small, large, eq \\ Funx.Eq.Protocol) when is_list(small) and is_list(large) do
    Enum.all?(small, fn item -> Enum.any?(large, &Funx.Eq.eq?(item, &1, eq)) end)
  end

  @doc """
  Checks if the first list is a superset of the second.

  ## Examples

      iex> Funx.List.superset?([1, 2, 3, 4], [1, 2])
      true

      iex> Funx.List.superset?([1, 2, 3, 4], [1, 5])
      false
  """
  @spec superset?([term()], [term()], Funx.Eq.eq_t()) :: boolean()
  def superset?(large, small, eq \\ Funx.Eq.Protocol) when is_list(small) and is_list(large) do
    subset?(small, large, eq)
  end

  @doc """
  Sorts a list using the given ordering module.

  ## Examples

      iex> Funx.List.sort([3, 1, 4, 1, 5])
      [1, 1, 3, 4, 5]
  """
  @spec sort([term()], Funx.Ord.ord_t()) :: [term()]
  def sort(list, ord \\ Funx.Ord.Protocol) when is_list(list) do
    Enum.sort(list, Funx.Ord.comparator(ord))
  end

  @doc """
  Sorts a list while ensuring uniqueness.

  ## Examples

      iex> Funx.List.strict_sort([3, 1, 4, 1, 5])
      [1, 3, 4, 5]
  """
  @spec strict_sort([term()], Funx.Ord.ord_t()) :: [term()]
  def strict_sort(list, ord \\ Funx.Ord.Protocol) when is_list(list) do
    list
    |> uniq(Funx.Ord.to_eq(ord))
    |> sort(ord)
  end

  @doc """
  Concatenates a list of lists from left to right.

  This uses the `ListConcat` monoid, preserving the original order of elements.

  ## Examples

      iex> Funx.List.concat([[1], [2, 3], [4]])
      [1, 2, 3, 4]
  """
  @spec concat([[term()]]) :: [term()]
  def concat(list) when is_list(list) do
    m_concat(%ListConcat{}, list)
  end

  @doc """
  Returns the head of a list wrapped in `Maybe.Just`, or `Maybe.Nothing` if empty.

  This is a safe version of `hd/1` that returns `Maybe` instead of raising.

  ## Examples

      iex> Funx.List.head([1, 2, 3])
      %Funx.Monad.Maybe.Just{value: 1}

      iex> Funx.List.head([])
      %Funx.Monad.Maybe.Nothing{}

      iex> Funx.List.head("not a list")
      %Funx.Monad.Maybe.Nothing{}
  """
  @spec head([a]) :: Maybe.t(a) when a: term()
  def head(list) do
    case list do
      [head | _] -> Maybe.just(head)
      _ -> Maybe.nothing()
    end
  end

  @doc """
  Returns the head of a list.

  Raises `ArgumentError` if the list is empty or not a list.

  ## Examples

      iex> Funx.List.head!([1, 2, 3])
      1

      iex> Funx.List.head!([42])
      42
  """
  @spec head!([a]) :: a when a: term()
  def head!(list) do
    Maybe.to_try!(head(list), %ArgumentError{message: "cannot get head of empty list"})
  end

  @doc """
  Returns the tail of a list.

  The tail of an empty list is an empty list.

  ## Examples

      iex> Funx.List.tail([1, 2, 3])
      [2, 3]

      iex> Funx.List.tail([1])
      []

      iex> Funx.List.tail([])
      []
  """
  @spec tail([a]) :: [a] when a: term()
  def tail([_ | tail]), do: tail
  def tail([]), do: []

  @doc """
  Returns the maximum element in a list according to the given ordering.

  Returns `Just(element)` for non-empty lists, `Nothing` for empty lists.

  This is a safe version that returns `Maybe` instead of raising.
  Use `max!/2` if you want to raise on empty lists.

  ## Examples

      iex> Funx.List.max([3, 1, 4, 1, 5])
      %Funx.Monad.Maybe.Just{value: 5}

      iex> Funx.List.max([])
      %Funx.Monad.Maybe.Nothing{}

      iex> ord = Funx.Ord.contramap(&String.length/1)
      iex> Funx.List.max(["cat", "elephant", "ox"], ord)
      %Funx.Monad.Maybe.Just{value: "elephant"}
  """
  @spec max([a], Funx.Ord.ord_t()) :: Maybe.t(a) when a: term()
  def max(list, ord \\ Funx.Ord.Protocol) when is_list(list) do
    import Funx.Monad, only: [map: 2]

    head(list)
    |> map(fn first ->
      fold_l(tail(list), first, fn item, acc -> Funx.Ord.max(item, acc, ord) end)
    end)
  end

  @doc """
  Returns the maximum element in a list according to the given ordering.

  Raises `Enum.EmptyError` if the list is empty.

  ## Examples

      iex> Funx.List.max!([3, 1, 4, 1, 5])
      5

      iex> ord = Funx.Ord.contramap(&String.length/1)
      iex> Funx.List.max!(["cat", "elephant", "ox"], ord)
      "elephant"
  """
  @spec max!([a], Funx.Ord.ord_t()) :: a when a: term()
  def max!(list, ord \\ Funx.Ord.Protocol) when is_list(list) do
    Maybe.to_try!(max(list, ord), Enum.EmptyError)
  end

  @doc """
  Returns the minimum element in a list according to the given ordering.

  Returns `Just(element)` for non-empty lists, `Nothing` for empty lists.

  This is a safe version that returns `Maybe` instead of raising.
  Use `min!/2` if you want to raise on empty lists.

  ## Examples

      iex> Funx.List.min([3, 1, 4, 1, 5])
      %Funx.Monad.Maybe.Just{value: 1}

      iex> Funx.List.min([])
      %Funx.Monad.Maybe.Nothing{}

      iex> ord = Funx.Ord.contramap(&String.length/1)
      iex> Funx.List.min(["cat", "elephant", "ox"], ord)
      %Funx.Monad.Maybe.Just{value: "ox"}
  """
  @spec min([a], Funx.Ord.ord_t()) :: Maybe.t(a) when a: term()
  def min(list, ord \\ Funx.Ord.Protocol) when is_list(list) do
    import Funx.Monad, only: [map: 2]

    head(list)
    |> map(fn first ->
      fold_l(tail(list), first, fn item, acc -> Funx.Ord.min(item, acc, ord) end)
    end)
  end

  @doc """
  Returns the minimum element in a list according to the given ordering.

  Raises `Enum.EmptyError` if the list is empty.

  ## Examples

      iex> Funx.List.min!([3, 1, 4, 1, 5])
      1

      iex> ord = Funx.Ord.contramap(&String.length/1)
      iex> Funx.List.min!(["cat", "elephant", "ox"], ord)
      "ox"
  """
  @spec min!([a], Funx.Ord.ord_t()) :: a when a: term()
  def min!(list, ord \\ Funx.Ord.Protocol) when is_list(list) do
    Maybe.to_try!(min(list, ord), Enum.EmptyError)
  end
end

defimpl Funx.Monad, for: List do
  @spec map([term], (term -> term)) :: [term]
  def map(list, func) do
    :lists.map(func, list)
  end

  @spec ap(list((term -> term)), list(term)) :: list(term)
  def ap(funcs, list) do
    :lists.flatten(
      for f <- funcs do
        :lists.map(f, list)
      end
    )
  end

  @spec bind([term], (term -> [term])) :: [term]
  def bind(list, func) do
    :lists.flatmap(func, list)
  end
end

defimpl Funx.Foldable, for: List do
  @spec fold_l(list(term), term, (term, term -> term)) :: term
  def fold_l(list, acc, func), do: :lists.foldl(func, acc, list)

  @spec fold_r(list(term), term, (term, term -> term)) :: term
  def fold_r(list, acc, func), do: :lists.foldr(func, acc, list)
end

defimpl Funx.Filterable, for: List do
  def guard(list, true), do: list
  def guard(_list, false), do: []

  def filter(list, predicate) do
    :lists.filter(predicate, list)
  end

  def filter_map(list, func) do
    :lists.foldl(
      fn x, acc ->
        case func.(x) do
          nil -> acc
          result -> [result | acc]
        end
      end,
      [],
      list
    )
    |> :lists.reverse()
  end
end
