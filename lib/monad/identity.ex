defmodule Funx.Monad.Identity do
  @moduledoc """
  [![Run in Livebook](https://livebook.dev/badge/v1/black.svg)](https://livebook.dev/run?url=https%3A%2F%2Fgithub.com%2FJKWA%2Ffunx%2Fblob%2Fmain%2Flivebooks%2Fmonad%2Fidentity%2Fidentity.livemd)

  The `Funx.Monad.Identity` module represents the identity monad, where values are simply wrapped in a structure
  and operations are applied directly to those values.

  ## Functions

    - `pure/1`: Wraps a value in the `Identity` monad.
    - `extract/1`: Extracts the wrapped value from an `Identity`.

  ## Protocols

  This module implements the following protocols:
    - `Funx.Monad`: Implements the `bind/2`, `map/2`, and `ap/2` functions for monadic operations.
    - `Funx.Eq`: Defines equality checks for `Identity` values.
    - `Funx.Ord`: Defines ordering logic for `Identity` values.
    - `Funx.Tappable`: Executes side effects on the wrapped value via `Funx.Tappable.tap/2`.
    - `String.Chars`: Converts an `Identity` value into a string representation.
  """

  alias Funx.Eq.Protocol

  @enforce_keys [:value]
  defstruct [:value]

  @type t(value) :: %__MODULE__{value: value}

  @doc """
  Creates a new `Identity` value by wrapping a given value.

  ## Examples

      iex> Funx.Monad.Identity.pure(5)
      %Funx.Monad.Identity{value: 5}
  """
  @spec pure(value) :: t(value) when value: term()
  def pure(value), do: %__MODULE__{value: value}

  @doc """
  Extracts the value from an `Identity`.

  ## Examples

      iex> Funx.Monad.Identity.extract(Funx.Monad.Identity.pure(5))
      5
  """
  @spec extract(t(value)) :: value when value: term()
  def extract(%__MODULE__{value: value}), do: value

  @spec lift_eq(Funx.Eq.eq_map()) :: Funx.Eq.eq_map()
  def lift_eq(custom_eq) do
    custom_eq = Funx.Eq.to_eq_map(custom_eq)

    %{
      eq?: fn
        %__MODULE__{value: a}, %__MODULE__{value: b} -> custom_eq.eq?.(a, b)
      end,
      not_eq?: fn
        %__MODULE__{value: a}, %__MODULE__{value: b} -> custom_eq.not_eq?.(a, b)
      end
    }
  end

  @spec lift_ord(Funx.Ord.ord_t()) :: Funx.Ord.ord_map()
  def lift_ord(custom_ord) do
    custom_ord = Funx.Ord.to_ord_map(custom_ord)

    %{
      lt?: fn
        %__MODULE__{value: v1}, %__MODULE__{value: v2} ->
          custom_ord.lt?.(v1, v2)
      end,
      le?: fn
        %__MODULE__{value: v1}, %__MODULE__{value: v2} ->
          custom_ord.le?.(v1, v2)
      end,
      gt?: fn
        %__MODULE__{value: v1}, %__MODULE__{value: v2} ->
          custom_ord.gt?.(v1, v2)
      end,
      ge?: fn
        %__MODULE__{value: v1}, %__MODULE__{value: v2} ->
          custom_ord.ge?.(v1, v2)
      end
    }
  end
end

defimpl Funx.Monad, for: Funx.Monad.Identity do
  alias Funx.Monad.Identity

  @spec map(Identity.t(a), (a -> b)) :: Identity.t(b) when a: term(), b: term()
  def map(%Identity{value: value}, func) do
    Identity.pure(func.(value))
  end

  @spec ap(Identity.t((a -> b)), Identity.t(a)) :: Identity.t(b) when a: term(), b: term()
  def ap(%Identity{value: func}, %Identity{value: value}) do
    Identity.pure(func.(value))
  end

  @spec bind(Identity.t(a), (a -> Identity.t(b))) :: Identity.t(b) when a: term(), b: term()
  def bind(%Identity{value: value}, func) do
    func.(value)
  end
end

defimpl String.Chars, for: Funx.Monad.Identity do
  alias Funx.Monad.Identity

  def to_string(%Identity{value: value}), do: "Identity(#{value})"
end

defimpl Funx.Eq.Protocol, for: Funx.Monad.Identity do
  alias Funx.Monad.Identity
  alias Funx.Eq.Protocol

  @spec eq?(Identity.t(a), Identity.t(a)) :: boolean() when a: term()
  def eq?(%Identity{value: v1}, %Identity{value: v2}), do: Protocol.eq?(v1, v2)

  @spec not_eq?(Identity.t(a), Identity.t(a)) :: boolean() when a: term()
  def not_eq?(%Identity{value: v1}, %Identity{value: v2}), do: Protocol.not_eq?(v1, v2)
end

defimpl Funx.Ord.Protocol, for: Funx.Monad.Identity do
  alias Funx.Ord.Protocol
  alias Funx.Monad.Identity

  @spec lt?(Identity.t(a), Identity.t(a)) :: boolean() when a: term()
  def lt?(%Identity{value: v1}, %Identity{value: v2}), do: Protocol.lt?(v1, v2)

  @spec le?(Identity.t(a), Identity.t(a)) :: boolean() when a: term()
  def le?(%Identity{value: v1}, %Identity{value: v2}), do: Protocol.le?(v1, v2)

  @spec gt?(Identity.t(a), Identity.t(a)) :: boolean() when a: term()
  def gt?(%Identity{value: v1}, %Identity{value: v2}), do: Protocol.gt?(v1, v2)

  @spec ge?(Identity.t(a), Identity.t(a)) :: boolean() when a: term()
  def ge?(%Identity{value: v1}, %Identity{value: v2}), do: Protocol.ge?(v1, v2)
end

defimpl Funx.Summarizable, for: Funx.Monad.Identity do
  def summarize(%{value: value}), do: {:identity, Funx.Summarizable.summarize(value)}
end

defimpl Funx.Tappable, for: Funx.Monad.Identity do
  alias Funx.Monad.Identity

  @spec tap(Identity.t(value), (value -> any())) :: Identity.t(value) when value: term()
  def tap(%Identity{value: value} = identity, func) when is_function(func, 1) do
    func.(value)
    identity
  end
end
