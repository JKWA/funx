defmodule Monex.Monoid.Utils do
  @moduledoc """
  Utility functions for working with Monoids.

  This module provides functions to combine monoidal values using the
  `concat/2` and `concat/3` functions.
  """

  import Monex.Monoid, only: [empty: 1, append: 2, wrap: 2, unwrap: 1]

  @doc """
  Appends two values within a given monoid.

  This function wraps the input values using the provided `monoid`, applies
  the `append/2` operation, and then unwraps the result.

  ## Parameters
    - `monoid` – The monoid struct defining how values should be combined.
    - `a` – The first value to be appended.
    - `b` – The second value to be appended.

  ## Examples

      iex> append(%Monoid.Sum{}, 3, 5)
      8

      iex> append(%Monoid.Ord{}, :apple, :banana)
      :lt

  """
  @spec append(struct(), any(), any()) :: any()
  def append(monoid, a, b) when is_struct(monoid) do
    append(wrap(monoid, a), wrap(monoid, b)) |> unwrap()
  end

  @doc """
  Concatenates two values within a given monoid.

  This function wraps the input values using the provided `monoid`, applies
  the `append/2` operation, and then unwraps the result.

  ## Parameters
    - `monoid` – The monoid struct defining how values should be combined.
    - `a` – The first value to be concatenated.
    - `b` – The second value to be concatenated.

  ## Examples

      iex> concat(%Monoid.Sum{}, 3, 5)
      8

      iex> concat(%Monoid.Ord{}, :apple, :banana)
      :lt

  """
  def concat(monoid, values) when is_struct(monoid) and is_list(values) do
    Enum.reduce(values, empty(monoid), fn value, acc ->
      append(acc, wrap(monoid, value))
    end)
    |> unwrap()
  end
end
