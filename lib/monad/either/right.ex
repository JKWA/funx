defmodule Funx.Either.Right do
  @moduledoc """
  Represents the `Right` variant of the `Either` monad, used to model a success or valid result.

  This module implements the following protocols:
    - `Funx.Eq`: Defines equality checks between `Right` and other `Either` values.
    - `Funx.Filterable`: Provides `guard/2`, `filter/2`, and `filter_map/2` for conditional transformations.
    - `Funx.Foldable`: Provides `fold_l/3` and `fold_r/3` to handle folding for `Right` values.
    - `Funx.Monad`: Implements the `bind/2`, `map/2`, and `ap/2` functions for monadic operations.
    - `Funx.Ord`: Defines ordering logic for `Right` and `Left` values.

  The `Right` monad represents a valid result, and the contained value is propagated through operations.

  ### `Funx.Filterable` Implementation

  This module implements `Funx.Filterable`, allowing `Right` values to be conditionally transformed or filtered.
  """

  @enforce_keys [:right]
  defstruct [:right]

  @type t(value) :: %__MODULE__{right: value}

  @doc """
  Creates a new `Right` value.

  The `pure/1` function wraps a value in the `Right` monad, representing a valid result.

  ## Examples

      iex> Funx.Either.Right.pure(5)
      %Funx.Either.Right{right: 5}
  """
  @spec pure(value) :: t(value) when value: term()
  def pure(value), do: %__MODULE__{right: value}
end

defimpl String.Chars, for: Funx.Either.Right do
  alias Funx.Either.Right

  def to_string(%Right{right: value}), do: "Right(#{value})"
end

defimpl Funx.Monad, for: Funx.Either.Right do
  alias Funx.Either.{Left, Right}

  @spec ap(Right.t((value -> result)), Right.t(value)) :: Right.t(result)
        when value: term(), result: term()
  def ap(%Right{right: func}, %Right{right: value}), do: Right.pure(func.(value))

  @spec ap(term(), Left.t(value)) :: Left.t(value)
        when value: term()
  def ap(_, %Left{} = left), do: left

  @spec bind(Right.t(value), (value -> Right.t(result))) :: Right.t(result)
        when value: term(), result: term()
  def bind(%Right{right: value}, func), do: func.(value)

  @spec map(Right.t(value), (value -> result)) :: Right.t(result)
        when value: term(), result: term()
  def map(%Right{right: value}, func), do: Right.pure(func.(value))
end

defimpl Funx.Foldable, for: Funx.Either.Right do
  alias Funx.Either.Right

  def fold_l(%Right{right: value}, right_func, _left_func) do
    right_func.(value)
  end

  def fold_r(%Right{right: value}, right_func, _left_func) do
    right_func.(value)
  end
end

defimpl Funx.Filterable, for: Funx.Either.Right do
  alias Funx.Either
  alias Funx.Either.Right
  alias Funx.Monad

  @spec guard(Right.t(value), boolean()) :: Either.t(any(), value)
        when value: term()
  def guard(%Right{} = right, true), do: right
  def guard(%Right{}, false), do: Either.left(:filtered_out)

  @spec filter(Right.t(value), (value -> boolean())) :: Either.t(any(), value)
        when value: term()
  def filter(%Right{} = right, predicate) do
    Monad.bind(right, fn value ->
      if predicate.(value) do
        Either.pure(value)
      else
        Either.left(:filtered_out)
      end
    end)
  end

  @spec filter_map(Right.t(value), (value -> Either.t(left, result))) :: Either.t(left, result)
        when value: term(), left: term(), result: term()
  def filter_map(%Right{right: value}, func) do
    case func.(value) do
      %Right{} = right -> right
      %Either.Left{} = left -> left
      _ -> Either.left(:filtered_out)
    end
  end
end

defimpl Funx.Eq, for: Funx.Either.Right do
  alias Funx.Either.{Left, Right}
  alias Funx.Eq

  def eq?(%Right{right: v1}, %Right{right: v2}), do: Eq.eq?(v1, v2)
  def eq?(%Right{}, %Left{}), do: false

  def not_eq?(%Right{right: v1}, %Right{right: v2}), do: not Eq.eq?(v1, v2)
  def not_eq?(%Right{}, %Left{}), do: true
end

defimpl Funx.Ord, for: Funx.Either.Right do
  alias Funx.Either.{Left, Right}
  alias Funx.Ord

  def lt?(%Right{right: v1}, %Right{right: v2}), do: Ord.lt?(v1, v2)
  def lt?(%Right{}, %Left{}), do: false
  def le?(a, b), do: not Funx.Ord.gt?(a, b)
  def gt?(a, b), do: Funx.Ord.lt?(b, a)
  def ge?(a, b), do: not Funx.Ord.lt?(a, b)
end
