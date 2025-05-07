defmodule Funx.Identity do
  @moduledoc """
  The `Funx.Identity` module represents the identity monad, where values are simply wrapped in a structure
  and operations are applied directly to those values.

  This module implements the following protocols:
    - `Funx.Monad`: Implements the `bind/2`, `map/2`, and `ap/2` functions for monadic operations.
    - `Funx.Eq`: Defines equality checks for `Identity` values.
    - `Funx.Ord`: Defines ordering logic for `Identity` values.
    - `String.Chars`: Converts an `Identity` value into a string representation.

  Telemetry Configuration:
    - `:telemetry_enabled` (default: `true`): Enable or disable telemetry.
    - `:telemetry_prefix` (default: `[:funx]`): Set a custom prefix for telemetry events.
  """

  alias Funx.Eq
  alias Funx.Ord

  @enforce_keys [:value]
  defstruct [:value]

  @type t(value) :: %__MODULE__{value: value}

  @doc """
  Creates a new `Identity` value by wrapping a given value.

  ## Examples

      iex> Funx.Identity.pure(5)
      %Funx.Identity{value: 5}
  """
  @spec pure(value) :: t(value) when value: term()
  def pure(value), do: %__MODULE__{value: value}

  @doc """
  Extracts the value from an `Identity`.

  ## Examples

      iex> Funx.Identity.extract(Funx.Identity.pure(5))
      5
  """
  @spec extract(t(value)) :: value when value: term()
  def extract(%__MODULE__{value: value}), do: value

  @spec lift_eq(Eq.Utils.eq_map()) :: Eq.Utils.eq_map()
  def lift_eq(custom_eq) do
    custom_eq = Eq.Utils.to_eq_map(custom_eq)

    %{
      eq?: fn
        %__MODULE__{value: a}, %__MODULE__{value: b} -> custom_eq.eq?.(a, b)
      end,
      not_eq?: fn
        %__MODULE__{value: a}, %__MODULE__{value: b} -> custom_eq.not_eq?.(a, b)
      end
    }
  end

  @spec lift_ord(Ord.Utils.ord_map()) :: Ord.Utils.ord_map()
  def lift_ord(custom_ord) do
    custom_ord = Ord.Utils.to_ord_map(custom_ord)

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

defimpl Funx.Monad, for: Funx.Identity do
  alias Funx.Identity

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

defimpl String.Chars, for: Funx.Identity do
  alias Funx.Identity

  def to_string(%Identity{value: value}), do: "Identity(#{value})"
end

defimpl Funx.Eq, for: Funx.Identity do
  alias Funx.Identity
  alias Funx.Eq

  @spec eq?(Identity.t(a), Identity.t(a)) :: boolean() when a: term()
  def eq?(%Identity{value: v1}, %Identity{value: v2}), do: Eq.eq?(v1, v2)

  @spec not_eq?(Identity.t(a), Identity.t(a)) :: boolean() when a: term()
  def not_eq?(%Identity{value: v1}, %Identity{value: v2}), do: Eq.not_eq?(v1, v2)
end

defimpl Funx.Ord, for: Funx.Identity do
  alias Funx.Ord
  alias Funx.Identity

  @spec lt?(Identity.t(a), Identity.t(a)) :: boolean() when a: term()
  def lt?(%Identity{value: v1}, %Identity{value: v2}), do: Ord.lt?(v1, v2)

  @spec le?(Identity.t(a), Identity.t(a)) :: boolean() when a: term()
  def le?(%Identity{value: v1}, %Identity{value: v2}), do: Ord.le?(v1, v2)

  @spec gt?(Identity.t(a), Identity.t(a)) :: boolean() when a: term()
  def gt?(%Identity{value: v1}, %Identity{value: v2}), do: Ord.gt?(v1, v2)

  @spec ge?(Identity.t(a), Identity.t(a)) :: boolean() when a: term()
  def ge?(%Identity{value: v1}, %Identity{value: v2}), do: Ord.ge?(v1, v2)
end

defimpl Funx.Summarizable, for: Funx.Identity do
  def summarize(%{value: value}), do: {:identity, Funx.Summarizable.summarize(value)}
end
