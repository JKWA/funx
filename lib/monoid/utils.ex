defmodule Funx.Monoid.Utils do
  @moduledoc """
  Utility functions for working with Monoids.

  This module provides functions to combine monoidal values using
  `m_append/3` and `m_concat/2`.
  """

  import Funx.Monoid, only: [empty: 1, append: 2, wrap: 2, unwrap: 1]
  import Funx.Foldable, only: [fold_l: 3]

  @doc """
  Appends two values within a given monoid.

  This function wraps the input values using the provided `monoid`, applies
  the `append/2` operation, and then unwraps the result.

  ## Parameters

    - `monoid` – A monoid struct defining how values should be combined.
    - `a` – The first raw value.
    - `b` – The second raw value.

  ## Examples

      iex> alias Funx.Monoid.Sum
      iex> Funx.Monoid.Utils.m_append(%Sum{}, 3, 5)
      8
  """
  @spec m_append(struct(), any(), any()) :: any()
  def m_append(monoid, a, b) when is_struct(monoid) do
    append(wrap(monoid, a), wrap(monoid, b)) |> unwrap()
  end

  @doc """
  Concatenates a list of values using the given monoid.

  This function wraps each value using the provided `monoid`, folds the list
  using the monoid's identity and append operation, and then unwraps the result.

  ## Parameters

    - `monoid` – A monoid struct defining how values should be combined.
    - `values` – A list of raw values.

  ## Examples

      iex> alias Funx.Monoid.Sum
      iex> Funx.Monoid.Utils.m_concat(%Sum{}, [1, 2, 3])
      6
  """
  @spec m_concat(struct(), list()) :: any()
  def m_concat(monoid, values) when is_struct(monoid) and is_list(values) do
    fold_l(values, empty(monoid), fn value, acc ->
      append(acc, wrap(monoid, value))
    end)
    |> unwrap()
  end
end
