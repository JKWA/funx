defmodule Monex.Enum do
  @moduledoc """
  Utility functions for working with lists while respecting `Eq` and `Ord` instances.
  """
  alias Monex.Eq
  alias Monex.Ord

  @doc """
  Removes duplicate elements from a list based on the given equality module.
  """
  @spec uniq([term()], Eq.Utils.eq_t()) :: [term()]
  def uniq(list, eq \\ Monex.Eq) when is_list(list) do
    list
    |> Enum.reduce([], fn item, acc ->
      if Enum.any?(acc, &Eq.Utils.eq?(item, &1, eq)), do: acc, else: [item | acc]
    end)
    |> :lists.reverse()
  end

  @doc """
  Returns the union of two lists, removing duplicates based on the given equality module.
  """
  @spec union([term()], [term()], Eq.Utils.eq_t()) :: [term()]
  def union(list1, list2, eq \\ Monex.Eq) when is_list(list1) and is_list(list2) do
    (list1 ++ list2) |> uniq(eq)
  end

  @doc """
  Returns the intersection of two lists, keeping elements present in both.
  """
  @spec intersection([term()], [term()], Eq.Utils.eq_t()) :: [term()]
  def intersection(list1, list2, eq \\ Monex.Eq) when is_list(list1) and is_list(list2) do
    list1
    |> Enum.filter(fn item -> Enum.any?(list2, &Eq.Utils.eq?(item, &1, eq)) end)
    |> uniq(eq)
  end

  @doc """
  Returns the difference of two lists, removing elements from the first list that appear in the second.
  """
  @spec difference([term()], [term()], Eq.Utils.eq_t()) :: [term()]
  def difference(list1, list2, eq \\ Monex.Eq) when is_list(list1) and is_list(list2) do
    list1
    |> Enum.reject(fn item -> Enum.any?(list2, &Eq.Utils.eq?(item, &1, eq)) end)
    |> uniq(eq)
  end

  @doc """
  Returns the symmetric difference of two lists, keeping elements that appear in only one of the lists.
  """
  @spec symmetric_difference([term()], [term()], Eq.Utils.eq_t()) :: [term()]
  def symmetric_difference(list1, list2, eq \\ Monex.Eq)
      when is_list(list1) and is_list(list2) do
    (difference(list1, list2, eq) ++ difference(list2, list1, eq))
    |> uniq(eq)
  end

  @doc """
  Checks if the first list is a subset of the second.
  """
  @spec subset?([term()], [term()], Eq.Utils.eq_t()) :: boolean()
  def subset?(small, large, eq \\ Monex.Eq) when is_list(small) and is_list(large) do
    Enum.all?(small, fn item -> Enum.any?(large, &Eq.Utils.eq?(item, &1, eq)) end)
  end

  @doc """
  Checks if the first list is a superset of the second.
  """
  @spec superset?([term()], [term()], Eq.Utils.eq_t()) :: boolean()
  def superset?(large, small, eq \\ Monex.Eq) when is_list(small) and is_list(large) do
    subset?(small, large, eq)
  end

  @doc """
  Sorts a list using the given ordering module.
  """
  @spec sort([term()], Ord.Utils.ord_t()) :: [term()]
  def sort(list, ord \\ Monex.Ord) when is_list(list) do
    Enum.sort(list, Ord.Utils.comparator(ord))
  end

  @doc """
  Sorts a list while ensuring uniqueness based on the given ordering module.
  """
  @spec strict_sort([term()], Ord.Utils.ord_t()) :: [term()]
  def strict_sort(list, ord \\ Monex.Ord) when is_list(list) do
    list
    |> uniq(Ord.Utils.to_eq(ord))
    |> sort(ord)
  end
end
