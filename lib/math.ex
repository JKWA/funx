defmodule Funx.Math do
  @moduledoc """
  Provides mathematical operations using Monoids.

  This module uses the `Sum` and `Product` monoids to perform operations
  such as addition and multiplication over values or lists of values.
  """

  import Funx.Monoid.Utils, only: [append: 3, concat: 2]
  alias Funx.Monoid.{Max, Product, Sum}

  @doc """
  Sums two numbers using the `Sum` monoid.

  ## Examples

      iex> Funx.Math.sum(1, 2)
      3
  """
  @spec sum(number(), number()) :: number()
  def sum(a, b) do
    append(%Sum{}, a, b)
  end

  @doc """
  Sums a list of numbers using the `Sum` monoid.

  ## Examples

      iex> Funx.Math.sum([1, 2, 3])
      6

      iex> Funx.Math.sum([])
      0
  """
  @spec sum([number()]) :: number()
  def sum(list) when is_list(list) do
    concat(%Sum{}, list)
  end

  @doc """
  Multiplies two numbers using the `Product` monoid.

  ## Examples

      iex> Funx.Math.product(3, 4)
      12
  """
  @spec product(number(), number()) :: number()
  def product(a, b) do
    append(%Product{}, a, b)
  end

  @doc """
  Multiplies a list of numbers using the `Product` monoid.

  ## Examples

      iex> Funx.Math.product([2, 3, 4])
      24

      iex> Funx.Math.product([])
      1
  """
  @spec product([number()]) :: number()
  def product(list) when is_list(list) do
    concat(%Product{}, list)
  end

  def max(a, b) do
    append(%Max{value: Float.min_finite()}, a, b)
  end

  def max(list) when is_list(list) do
    concat(%Max{value: Float.min_finite()}, list)
  end
end
