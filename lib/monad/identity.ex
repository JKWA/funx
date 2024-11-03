defmodule Monex.Identity do
  @moduledoc """
  The `Monex.Identity` module represents the identity monad, where values are simply wrapped in a structure
  and operations are applied directly to those values.

  This module implements the following protocols:
    - `Monex.Monad`: Implements the `bind/2`, `map/2`, and `ap/2` functions for monadic operations.
    - `Monex.Eq`: Defines equality checks for `Identity` values.
    - `Monex.Ord`: Defines ordering logic for `Identity` values.
    - `String.Chars`: Converts an `Identity` value into a string representation.

  Telemetry Events:
    - `[:monex, :identity, :ap]`: Emitted when the `ap` operation is called.
    - `[:monex, :identity, :bind]`: Emitted when the `bind` operation is called.
    - `[:monex, :identity, :map]`: Emitted when the `map` operation is called.

  Telemetry Configuration:
    - `:telemetry_enabled` (default: `true`): Enable or disable telemetry.
    - `:telemetry_prefix` (default: `[:monex]`): Set a custom prefix for telemetry events.
  """

  alias Monex.TelemetryUtils

  @enforce_keys [:value]
  defstruct [:value]

  @type t(value) :: %__MODULE__{value: value}

  @doc """
  Creates a new `Identity` value by wrapping a given value.

  ## Examples

      iex> Monex.Identity.pure(5)
      %Monex.Identity{value: 5}
  """
  @spec pure(value) :: t(value) when value: term()
  def pure(value), do: %__MODULE__{value: value}

  @doc """
  Extracts the value from an `Identity`.

  ## Examples

      iex> Monex.Identity.extract(Monex.Identity.pure(5))
      5
  """
  @spec extract(t(value)) :: value when value: term()
  def extract(%__MODULE__{value: value}), do: value

  def get_ord(custom_ord) do
    %{
      lt?: fn
        %__MODULE__{value: v1}, %__MODULE__{value: v2} -> custom_ord.lt?.(v1, v2)
      end,
      le?: fn a, b -> not get_ord(custom_ord).gt?.(a, b) end,
      gt?: fn a, b -> get_ord(custom_ord).lt?.(b, a) end,
      ge?: fn a, b -> not get_ord(custom_ord).lt?.(a, b) end
    }
  end

  defimpl Monex.Monad do
    alias Monex.Identity

    def bind(%Identity{value: value}, func) do
      start_time = System.monotonic_time()
      result = func.(value)

      if Application.get_env(:monex, :telemetry_enabled, true) do
        :telemetry.execute(
          Application.get_env(:monex, :telemetry_prefix, [:monex]) ++ [:identity, :bind],
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

      if Application.get_env(:monex, :telemetry_enabled, true) do
        :telemetry.execute(
          Application.get_env(:monex, :telemetry_prefix, [:monex]) ++ [:identity, :map],
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

      if Application.get_env(:monex, :telemetry_enabled, true) do
        :telemetry.execute(
          Application.get_env(:monex, :telemetry_prefix, [:monex]) ++ [:identity, :ap],
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
    alias Monex.Identity

    def to_string(%Identity{value: value}), do: "Identity(#{value})"
  end

  defimpl Monex.Eq do
    alias Monex.Identity

    @doc """
    Returns `true` if the inner values of two `Identity` instances are equal, otherwise returns `false`.
    """
    def eq?(%Identity{value: v1}, %Identity{value: v2}) do
      v1 == v2
    end

    def get_eq(eq_for_value) do
      %{
        eq?: fn
          %Identity{value: a}, %Identity{value: b} -> eq_for_value[:eq?].(a, b)
          _, _ -> false
        end
      }
    end
  end

  defimpl Monex.Ord do
    alias Monex.Identity

    def lt?(%Identity{value: v1}, %Identity{value: v2}) do
      v1 < v2
    end

    def le?(a, b), do: not Monex.Ord.gt?(a, b)
    def gt?(a, b), do: Monex.Ord.lt?(b, a)
    def ge?(a, b), do: not Monex.Ord.lt?(a, b)
  end
end
