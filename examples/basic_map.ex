defmodule Basic.Map do
  @moduledoc """
  A module demonstrating the use of `map` with different monads (`Identity`, `Maybe`, and `Either`)
  for transforming values while preserving their monadic context.
  """

  import Monex.Monad, only: [map: 2]
  alias Monex.{Identity, Maybe, Either}

  @type monad_t(value) :: Identity.t(value) | Maybe.t(value) | Either.t(String.t(), value)

  @doc """
  Adds two integers.

  ## Examples

      iex> Basic.Map.add(2, 3)
      5
  """
  @spec add(integer(), integer()) :: integer()
  def add(x, y) when is_integer(x) and is_integer(y), do: x + y

  @doc """
  Increments an integer wrapped in a monad by one.

  Applies the `add` function within the context of a monad, transforming the value it contains
  while preserving its structure.

  ## Examples

      iex> Basic.Map.add_one(Maybe.just(3))
      %Monex.Maybe.Just{value: 4}
  """
  @spec add_one(monad_t(integer())) :: monad_t(integer())
  def add_one(value) do
    value
    |> map(&add(&1, 1))
  end

  @doc """
  Increments an integer wrapped in a monad by two.

  Applies the `add` function twice using `map` to increment the value within the monadic context,
  while keeping the structure intact.

  ## Examples

      iex> Basic.Map.add_two(Identity.pure(3))
      %Monex.Identity{value: 5}
  """
  @spec add_two(monad_t(integer())) :: monad_t(integer())
  def add_two(value) do
    value
    |> map(&add(&1, 1))
    |> map(&add(&1, 1))
  end

  @doc """
  Wraps an integer in the `Identity` monad and increments it by two.

  This function demonstrates the use of the `Identity` monad to apply transformations
  while keeping the value intact within the monadic context.

  ## Examples

      iex> Basic.Map.add_two_identity(3)
      %Monex.Identity{value: 5}
  """
  @spec add_two_identity(integer()) :: Identity.t(integer())
  def add_two_identity(value) when is_integer(value) do
    value
    |> Identity.pure()
    |> add_two()
  end

  @doc """
  Wraps an integer in the `Maybe` monad and increments it by two.

  Uses `Maybe.just/1` to handle a present value, ensuring the transformation occurs only if
  a value is present.

  ## Examples

      iex> Basic.Map.add_two_maybe(3)
      %Monex.Maybe.Just{value: 5}
  """
  @spec add_two_maybe(integer()) :: Maybe.t(integer())
  def add_two_maybe(value) when is_integer(value) do
    value
    |> Maybe.just()
    |> add_two()
  end

  @doc """
  Applies `add_two` to a `Nothing` value in the `Maybe` monad.

  Demonstrates handling of absent values (`Nothing`) in the `Maybe` monad,
  with no transformation applied.

  ## Examples

      iex> Basic.Map.add_two_maybe()
      %Monex.Maybe.Nothing{}
  """
  @spec add_two_maybe() :: Maybe.t(integer())
  def add_two_maybe() do
    Maybe.nothing()
    |> add_two()
  end

  @doc """
  Wraps an integer or string in the `Either` monad and increments it by two if it's an integer.

  Uses `Either.right/1` for integers to indicate a successful path, and `Either.left/1` for strings
  to signal an error, avoiding the need for try-catch blocks.

  ## Examples

      iex> Basic.Map.add_two_either(3)
      %Monex.Either.Right{right: 5}

      iex> Basic.Map.add_two_either("Oops, error")
      %Monex.Either.Left{left: "Oops, error"}
  """
  @spec add_two_either(integer() | String.t()) :: Either.t(String.t(), integer())
  def add_two_either(value) when is_integer(value) do
    value
    |> Either.right()
    |> add_two()
  end

  def add_two_either(value) when is_bitstring(value) do
    value
    |> Either.left()
    |> add_two()
  end
end
