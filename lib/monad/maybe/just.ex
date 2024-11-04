defmodule Monex.Maybe.Just do
  @moduledoc """
  Represents the `Just` variant of the `Maybe` monad, used to model the presence of a value.

  This module implements the following protocols:
    - `Monex.Monad`: Implements the `bind/2`, `map/2`, and `ap/2` functions for monadic operations.
    - `Monex.Foldable`: Provides `fold_l/3` and `fold_r/3` to handle folding for `Just` values.
    - `Monex.Eq`: Defines equality checks between `Just` and other `Maybe` values.
    - `Monex.Ord`: Defines ordering logic for `Just` and `Nothing` values.

  The `Just` monad provides implementations that propagate the wrapped value through operations.
  """

  @enforce_keys [:value]
  defstruct [:value]

  @type t(value) :: %__MODULE__{value: value}

  @doc """
  Creates a new `Just` value.

  The `pure/1` function wraps a value in the `Just` monad, representing the presence of the value.

  ## Examples

      iex> Monex.Maybe.Just.pure(5)
      %Monex.Maybe.Just{value: 5}

  ### Raises
  - `ArgumentError` if `nil` is provided.

      iex> Monex.Maybe.Just.pure(nil)
      ** (ArgumentError) Cannot wrap nil in a Just
  """
  @spec pure(value) :: t(value) when value: term()
  def pure(nil), do: raise(ArgumentError, "Cannot wrap nil in a Just")
  def pure(value), do: %__MODULE__{value: value}

  defimpl Monex.Monad do
    alias Monex.Maybe.{Just, Nothing}

    @spec ap(Just.t((value -> result)) | Nothing.t(), Just.t(value) | Nothing.t()) ::
            Just.t(result) | Nothing.t()
          when value: term(), result: term()
    def ap(%Just{value: func}, %Just{value: value}),
      do: Just.pure(func.(value))

    def ap(_, %Nothing{}), do: %Nothing{}

    @spec map(Just.t(value), (value -> result)) :: Just.t(result)
          when value: term(), result: term()
    def map(%Just{value: value}, func), do: Just.pure(func.(value))

    @spec bind(Just.t(value), (value -> Just.t(result))) :: Just.t(result)
          when value: term(), result: term()
    def bind(%Just{value: value}, func), do: func.(value)
  end

  defimpl String.Chars do
    alias Monex.Maybe.Just

    def to_string(%Just{value: value}), do: "Just(#{value})"
  end

  defimpl Monex.Foldable do
    alias Monex.Maybe.Just

    @spec fold_l(Just.t(value), (value -> result), (-> result)) :: result
          when value: term(), result: term()
    def fold_l(%Just{value: value}, just_func, _nothing_func) do
      just_func.(value)
    end

    @spec fold_r(Just.t(value), (value -> result), (-> result)) :: result
          when value: term(), result: term()
    def fold_r(%Just{value: value}, just_func, _nothing_func) do
      just_func.(value)
    end
  end
end

defimpl Monex.Eq, for: Monex.Maybe.Just do
  alias Monex.Maybe.{Just, Nothing}
  alias Monex.Eq

  def eq?(%Just{value: v1}, %Just{value: v2}), do: Eq.eq?(v1, v2)
  def eq?(%Just{}, %Nothing{}), do: false
end

defimpl Monex.Ord, for: Monex.Maybe.Just do
  alias Monex.Maybe.{Just, Nothing}
  alias Monex.Ord

  def lt?(%Just{value: v1}, %Just{value: v2}), do: Ord.lt?(v1, v2)
  def lt?(%Just{}, %Nothing{}), do: false
  def le?(a, b), do: not Monex.Ord.gt?(a, b)
  def gt?(a, b), do: Monex.Ord.lt?(b, a)
  def ge?(a, b), do: not Monex.Ord.lt?(a, b)
end
