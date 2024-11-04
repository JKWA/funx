defmodule Basic.Bind do
  @moduledoc """
  A module demonstrating the use of `bind` with different monads (`Identity`, `Maybe`, and `Either`)
  for transforming values while preserving their monadic context.

  This module explores how `bind` works by flattening nested monadic structures, allowing chained transformations
  without additional wrapping layers.
  """

  import Monex.Monad, only: [bind: 2, map: 2]
  alias Monex.{Identity, Maybe, Either}

  @type monad_t(value) :: Identity.t(value) | Maybe.t(value) | Either.t(String.t(), value)

  @doc """
  Adds two integers.

  ## Examples

      iex> Basic.Bind.add(2, 3)
      5
  """
  @spec add(integer(), integer()) :: integer()
  def add(x, y) when is_integer(x) and is_integer(y), do: x + y

  @doc """
  Increments an integer wrapped in a monad by one.

  Uses `map` to apply the `add/2` function within the context of the monad, preserving the monadic structure.

  ## Examples

      iex> Basic.Bind.add_one(Maybe.just(3))
      %Monex.Maybe.Just{value: 4}
  """
  @spec add_one(monad_t(integer())) :: monad_t(integer())
  def add_one(value) do
    value
    |> map(&add(&1, 1))
  end

  @doc """
  Increments an integer within the `Identity` monad by one.

  Lifts the integer into the `Identity` monadic context and then applies `add_one`.

  ## Examples

      iex> Basic.Bind.add_one_identity(3)
      %Monex.Identity{value: 4}
  """
  @spec add_one_identity(integer()) :: Identity.t(integer())
  def add_one_identity(value) when is_integer(value) do
    value
    |> Identity.pure()
    |> add_one()
  end

  @doc """
  Adds two to an integer within the `Identity` monad by chaining two `add_one_identity` transformations.

  Uses `bind` to flatten the result of two `add_one_identity` operations, resulting in a single `Identity` structure.

  ## Examples

      iex> Basic.Bind.add_two_identity(3)
      %Monex.Identity{value: 5}
  """
  @spec add_two_identity(integer()) :: Identity.t(integer())
  def add_two_identity(value) do
    value
    |> add_one_identity()
    |> bind(&add_one_identity/1)
  end

  @doc """
  Increments an integer or handles `nil` within the `Maybe` monad by one.

  Converts `nil` to `Nothing` or an integer to `Just` using `Maybe.from_nil/1`, and applies `add_one`.

  ## Examples

      iex> Basic.Bind.add_one_maybe(3)
      %Monex.Maybe.Just{value: 4}

      iex> Basic.Bind.add_one_maybe(nil)
      %Monex.Maybe.Nothing{}
  """
  def add_one_maybe(value) when is_integer(value) or is_nil(value) do
    value
    |> Maybe.from_nil()
    |> add_one()
  end

  @doc """
  Adds two to an integer or handles `nil` within the `Maybe` monad.

  Composes two `add_one_maybe` operations using `bind` to flatten the resulting structure, retaining a single `Maybe` context.

  ## Examples

      iex> Basic.Bind.add_two_maybe(3)
      %Monex.Maybe.Just{value: 5}

      iex> Basic.Bind.add_two_maybe(nil)
      %Monex.Maybe.Nothing{}
  """
  def add_two_maybe(value) when is_integer(value) or is_nil(value) do
    value
    |> add_one_maybe()
    |> bind(&add_one_maybe/1)
  end

  @doc """
  Increments an integer or handles `nil` within the `Either` monad by one.

  Uses `Maybe` to handle possible `nil` values, then lifts to `Either` to convert `Nothing` to `Left` with a custom error message.

  ## Examples

      iex> Basic.Bind.add_one_either(3)
      %Monex.Either.Right{right: 4}

      iex> Basic.Bind.add_one_either(nil)
      %Monex.Either.Left{left: "Value must not be nil"}
  """
  def add_one_either(value) when is_integer(value) or is_nil(value) do
    value
    |> add_one_maybe()
    |> Either.lift_maybe(fn -> "Value must not be nil" end)
  end

  @doc """
  Adds two to an integer or handles `nil` within the `Either` monad.

  Chains two `add_one_either` transformations using `bind`, managing errors and producing a single `Either` structure.

  ## Examples

      iex> Basic.Bind.add_two_either(3)
      %Monex.Either.Right{right: 5}

      iex> Basic.Bind.add_two_either(nil)
      %Monex.Either.Left{left: "Value must not be nil"}
  """
  @spec add_two_either(integer() | nil) :: Either.t(String.t(), integer())
  def add_two_either(value) when is_integer(value) or is_nil(value) do
    value
    |> add_one_either()
    |> bind(&add_one_either/1)
  end
end
