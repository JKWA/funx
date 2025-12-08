defmodule Funx.Monad.Either.Left do
  @moduledoc """
  Represents the `Left` variant of the `Either` monad, used to model an error or failure.

  This module implements the following protocols:
    - `Funx.Eq`: Defines equality checks between `Left` and other `Either` values.
    - `Funx.Foldable`: Provides `fold_l/3` and `fold_r/3` to handle folding for `Left` values.
    - `Funx.Monad`: Implements the `bind/2`, `map/2`, and `ap/2` functions for monadic operations.
    - `Funx.Ord`: Defines ordering logic for `Left` and `Right` values.

  The `Left` monad propagates the wrapped error through operations without executing the success logic.
  """
  @enforce_keys [:left]
  defstruct [:left]

  @type t(value) :: %__MODULE__{left: value}

  @doc """
  Creates a new `Left` value.

  The `pure/1` function wraps a value in the `Left` monad, representing an error or failure.

  ## Examples

      iex> Funx.Monad.Either.Left.pure("error")
      %Funx.Monad.Either.Left{left: "error"}
  """
  @spec pure(value) :: t(value) when value: term()
  def pure(value), do: %__MODULE__{left: value}
end

defimpl String.Chars, for: Funx.Monad.Either.Left do
  alias Funx.Monad.Either.Left

  def to_string(%Left{left: left}), do: "Left(#{left})"
end

defimpl Funx.Monad, for: Funx.Monad.Either.Left do
  alias Funx.Monad.Either.{Left, Right}

  @spec map(Left.t(value), (term() -> term())) :: Left.t(value)
        when value: term()
  def map(%Left{} = left, _func), do: left

  @spec ap(Left.t(value), Left.t(value)) :: Left.t(value)
        when value: term()
  def ap(%Left{} = left, %Left{}), do: left
  def ap(%Left{} = left, %Right{}), do: left

  @spec bind(Left.t(value), (term() -> Left.t(result))) :: Left.t(value)
        when value: term(), result: term()
  def bind(%Left{} = left, _func), do: left
end

defimpl Funx.Foldable, for: Funx.Monad.Either.Left do
  alias Funx.Monad.Either.Left

  def fold_l(%Left{left: left}, _right_func, left_func) do
    left_func.(left)
  end

  def fold_r(%Left{} = left, right_func, left_func) do
    fold_l(left, right_func, left_func)
  end
end

defimpl Funx.Eq, for: Funx.Monad.Either.Left do
  alias Funx.Monad.Either.{Left, Right}
  alias Funx.Eq

  def eq?(%Left{left: v1}, %Left{left: v2}), do: Eq.eq?(v1, v2)
  def eq?(%Left{}, %Right{}), do: false

  def not_eq?(%Left{left: v1}, %Left{left: v2}), do: Eq.not_eq?(v1, v2)
  def not_eq?(%Left{}, %Right{}), do: true
end

defimpl Funx.Ord, for: Funx.Monad.Either.Left do
  alias Funx.Monad.Either.{Left, Right}
  alias Funx.Ord

  def lt?(%Left{left: v1}, %Left{left: v2}), do: Ord.lt?(v1, v2)
  def lt?(%Left{}, %Right{}), do: true

  def le?(%Left{left: v1}, %Left{left: v2}), do: Ord.le?(v1, v2)
  def le?(%Left{}, %Right{}), do: true

  def gt?(%Left{left: v1}, %Left{left: v2}), do: Ord.gt?(v1, v2)
  def gt?(%Left{}, %Right{}), do: false

  def ge?(%Left{left: v1}, %Left{left: v2}), do: Ord.ge?(v1, v2)
  def ge?(%Left{}, %Right{}), do: false
end

defimpl Funx.Summarizable, for: Funx.Monad.Either.Left do
  def summarize(%{left: value}), do: {:either_left, Funx.Summarizable.summarize(value)}
end

defimpl Funx.Tappable, for: Funx.Monad.Either.Left do
  def tap(left, _fun), do: left
end
