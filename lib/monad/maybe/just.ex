defmodule Funx.Maybe.Just do
  @moduledoc """
  Represents the `Just` variant of the `Maybe` monad, used to model the presence of a value.

  A `Just` wraps a single value and participates in functional composition by propagating the contained value through monadic operations.

  This module implements the following protocols:

    - `Funx.Monad`: Implements `bind/2`, `map/2`, and `ap/2` for monadic composition.
    - `Funx.Foldable`: Provides `fold_l/3` and `fold_r/3` to fold over the wrapped value.
    - `Funx.Filterable`: Supports filtering with `filter/2`, `filter_map/2`, and `guard/2`.
    - `Funx.Eq`: Enables equality checks between `Just` and other `Maybe` values.
    - `Funx.Ord`: Defines ordering behavior between `Just` and `Nothing`.

  These protocol implementations allow `Just` to participate in structured computation, validation, filtering, and comparison within the `Maybe` context.
  """

  @enforce_keys [:value]
  defstruct [:value]

  @type t(value) :: %__MODULE__{value: value}

  @doc """
  Creates a new `Just` value.

  The `pure/1` function wraps a value in the `Just` monad, representing the presence of the value.

  ## Examples

      iex> Funx.Maybe.Just.pure(5)
      %Funx.Maybe.Just{value: 5}

  ### Raises
  - `ArgumentError` if `nil` is provided.

      iex> Funx.Maybe.Just.pure(nil)
      ** (ArgumentError) Cannot wrap nil in a Just
  """
  @spec pure(value) :: t(value) when value: term()
  def pure(nil), do: raise(ArgumentError, "Cannot wrap nil in a Just")
  def pure(value), do: %__MODULE__{value: value}
end

defimpl String.Chars, for: Funx.Maybe.Just do
  alias Funx.Maybe.Just

  def to_string(%Just{value: value}), do: "Just(#{value})"
end

defimpl Funx.Monad, for: Funx.Maybe.Just do
  alias Funx.Maybe.{Just, Nothing}

  @spec map(Just.t(value), (value -> result)) :: Just.t(result)
        when value: term(), result: term()
  def map(%Just{value: value}, func), do: Just.pure(func.(value))

  @spec ap(Just.t((value -> result)) | Nothing.t(), Just.t(value) | Nothing.t()) ::
          Just.t(result) | Nothing.t()
        when value: term(), result: term()
  def ap(%Just{value: func}, %Just{value: value}),
    do: Just.pure(func.(value))

  def ap(%Just{}, %Nothing{}), do: %Nothing{}

  @spec bind(Just.t(value), (value -> Just.t(result))) :: Just.t(result)
        when value: term(), result: term()
  def bind(%Just{value: value}, func), do: func.(value)
end

defimpl Funx.Foldable, for: Funx.Maybe.Just do
  alias Funx.Maybe.Just

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

defimpl Funx.Filterable, for: Funx.Maybe.Just do
  alias Funx.Maybe
  alias Funx.Maybe.Just
  alias Funx.Monad

  @spec guard(Funx.Maybe.Just.t(value), boolean()) :: Funx.Maybe.t(value)
        when value: var
  def guard(%Just{} = maybe, true), do: maybe
  def guard(%Just{}, false), do: Maybe.nothing()

  @spec filter(Funx.Maybe.Just.t(value), (value -> boolean())) :: Funx.Maybe.t(value)
        when value: var
  def filter(%Just{} = maybe, predicate) do
    Monad.bind(maybe, fn value ->
      if predicate.(value) do
        Maybe.pure(value)
      else
        Maybe.nothing()
      end
    end)
  end

  @spec filter_map(Funx.Maybe.Just.t(value), (value -> Funx.Maybe.t(result))) ::
          Funx.Maybe.t(result)
        when value: var, result: var
  def filter_map(%Just{value: value}, func) do
    case func.(value) do
      %Just{} = just -> just
      _ -> Maybe.nothing()
    end
  end
end

defimpl Funx.Eq, for: Funx.Maybe.Just do
  alias Funx.Maybe.{Just, Nothing}
  alias Funx.Eq

  def eq?(%Just{value: v1}, %Just{value: v2}), do: Eq.eq?(v1, v2)
  def eq?(%Just{}, %Nothing{}), do: false

  def not_eq?(%Just{value: v1}, %Just{value: v2}), do: not Eq.eq?(v1, v2)
  def not_eq?(%Just{}, %Nothing{}), do: true
end

defimpl Funx.Ord, for: Funx.Maybe.Just do
  alias Funx.Maybe.{Just, Nothing}
  alias Funx.Ord

  def lt?(%Just{value: v1}, %Just{value: v2}), do: Ord.lt?(v1, v2)
  def lt?(%Just{}, %Nothing{}), do: false

  def le?(%Just{value: v1}, %Just{value: v2}), do: Ord.le?(v1, v2)
  def le?(%Just{}, %Nothing{}), do: false

  def gt?(%Just{value: v1}, %Just{value: v2}), do: Ord.gt?(v1, v2)
  def gt?(%Just{}, %Nothing{}), do: true

  def ge?(%Just{value: v1}, %Just{value: v2}), do: Ord.ge?(v1, v2)
  def ge?(%Just{}, %Nothing{}), do: true
end

defimpl Funx.Summarizable, for: Funx.Maybe.Just do
  def summarize(%{value: value}), do: {:maybe_just, Funx.Summarizable.summarize(value)}
end
