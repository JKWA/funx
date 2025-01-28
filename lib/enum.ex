defmodule Monex.Enum do
  @moduledoc """
  Utility functions for working with lists while respecting `Eq` and `Ord` instances.
  """
  alias Monex.Eq
  alias Monex.Ord

  @doc """
  Removes duplicate elements from a list based on the given equality module.
  """
  def uniq(list, eq_module \\ Monex.Eq) do
    list
    |> Enum.reduce([], fn item, acc ->
      if Enum.any?(acc, &Eq.Utils.eq?(item, &1, eq_module)), do: acc, else: [item | acc]
    end)
    |> Enum.reverse()
  end

  @doc """
  Returns the union of two lists, removing duplicates based on the given equality module.
  """
  def union(list1, list2, eq_module \\ Monex.Eq) do
    (list1 ++ list2) |> uniq(eq_module)
  end

  @doc """
  Returns the intersection of two lists, keeping elements present in both.
  """
  def intersection(list1, list2, eq_module \\ Monex.Eq) do
    list1
    |> Enum.filter(fn item -> Enum.any?(list2, &Eq.Utils.eq?(item, &1, eq_module)) end)
    |> uniq(eq_module)
  end

  @doc """
  Returns the difference of two lists, removing elements from the first list that appear in the second.
  """
  def difference(list1, list2, eq_module \\ Monex.Eq) do
    list1
    |> Enum.reject(fn item -> Enum.any?(list2, &Eq.Utils.eq?(item, &1, eq_module)) end)
    |> uniq(eq_module)
  end

  @doc """
  Returns the symmetric difference of two lists, keeping elements that appear in only one of the lists.
  """
  def symmetric_difference(list1, list2, eq_module \\ Monex.Eq) do
    (difference(list1, list2, eq_module) ++ difference(list2, list1, eq_module))
    |> uniq(eq_module)
  end

  @doc """
  Checks if the first list is a subset of the second.
  """
  def subset?(small, large, eq_module \\ Monex.Eq) do
    Enum.all?(small, fn item -> Enum.any?(large, &Eq.Utils.eq?(item, &1, eq_module)) end)
  end

  @doc """
  Checks if the first list is a superset of the second.
  """
  def superset?(large, small, eq_module \\ Monex.Eq) do
    subset?(small, large, eq_module)
  end

  @doc """
  Sorts a list using the given ordering module.
  """
  def sort(list, ord \\ Monex.Ord) do
    Enum.sort(list, Ord.Utils.comparator(ord))
  end

  @doc """
  Sorts a list while ensuring uniqueness based on the given ordering module.
  """
  def strict_sort(list, ord \\ Monex.Ord) do
    list
    |> uniq(Ord.Utils.to_eq(ord))
    |> sort(ord)
  end
end
