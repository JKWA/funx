defmodule Monex.Either.Right do
  @moduledoc """
  Represents the `Right` variant of the `Either` monad, used to model a success or valid result.

  This module implements the following protocols:
    - `Monex.Monad`: Implements the `bind/2`, `map/2`, and `ap/2` functions for monadic operations.
    - `Monex.Foldable`: Provides `fold_l/3` and `fold_r/3` to handle folding for `Right` values.
    - `Monex.Eq`: Defines equality checks between `Right` and other `Either` values.
    - `Monex.Ord`: Defines ordering logic for `Right` and `Left` values.

  The `Right` monad represents a valid result, and the contained value is propagated through operations.
  """

  @enforce_keys [:value]
  defstruct [:value]

  @type t(value) :: %__MODULE__{value: value}

  @doc """
  Creates a new `Right` value.

  The `pure/1` function wraps a value in the `Right` monad, representing a valid result.

  ## Examples

      iex> Monex.Either.Right.pure(5)
      %Monex.Either.Right{value: 5}
  """
  @spec pure(value) :: t(value) when value: term()
  def pure(value), do: %__MODULE__{value: value}

  defimpl Monex.Monad do
    alias Monex.Either.{Left, Right}

    @spec ap(Right.t((value -> result)), Right.t(value)) :: Right.t(result)
          when value: term(), result: term()
    def ap(%Right{value: func}, %Right{value: value}), do: Right.pure(func.(value))

    @spec ap(term(), Left.t(value)) :: Left.t(value)
          when value: term()
    def ap(_, %Left{} = left), do: left

    @spec bind(Right.t(value), (value -> Right.t(result))) :: Right.t(result)
          when value: term(), result: term()
    def bind(%Right{value: value}, func), do: func.(value)

    @spec map(Right.t(value), (value -> result)) :: Right.t(result)
          when value: term(), result: term()
    def map(%Right{value: value}, func), do: Right.pure(func.(value))
  end

  defimpl String.Chars do
    alias Monex.Either.{Right}

    def to_string(%Right{value: value}), do: "Right(#{value})"
  end

  defimpl Monex.Foldable do
    alias Monex.Either.{Right}

    def fold_l(%Right{value: value}, right_func, _left_func) do
      right_func.(value)
    end

    def fold_r(%Right{value: value}, right_func, _left_func) do
      right_func.(value)
    end
  end

  defimpl Monex.Eq do
    alias Monex.Either.{Left, Right}

    def eq?(%Right{value: v1}, %Right{value: v2}), do: v1 == v2
    def eq?(%Right{}, %Left{}), do: false

    def get_eq(eq_for_value) do
      %{
        eq?: fn
          %Right{value: a}, %Right{value: b} -> eq_for_value[:eq?].(a, b)
          _, _ -> false
        end
      }
    end
  end

  defimpl Monex.Ord do
    alias Monex.Either.{Left, Right}
    def lt?(%Right{value: v1}, %Right{value: v2}), do: v1 < v2
    def lt?(%Right{}, %Left{}), do: false
    def le?(a, b), do: not Monex.Ord.gt?(a, b)
    def gt?(a, b), do: Monex.Ord.lt?(b, a)
    def ge?(a, b), do: not Monex.Ord.lt?(a, b)
  end
end
