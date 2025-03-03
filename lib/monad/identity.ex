defmodule Funx.Identity do
  @moduledoc """
  The `Funx.Identity` module represents the identity monad, where values are simply wrapped in a structure
  and operations are applied directly to those values.

  This module implements the following protocols:
    - `Funx.Monad`: Implements the `bind/2`, `map/2`, and `ap/2` functions for monadic operations.
    - `Funx.Eq`: Defines equality checks for `Identity` values.
    - `Funx.Ord`: Defines ordering logic for `Identity` values.
    - `String.Chars`: Converts an `Identity` value into a string representation.

  Telemetry Events:
    - `[:funx, :identity, :ap]`: Emitted when the `ap` operation is called.
    - `[:funx, :identity, :bind]`: Emitted when the `bind` operation is called.
    - `[:funx, :identity, :map]`: Emitted when the `map` operation is called.

  Telemetry Configuration:
    - `:telemetry_enabled` (default: `true`): Enable or disable telemetry.
    - `:telemetry_prefix` (default: `[:funx]`): Set a custom prefix for telemetry events.
  """

  alias Funx.TelemetryUtils

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

  def lift_eq(eq_for_value) do
    %{
      eq?: fn
        %__MODULE__{value: a}, %__MODULE__{value: b} -> eq_for_value[:eq?].(a, b)
        _, _ -> false
      end
    }
  end

  def lift_ord(custom_ord) do
    %{
      lt?: fn
        %__MODULE__{value: v1}, %__MODULE__{value: v2} -> custom_ord.lt?.(v1, v2)
      end,
      le?: fn a, b -> not lift_ord(custom_ord).gt?.(a, b) end,
      gt?: fn a, b -> lift_ord(custom_ord).lt?.(b, a) end,
      ge?: fn a, b -> not lift_ord(custom_ord).lt?.(a, b) end
    }
  end

  defimpl Funx.Monad do
    alias Funx.Identity

    def bind(%Identity{value: value}, func) do
      start_time = System.monotonic_time()
      result = func.(value)

      if Application.get_env(:funx, :telemetry_enabled, true) do
        :telemetry.execute(
          Application.get_env(:funx, :telemetry_prefix, [:funx]) ++ [:identity, :bind],
          %{duration: System.monotonic_time() - start_time},
          %{
            initial_value: TelemetryUtils.summarize(value),
            transformed_value: TelemetryUtils.summarize(result.value)
          }
        )
      end

      result
    end

    def map(%Identity{value: value}, func) do
      start_time = System.monotonic_time()
      result = Identity.pure(func.(value))

      if Application.get_env(:funx, :telemetry_enabled, true) do
        :telemetry.execute(
          Application.get_env(:funx, :telemetry_prefix, [:funx]) ++ [:identity, :map],
          %{duration: System.monotonic_time() - start_time},
          %{
            initial_value: TelemetryUtils.summarize(value),
            transformed_value: TelemetryUtils.summarize(result.value)
          }
        )
      end

      result
    end

    def ap(%Identity{value: func}, %Identity{value: value}) do
      start_time = System.monotonic_time()
      result = Identity.pure(func.(value))

      if Application.get_env(:funx, :telemetry_enabled, true) do
        :telemetry.execute(
          Application.get_env(:funx, :telemetry_prefix, [:funx]) ++ [:identity, :ap],
          %{duration: System.monotonic_time() - start_time},
          %{
            initial_value: TelemetryUtils.summarize(value),
            transformed_value: TelemetryUtils.summarize(result.value)
          }
        )
      end

      result
    end
  end

  defimpl String.Chars do
    alias Funx.Identity

    def to_string(%Identity{value: value}), do: "Identity(#{value})"
  end
end

defimpl Funx.Eq, for: Funx.Identity do
  alias Funx.Identity
  alias Funx.Eq

  def eq?(%Identity{value: v1}, %Identity{value: v2}), do: Eq.eq?(v1, v2)

  def not_eq?(%Identity{value: v1}, %Identity{value: v2}), do: Eq.not_eq?(v1, v2)
end

defimpl Funx.Ord, for: Funx.Identity do
  alias Funx.Ord
  alias Funx.Identity

  def lt?(%Identity{value: v1}, %Identity{value: v2}), do: Ord.lt?(v1, v2)
  def le?(%Identity{value: v1}, %Identity{value: v2}), do: Ord.le?(v1, v2)
  def gt?(%Identity{value: v1}, %Identity{value: v2}), do: Ord.gt?(v1, v2)
  def ge?(%Identity{value: v1}, %Identity{value: v2}), do: Ord.ge?(v1, v2)
end
