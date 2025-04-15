defmodule Funx.Maybe.Nothing do
  @moduledoc """
  Represents the `Nothing` variant of the `Maybe` monad, used to model the absence of a value.

  This module implements the following protocols:
    - `Funx.Monad`: Implements the `bind/2`, `map/2`, and `ap/2` functions for monadic operations.
    - `Funx.Foldable`: Provides `fold_l/3` and `fold_r/3` to handle folding with default behavior for `Nothing`.
    - `Funx.Eq`: Defines equality checks between `Nothing` and other `Maybe` values.
    - `Funx.Ord`: Defines ordering logic for `Nothing` and `Just` values.

  The `Nothing` monad provides default implementations where the absence of a value is propagated through operations.
  """

  defstruct []

  @type t :: %__MODULE__{}

  @doc """
  Creates a new `Nothing` value.

  ## Examples

      iex> Funx.Maybe.Nothing.pure()
      %Funx.Maybe.Nothing{}
  """
  @spec pure() :: t()
  def pure, do: %__MODULE__{}
end

defimpl String.Chars, for: Funx.Maybe.Nothing do
  alias Funx.Maybe.Nothing

  def to_string(%Nothing{}), do: "Nothing"
end

defimpl Funx.Monad, for: Funx.Maybe.Nothing do
  alias Funx.Maybe.Nothing

  @spec map(Nothing.t(), (term() -> term())) :: Nothing.t()
  def map(%Nothing{}, _func), do: %Nothing{}

  @spec ap(Nothing.t(), Nothing.t()) :: Nothing.t()
  def ap(%Nothing{}, _val), do: %Nothing{}

  @spec bind(Nothing.t(), (term() -> Nothing.t())) :: Nothing.t()
  def bind(%Nothing{}, _func), do: %Nothing{}
end

defimpl Funx.Foldable, for: Funx.Maybe.Nothing do
  alias Funx.Maybe.Nothing

  def fold_l(%Nothing{}, _just_func, nothing_func) do
    nothing_func.()
  end

  def fold_r(%Nothing{}, _just_func, nothing_func) do
    nothing_func.()
  end
end

defimpl Funx.Filterable, for: Funx.Maybe.Nothing do
  alias Funx.Maybe.Nothing

  @spec guard(Funx.Maybe.Nothing.t(), boolean()) :: Funx.Maybe.t(any())
  def guard(%Nothing{}, _boolean), do: %Nothing{}

  @spec filter(Funx.Maybe.Nothing.t(), (any() -> boolean())) :: Funx.Maybe.t(any())
  def filter(%Nothing{}, _predicate), do: %Nothing{}

  @spec filter_map(Funx.Maybe.Nothing.t(), (any() -> Funx.Maybe.t(any()))) ::
          Funx.Maybe.Nothing.t()
  def filter_map(%Nothing{}, _func), do: %Nothing{}
end

defimpl Funx.Eq, for: Funx.Maybe.Nothing do
  alias Funx.Maybe.{Nothing, Just}

  def eq?(%Nothing{}, %Nothing{}), do: true
  def eq?(%Nothing{}, %Just{}), do: false

  def not_eq?(%Nothing{}, %Nothing{}), do: false
  def not_eq?(%Nothing{}, %Just{}), do: true
end

defimpl Funx.Ord, for: Funx.Maybe.Nothing do
  alias Funx.Maybe.{Nothing, Just}

  def lt?(%Nothing{}, %Just{}), do: true
  def lt?(%Nothing{}, %Nothing{}), do: false

  def le?(%Nothing{}, %Just{}), do: true
  def le?(%Nothing{}, %Nothing{}), do: true

  def gt?(%Nothing{}, %Just{}), do: false
  def gt?(%Nothing{}, %Nothing{}), do: false

  def ge?(%Nothing{}, %Just{}), do: false
  def ge?(%Nothing{}, %Nothing{}), do: true
end
