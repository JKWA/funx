defmodule Basic.Ap do
  @moduledoc """
  A module demonstrating the use of `ap` with different monads (`Identity`, `Maybe`, and `Either`)
  for calculating adjusted airspeed based on wind speed and airspeed values.

  This example explores how different monads handle values and computations,
  especially when data might be missing or faulty.
  """

  import Monex.Monad, only: [ap: 2, map: 2]
  alias Monex.{Identity, Maybe, Either}

  @doc """
  Calculates adjusted airspeed by subtracting `wind_speed` from `airspeed`.

  ## Examples

      iex> Basic.Ap.calculate_adjusted_airspeed(100, 50)
      50
  """
  @spec calculate_adjusted_airspeed(integer(), integer()) :: integer()
  def calculate_adjusted_airspeed(airspeed, wind_speed), do: airspeed - wind_speed

  @doc """
  Wraps a partially applied function in the `Identity` monad using the provided `wind_speed`.

  Returns a function that expects `airspeed` to complete the calculation.

  ## Examples

      iex> Basic.Ap.get_wind_adjustment_identity(10)
      %Monex.Identity{value: #Function<...>}
  """
  @spec get_wind_adjustment_identity(integer()) :: Identity.t((integer() -> integer()))
  def get_wind_adjustment_identity(wind_speed) do
    Identity.pure(fn airspeed -> calculate_adjusted_airspeed(airspeed, wind_speed) end)
  end

  @doc """
  Applies `airspeed` to the `Identity`-wrapped wind speed function to calculate adjusted airspeed.

  ## Examples

      iex> Basic.Ap.get_wind_adjustment_identity(10) |> Basic.Ap.calculate_adjusted_airspeed_identity(100)
      %Monex.Identity{value: 90}

  """
  @spec calculate_adjusted_airspeed_identity(Identity.t((integer() -> integer())), integer()) ::
          Identity.t(integer())
  def calculate_adjusted_airspeed_identity(wind_speed_fn, airspeed) do
    wind_speed_fn
    |> ap(Identity.pure(airspeed))
  end

  @doc """
  Wraps a partially applied function in the `Maybe` monad, handling possible `nil` wind speed.

  If `wind_speed` is present, returns `Just` the function; otherwise, returns `Nothing`.

  ## Examples

      iex> Basic.Ap.get_wind_adjustment_maybe(10)
      %Monex.Maybe.Just{value: #Function<...>}

      iex> Basic.Ap.get_wind_adjustment_maybe(nil)
      %Monex.Maybe.Nothing{}
  """
  @spec get_wind_adjustment_maybe(integer() | nil) :: Maybe.t((integer() -> integer()))
  def get_wind_adjustment_maybe(wind_speed) do
    wind_speed
    |> Maybe.from_nil()
    |> map(fn w_speed -> fn airspeed -> calculate_adjusted_airspeed(airspeed, w_speed) end end)
  end

  @doc """
  Applies `airspeed` to the `Maybe`-wrapped wind speed function to calculate adjusted airspeed.
  Returns `Nothing` if either `wind_speed` or `airspeed` is missing.

  ## Examples

      iex> Basic.Ap.get_wind_adjustment_maybe(10) |> Basic.Ap.calculate_adjusted_airspeed_maybe(100)
      %Monex.Maybe.Just{value: 90}

      iex> Basic.Ap.get_wind_adjustment_maybe(nil) |> Basic.Ap.calculate_adjusted_airspeed_maybe(100)
      %Monex.Maybe.Nothing{}

      iex> Basic.Ap.get_wind_adjustment_maybe(10) |> Basic.Ap.calculate_adjusted_airspeed_maybe(nil)
      %Monex.Maybe.Nothing{}
  """
  @spec calculate_adjusted_airspeed_maybe(Maybe.t((integer() -> integer())), integer() | nil) ::
          Maybe.t(integer())
  def calculate_adjusted_airspeed_maybe(wind_speed_fn, airspeed) do
    wind_speed_fn
    |> ap(
      airspeed
      |> Maybe.from_nil()
    )
  end

  @doc """
  Lifts the `Maybe` monad result to the `Either` monad, capturing a message if `wind_speed` is missing.

  If `wind_speed` is present, returns `Right` with the partial function; otherwise, returns `Left` with an error message.

  ## Examples

      iex> Basic.Ap.get_wind_adjustment_either(10)
      %Monex.Either.Right{value: #Function<...>}

      iex> Basic.Ap.get_wind_adjustment_either(nil)
      %Monex.Either.Left{value: "Wind speed not available"}
  """
  @spec get_wind_adjustment_either(integer() | nil) ::
          Either.t(String.t(), (integer() -> integer()))
  def get_wind_adjustment_either(wind_speed) do
    get_wind_adjustment_maybe(wind_speed)
    |> Either.lift_maybe(fn -> "Wind speed not available" end)
  end

  @doc """
  Applies `airspeed` to the `Either`-wrapped wind speed function to calculate adjusted airspeed,
  capturing error messages if either value is missing.

  ## Examples

      iex> Basic.Ap.get_wind_adjustment_either(10) |> Basic.Ap.calculate_adjusted_airspeed_either(100)
      %Monex.Either.Right{value: 90}

      iex> Basic.Ap.get_wind_adjustment_either(nil) |> Basic.Ap.calculate_adjusted_airspeed_either(100)
      %Monex.Either.Left{value: "Wind speed not available"}

      iex> Basic.Ap.get_wind_adjustment_either(10) |> Basic.Ap.calculate_adjusted_airspeed_either(nil)
      %Monex.Either.Left{value: "Air speed not available"}
  """
  @spec calculate_adjusted_airspeed_either(
          Either.t(String.t(), (integer() -> integer())),
          integer() | nil
        ) :: Either.t(String.t(), integer())
  def calculate_adjusted_airspeed_either(wind_speed_fn, airspeed) do
    wind_speed_fn
    |> ap(
      airspeed
      |> Maybe.from_nil()
      |> Either.lift_maybe(fn -> "Air speed not available" end)
    )
  end
end
