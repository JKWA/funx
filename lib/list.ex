defmodule Funx.List do
  @moduledoc """
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

  ### Monad Implementation

  - `map/2`: Transforms list elements.
  - `bind/2`: Applies a function returning lists and flattens the result.
  - `ap/2`: Applies functions in a list to elements in another list.

  ### Foldable Implementation

  - `fold_l/3`: Performs left-associative folding.
  - `fold_r/3`: Performs right-associative folding.
  """
  import Funx.Foldable, only: [fold_l: 3]
  import Funx.Filterable, only: [filter: 2]
  import Funx.Monoid.Utils, only: [concat: 2]

  alias Funx.Eq
  alias Funx.Monoid.ListConcat
  alias Funx.Ord

  @doc """
  Removes duplicate elements from a list based on the given equality module.

  ## Examples

      iex> Funx.List.uniq([1, 2, 2, 3, 1, 4, 5])
      [1, 2, 3, 4, 5]
  """
  @spec uniq([term()], Eq.Utils.eq_t()) :: [term()]
  def uniq(list, eq \\ Funx.Eq) when is_list(list) do
    list
    |> fold_l([], fn item, acc ->
      if Enum.any?(acc, &Eq.Utils.eq?(item, &1, eq)), do: acc, else: [item | acc]
    end)
    |> :lists.reverse()
  end

  @doc """
  Returns the union of two lists, removing duplicates.

  ## Examples

      iex> Funx.List.union([1, 2, 3], [3, 4, 5])
      [1, 2, 3, 4, 5]
  """
  @spec union([term()], [term()], Eq.Utils.eq_t()) :: [term()]
  def union(list1, list2, eq \\ Funx.Eq) when is_list(list1) and is_list(list2) do
    (list1 ++ list2) |> uniq(eq)
  end

  @doc """
  Returns the intersection of two lists.

  ## Examples

      iex> Funx.List.intersection([1, 2, 3, 4], [3, 4, 5])
      [3, 4]
  """
  @spec intersection([term()], [term()], Eq.Utils.eq_t()) :: [term()]
  def intersection(list1, list2, eq \\ Funx.Eq) when is_list(list1) and is_list(list2) do
    list1
    |> filter(fn item -> Enum.any?(list2, &Eq.Utils.eq?(item, &1, eq)) end)
    |> uniq(eq)
  end

  @doc """
  Returns the difference of two lists.

  ## Examples

      iex> Funx.List.difference([1, 2, 3, 4], [3, 4, 5])
      [1, 2]
  """
  @spec difference([term()], [term()], Eq.Utils.eq_t()) :: [term()]
  def difference(list1, list2, eq \\ Funx.Eq) when is_list(list1) and is_list(list2) do
    list1
    |> Enum.reject(fn item -> Enum.any?(list2, &Eq.Utils.eq?(item, &1, eq)) end)
    |> uniq(eq)
  end

  @doc """
  Returns the symmetric difference of two lists.

  ## Examples

      iex> Funx.List.symmetric_difference([1, 2, 3], [3, 4, 5])
      [1, 2, 4, 5]
  """
  @spec symmetric_difference([term()], [term()], Eq.Utils.eq_t()) :: [term()]
  def symmetric_difference(list1, list2, eq \\ Funx.Eq)
      when is_list(list1) and is_list(list2) do
    (difference(list1, list2, eq) ++ difference(list2, list1, eq))
    |> uniq(eq)
  end

  @doc """
  Checks if the first list is a subset of the second.

  ## Examples

      iex> Funx.List.subset?([1, 2], [1, 2, 3, 4])
      true

      iex> Funx.List.subset?([1, 5], [1, 2, 3, 4])
      false
  """
  @spec subset?([term()], [term()], Eq.Utils.eq_t()) :: boolean()
  def subset?(small, large, eq \\ Funx.Eq) when is_list(small) and is_list(large) do
    Enum.all?(small, fn item -> Enum.any?(large, &Eq.Utils.eq?(item, &1, eq)) end)
  end

  @doc """
  Checks if the first list is a superset of the second.

  ## Examples

      iex> Funx.List.superset?([1, 2, 3, 4], [1, 2])
      true

      iex> Funx.List.superset?([1, 2, 3, 4], [1, 5])
      false
  """
  @spec superset?([term()], [term()], Eq.Utils.eq_t()) :: boolean()
  def superset?(large, small, eq \\ Funx.Eq) when is_list(small) and is_list(large) do
    subset?(small, large, eq)
  end

  @doc """
  Sorts a list using the given ordering module.

  ## Examples

      iex> Funx.List.sort([3, 1, 4, 1, 5])
      [1, 1, 3, 4, 5]
  """
  @spec sort([term()], Ord.Utils.ord_t()) :: [term()]
  def sort(list, ord \\ Funx.Ord) when is_list(list) do
    Enum.sort(list, Ord.Utils.comparator(ord))
  end

  @doc """
  Sorts a list while ensuring uniqueness.

  ## Examples

      iex> Funx.List.strict_sort([3, 1, 4, 1, 5])
      [1, 3, 4, 5]
  """
  @spec strict_sort([term()], Ord.Utils.ord_t()) :: [term()]
  def strict_sort(list, ord \\ Funx.Ord) when is_list(list) do
    list
    |> uniq(Ord.Utils.to_eq(ord))
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
    concat(%ListConcat{}, list)
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
