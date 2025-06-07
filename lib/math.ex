defmodule Funx.Math do
  @moduledoc """
  Provides mathematical operations using Monoids.

  This module uses the `Sum` and `Product` monoids to perform operations
  such as addition and multiplication over values or lists of values.
  """

  import Funx.Monoid.Utils, only: [m_append: 3, m_concat: 2]
  import Funx.Monad, only: [bind: 2, map: 2]
  alias Funx.Monad.Maybe
  alias Funx.Monoid.{Max, Min, Product, Sum}

  @doc """
  Sums two numbers using the `Sum` monoid.

  ## Examples

      iex> Funx.Math.sum(1, 2)
      3
  """
  @spec sum(number(), number()) :: number()
  def sum(a, b) do
    m_append(%Sum{}, a, b)
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
    m_concat(%Sum{}, list)
  end

  @doc """
  Multiplies two numbers using the `Product` monoid.

  ## Examples

      iex> Funx.Math.product(3, 4)
      12
  """
  @spec product(number(), number()) :: number()
  def product(a, b) do
    m_append(%Product{}, a, b)
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
    m_concat(%Product{}, list)
  end

  @doc """
  Returns the maximum of two numbers using the `Max` monoid.

  ## Examples

      iex> Funx.Math.max(3, 7)
      7

      iex> Funx.Math.max(-1, -5)
      -1
  """
  @spec max(number(), number()) :: number()
  def max(a, b) do
    m_append(%Max{value: Float.min_finite()}, a, b)
  end

  @doc """
  Finds the maximum value in a list using the `Max` monoid.

  Returns `Float.min_finite()` if the list is empty.

  ## Examples

      iex> Funx.Math.max([3, 7, 2])
      7

      iex> Funx.Math.max([])
      Float.min_finite()
  """
  @spec max([number()]) :: number()
  def max(list) when is_list(list) do
    m_concat(%Max{value: Float.min_finite()}, list)
  end

  @doc """
  Returns the minimum of two numbers using the `Min` monoid.

  ## Examples

      iex> Funx.Math.min(3, 7)
      3

      iex> Funx.Math.min(-1, -5)
      -5
  """
  @spec min(number(), number()) :: number()
  def min(a, b) do
    m_append(%Min{value: Float.max_finite()}, a, b)
  end

  @doc """
  Finds the minimum value in a list using the `Min` monoid.

  Returns `Float.max_finite()` if the list is empty.

  ## Examples

      iex> Funx.Math.min([3, 7, 2])
      2

      iex> Funx.Math.min([])
      Float.max_finite()
  """
  @spec min([number()]) :: number()
  def min(list) when is_list(list) do
    m_concat(%Min{value: Float.max_finite()}, list)
  end

  @doc """
  Computes the arithmetic mean of a list of numbers.

  Returns `Nothing` if the list is empty.

  ## Examples

      iex> Funx.Math.mean([1, 2, 3, 4])
      Funx.Monad.Maybe.pure(2.5)

      iex> Funx.Math.mean([])
      Funx.Monad.Maybe.nothing()
  """
  @spec mean([number()]) :: Maybe.t(number())
  def mean([]), do: Maybe.nothing()

  def mean(list) when is_list(list) do
    Maybe.pure(sum(list) / length(list))
  end

  @doc """
  Computes the range (difference between max and min) of a list.

  Returns `nothing()` if the list is empty.

  ## Examples

      iex> Funx.Math.range([3, 7, 2])
      Funx.Monad.Maybe.pure(5)

      iex> Funx.Math.range([])
      Funx.Monad.Maybe.nothing()
  """
  @spec range([number()]) :: Maybe.t(number())
  def range([]), do: Maybe.nothing()

  def range(list) when is_list(list) do
    Maybe.pure(max(list) - min(list))
  end

  @doc """
  Computes the square of a number.

  ## Examples

      iex> Funx.Math.square(3)
      9

      iex> Funx.Math.square(-4)
      16
  """
  @spec square(number()) :: number()
  @spec square([number()]) :: [number()]
  def square(list) when is_list(list), do: map(list, &square/1)

  def square(x) when is_number(x), do: product(x, x)

  # @spec square(number()) :: number()

  @doc """
  Computes the sum of squares of a list of numbers.

  Returns `0` if the list is empty.

  ## Examples

      iex> Funx.Math.sum_of_squares([1, 2, 3])
      14

      iex> Funx.Math.sum_of_squares([-2, 5])
      29

      iex> Funx.Math.sum_of_squares([])
      0
  """
  @spec sum_of_squares([number()]) :: number()
  def sum_of_squares(list) when is_list(list) do
    list |> square() |> sum()
  end

  @doc """
  Computes the deviations from the mean for a list of numbers.

  Returns `Nothing` if the list is empty.

  ## Examples

      iex> Funx.Math.deviation([1, 2, 3, 4])
      Funx.Monad.Maybe.pure([-1.5, -0.5, 0.5, 1.5])

      iex> Funx.Math.deviation([5, 5, 5])
      Funx.Monad.Maybe.pure([0.0, 0.0, 0.0])

      iex> Funx.Math.deviation([])
      Funx.Monad.Maybe.nothing()
  """
  @spec deviation([number()]) :: Maybe.t([number()])
  def deviation(list) when is_list(list) do
    list
    |> mean()
    |> bind(fn mean ->
      Maybe.pure(map(list, &(&1 - mean)))
    end)
  end

  @doc """
  Computes the variance of a list of numbers.

  Returns `Nothing` if the list is empty.

  ## Examples

      iex> Funx.Math.variance([1, 2, 3, 4])
      Funx.Monad.Maybe.pure(1.25)

      iex> Funx.Math.variance([5, 5, 5])
      Funx.Monad.Maybe.pure(0.0)

      iex> Funx.Math.variance([])
      Funx.Monad.Maybe.nothing()
  """
  @spec variance([number()]) :: Maybe.t(number())
  def variance(list) when is_list(list) do
    list
    |> deviation()
    |> bind(fn deviations ->
      Maybe.pure(sum_of_squares(deviations) / length(list))
    end)
  end

  @doc """
  Computes the standard deviation of a list of numbers.

  Returns `Nothing` if the list is empty.

  ## Examples

      iex> Funx.Math.std_dev([1, 2, 3, 4])
      Funx.Monad.Maybe.pure(1.118033988749895)

      iex> Funx.Math.std_dev([5, 5, 5])
      Funx.Monad.Maybe.pure(0.0)

      iex> Funx.Math.std_dev([])
      Funx.Monad.Maybe.nothing()
  """
  @spec std_dev([number()]) :: Maybe.t(number())
  def std_dev(list) when is_list(list) do
    list
    |> variance()
    |> bind(fn var ->
      Maybe.pure(:math.sqrt(var))
    end)
  end
end
