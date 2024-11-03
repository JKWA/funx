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

  defimpl Monex.Monad, for: Monex.Maybe.Nothing do
    alias Monex.Maybe.Nothing

    @spec bind(Nothing.t(), (term() -> Nothing.t())) :: Nothing.t()
    def bind(%Nothing{}, _func), do: %Nothing{}

    @spec map(Nothing.t(), (term() -> term())) :: Nothing.t()
    def map(%Nothing{}, _func), do: %Nothing{}

    @spec ap(Nothing.t(), Nothing.t()) :: Nothing.t()
    def ap(%Nothing{}, _func), do: %Nothing{}
  end

  defimpl String.Chars do
    alias Monex.Maybe.Nothing

    def to_string(%Nothing{}), do: "Nothing"
  end

  defimpl Monex.Foldable do
    alias Monex.Maybe.Nothing

    def fold_l(%Nothing{}, _just_func, nothing_func) do
      nothing_func.()
    end

    def fold_r(%Nothing{}, _just_func, nothing_func) do
      nothing_func.()
    end
  end

  defimpl Monex.Eq do
    alias Monex.Maybe.Nothing

    def eq?(%Nothing{}, %Nothing{}), do: true
    def eq?(%Nothing{}, _), do: false

    def get_eq(_eq_for_value) do
      %{
        eq?: fn
          %Nothing{}, %Nothing{} -> true
          _, _ -> false
        end
      }
    end
  end

  defimpl Monex.Ord do
    alias Monex.Maybe.{Nothing, Just}

    def lt?(%Nothing{}, %Just{}), do: true
    def lt?(%Nothing{}, %Nothing{}), do: false
    def le?(a, b), do: not Monex.Ord.gt?(a, b)
    def gt?(a, b), do: Monex.Ord.lt?(b, a)
    def ge?(a, b), do: not Monex.Ord.lt?(a, b)
  end
end
