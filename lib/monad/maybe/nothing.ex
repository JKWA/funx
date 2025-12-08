defmodule Funx.Monad.Maybe.Nothing do
  @moduledoc """
  Represents the `Nothing` variant of the `Maybe` monad, used to model the absence of a value.

  A `Nothing` indicates that no value is present. All operations in the monad context simply propagate the absence, making `Nothing` an identity for failure or emptiness.

  This module implements the following protocols:

    - `Funx.Monad`: Implements `bind/2`, `map/2`, and `ap/2`, all of which return `Nothing`.
    - `Funx.Foldable`: Provides `fold_l/3` and `fold_r/3`, invoking the fallback function when folding.
    - `Funx.Filterable`: Supports filtering operations, which always return `Nothing`.
    - `Funx.Eq`: Enables equality checks between `Nothing` and other `Maybe` values.
    - `Funx.Ord`: Defines ordering behavior between `Nothing` and `Just`.
    - `Funx.Tappable`: Returns `Nothing` unchanged without executing the tap function.

  These implementations ensure that `Nothing` behaves consistently in functional composition, filtering, and comparison, treating absence as a stable and composable case.
  """

  defstruct []

  @type t :: %__MODULE__{}

  @doc """
  Creates a new `Nothing` value.

  ## Examples

      iex> Funx.Monad.Maybe.Nothing.pure()
      %Funx.Monad.Maybe.Nothing{}
  """
  @spec pure() :: t()
  def pure, do: %__MODULE__{}
end

defimpl String.Chars, for: Funx.Monad.Maybe.Nothing do
  alias Funx.Monad.Maybe.Nothing

  def to_string(%Nothing{}), do: "Nothing"
end

defimpl Funx.Monad, for: Funx.Monad.Maybe.Nothing do
  alias Funx.Monad.Maybe.Nothing

  @spec map(Nothing.t(), (term() -> term())) :: Nothing.t()
  def map(%Nothing{}, _func), do: %Nothing{}

  @spec ap(Nothing.t(), Nothing.t()) :: Nothing.t()
  def ap(%Nothing{}, _val), do: %Nothing{}

  @spec bind(Nothing.t(), (term() -> Nothing.t())) :: Nothing.t()
  def bind(%Nothing{}, _func), do: %Nothing{}
end

defimpl Funx.Foldable, for: Funx.Monad.Maybe.Nothing do
  alias Funx.Monad.Maybe.Nothing

  def fold_l(%Nothing{}, _just_func, nothing_func) do
    nothing_func.()
  end

  def fold_r(%Nothing{} = nothing, just_func, nothing_func) do
    fold_l(nothing, just_func, nothing_func)
  end
end

defimpl Funx.Filterable, for: Funx.Monad.Maybe.Nothing do
  alias Funx.Monad.Maybe.Nothing

  @spec guard(Funx.Monad.Maybe.Nothing.t(), boolean()) :: Funx.Monad.Maybe.t(any())
  def guard(%Nothing{}, _boolean), do: %Nothing{}

  @spec filter(Funx.Monad.Maybe.Nothing.t(), (any() -> boolean())) :: Funx.Monad.Maybe.t(any())
  def filter(%Nothing{}, _predicate), do: %Nothing{}

  @spec filter_map(Funx.Monad.Maybe.Nothing.t(), (any() -> Funx.Monad.Maybe.t(any()))) ::
          Funx.Monad.Maybe.Nothing.t()
  def filter_map(%Nothing{}, _func), do: %Nothing{}
end

defimpl Funx.Eq, for: Funx.Monad.Maybe.Nothing do
  alias Funx.Monad.Maybe.{Nothing, Just}

  def eq?(%Nothing{}, %Nothing{}), do: true
  def eq?(%Nothing{}, %Just{}), do: false

  def not_eq?(%Nothing{}, %Nothing{}), do: false
  def not_eq?(%Nothing{}, %Just{}), do: true
end

defimpl Funx.Ord, for: Funx.Monad.Maybe.Nothing do
  alias Funx.Monad.Maybe.{Nothing, Just}

  def lt?(%Nothing{}, %Just{}), do: true
  def lt?(%Nothing{}, %Nothing{}), do: false

  def le?(%Nothing{}, %Just{}), do: true
  def le?(%Nothing{}, %Nothing{}), do: true

  def gt?(%Nothing{}, %Just{}), do: false
  def gt?(%Nothing{}, %Nothing{}), do: false

  def ge?(%Nothing{}, %Just{}), do: false
  def ge?(%Nothing{}, %Nothing{}), do: true
end

defimpl Funx.Summarizable, for: Funx.Monad.Maybe.Nothing do
  def summarize(_), do: {:maybe_nothing, Funx.Summarizable.summarize(nil)}
end

defimpl Funx.Tappable, for: Funx.Monad.Maybe.Nothing do
  alias Funx.Monad.Maybe.Nothing

  @spec tap(Nothing.t(), (term() -> any())) :: Nothing.t()
  def tap(%Nothing{} = nothing, _func), do: nothing
end
