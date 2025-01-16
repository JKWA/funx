defmodule Monex.Monoid.Utils do
  @moduledoc """
  Utility functions for working with Monoids.

  This module provides functions to combine monoidal values using the
  `concat/2` and `concat/3` functions.
  """

  import Monex.Monoid, only: [empty: 1, append: 2, wrap: 2, unwrap: 1]

  @doc """
  Combines a list of values into a single result using the given monoid.

  If the list is empty, the monoid's identity element is returned.

  ## Examples

      iex> Monex.Monoid.Utils.concat(%Monex.Monoid.Sum{}, [1, 2, 3])
      6

      iex> Monex.Monoid.Utils.concat(%Monex.Monoid.Product{}, [])
      1
  """
  @spec concat(struct(), [any()]) :: any()
  def concat(monoid, values) when is_struct(monoid) and is_list(values) do
    Enum.reduce(values, empty(monoid), fn value, acc ->
      append(acc, wrap(monoid, value))
    end)
    |> unwrap()
  end

  @doc """
  Combines two values into a single result using the given monoid.

  ## Examples

      iex> Monex.Monoid.Utils.concat(%Monex.Monoid.Sum{}, 1, 2)
      3

      iex> Monex.Monoid.Utils.concat(%Monex.Monoid.Product{}, 4, 5)
      20
  """
  @spec concat(struct(), any(), any()) :: any()
  def concat(monoid, a, b) when is_struct(monoid) do
    append(wrap(monoid, a), wrap(monoid, b)) |> unwrap()
  end
end
