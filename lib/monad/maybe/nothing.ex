defmodule Monex.Maybe.Nothing do
  @moduledoc """
  Represents the `Nothing` variant of the `Maybe` monad, used to model the absence of a value.

  This module implements the following protocols:
    - `Monex.Monad`: Implements the `bind/2`, `map/2`, and `ap/2` functions for monadic operations.
    - `Monex.Foldable`: Provides `fold_l/3` and `fold_r/3` to handle folding with default behavior for `Nothing`.
    - `Monex.Eq`: Defines equality checks between `Nothing` and other `Maybe` values.
    - `Monex.Ord`: Defines ordering logic for `Nothing` and `Just` values.

  The `Nothing` monad provides default implementations where the absence of a value is propagated through operations.
  """

  defstruct []

  @type t :: %__MODULE__{}

  @doc """
  Creates a new `Nothing` value.

  ## Examples

      iex> Monex.Maybe.Nothing.pure()
      %Monex.Maybe.Nothing{}
  """
  @spec pure() :: t()
  def pure, do: %__MODULE__{}
end

defimpl String.Chars, for: Monex.Maybe.Nothing do
  alias Monex.Maybe.Nothing

  def to_string(%Nothing{}), do: "Nothing"
end

defimpl Monex.Monad, for: Monex.Maybe.Nothing do
  alias Monex.Maybe.Nothing

  @spec bind(Nothing.t(), (term() -> Nothing.t())) :: Nothing.t()
  def bind(%Nothing{}, _func), do: %Nothing{}

  @spec map(Nothing.t(), (term() -> term())) :: Nothing.t()
  def map(%Nothing{}, _func), do: %Nothing{}

  @spec ap(Nothing.t(), Nothing.t()) :: Nothing.t()
  def ap(%Nothing{}, _func), do: %Nothing{}
end

defimpl Monex.Foldable, for: Monex.Maybe.Nothing do
  alias Monex.Maybe.Nothing

  def fold_l(%Nothing{}, _just_func, nothing_func) do
    nothing_func.()
  end

  def fold_r(%Nothing{}, _just_func, nothing_func) do
    nothing_func.()
  end
end

defimpl Monex.Filterable, for: Monex.Maybe.Nothing do
  alias Monex.Maybe.Nothing

  @spec guard(Monex.Maybe.Nothing.t(), boolean()) :: Monex.Maybe.t(any())
  def guard(%Nothing{}, _boolean), do: %Nothing{}

  @spec filter(Monex.Maybe.Nothing.t(), (any() -> boolean())) :: Monex.Maybe.t(any())
  def filter(%Nothing{}, _predicate), do: %Nothing{}

  @spec filter_map(Monex.Maybe.Nothing.t(), (any() -> Monex.Maybe.t(any()))) ::
          Monex.Maybe.Nothing.t()
  def filter_map(%Nothing{}, _func), do: %Nothing{}
end

defimpl Monex.Eq, for: Monex.Maybe.Nothing do
  alias Monex.Maybe.{Nothing, Just}

  def eq?(%Nothing{}, %Nothing{}), do: true
  def eq?(%Nothing{}, %Just{}), do: false

  def not_eq?(%Nothing{}, %Nothing{}), do: false
  def not_eq?(%Nothing{}, %Just{}), do: true
end

defimpl Monex.Ord, for: Monex.Maybe.Nothing do
  alias Monex.Maybe.{Nothing, Just}

  def lt?(%Nothing{}, %Just{}), do: true
  def lt?(%Nothing{}, %Nothing{}), do: false

  def le?(%Nothing{}, %Just{}), do: true
  def le?(%Nothing{}, %Nothing{}), do: true

  def gt?(%Nothing{}, %Just{}), do: false
  def gt?(%Nothing{}, %Nothing{}), do: false

  def ge?(%Nothing{}, %Just{}), do: false
  def ge?(%Nothing{}, %Nothing{}), do: true
end
