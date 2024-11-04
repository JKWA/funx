defmodule Examples.RideEffectMonad do
  @moduledoc """
  The `Examples.RideEffectMonad` module demonstrates how to handle ride management using the `Effect` monad from the `Monex` library.
  This module allows for handling asynchronous tasks, such as validating a patron's height and checking ticket availability, while maintaining a clear, monadic flow for success and failure.

  The key difference from the `Either` monad is that `Effect` handles computations that may involve time delays or asynchronous execution, and those computations are deferred until they are explicitly run.

  ### Key Functions:
  - `register_patron/3`: Registers a new patron and wraps them in the `Effect` monad.
  - `check_valid_height/1`: Validates a patron’s height asynchronously.
  - `check_ticket_availability/1`: Asynchronously checks if the patron has enough tickets.
  - `take_ride/1`: Chains together the validations and ticket deduction asynchronously.
  - `add_ticket/1`: Adds a ticket to the patron asynchronously using function application within the `Effect` monad.

  The use of asynchronous validation introduces a slight delay, represented by `:timer.sleep/1` in the code, to simulate real-world scenarios such as waiting for database lookups or external API calls.
  """

  import Monex.Monad, only: [ap: 2, bind: 2, map: 2]

  alias Monex.Effect
  alias Examples.Patron

  @type effect_t :: Effect.t(String.t(), Patron.t())

  @doc """
  Registers a new patron with the given name, height, and number of tickets, returning the result wrapped in the `Effect` monad.

  ## Examples

      iex> task = Examples.RideEffectMonad.register_patron("John", 170, 2)
      iex> Monex.Effect.run(task)
      %Monex.Either.Right{value: %Examples.Patron{name: "John", height: 170, tickets: 2}}

  """
  @spec register_patron(String.t(), integer(), integer()) :: effect_t()
  def register_patron(name, height, tickets) do
    Effect.pure(Patron.new(name, height, tickets))
  end

  @doc """
  Asynchronously checks if the patron’s height is valid (between 150 and 200 cm). If the height is valid, it returns `Right(patron)`; otherwise, it returns `Left("Patron's height is not valid")`.

  This function uses a simulated delay (`:timer.sleep/1`) to represent an asynchronous validation process.

  ## Examples

      iex> task = Examples.RideEffectMonad.register_patron("John", 170, 2)
      iex> task = Examples.RideEffectMonad.check_valid_height(task)
      iex> Monex.Effect.run(task)
      %Monex.Either.Right{value: %Examples.Patron{...}}

      iex> task = Examples.RideEffectMonad.register_patron("Shorty", 140, 1)
      iex> task = Examples.RideEffectMonad.check_valid_height(task)
      iex> Monex.Effect.run(task)
      %Monex.Either.Left{left: "Patron's height is not valid"}

  """
  @spec check_valid_height(effect_t()) :: effect_t()
  def check_valid_height(patron) do
    patron
    |> Effect.lift_predicate(
      fn p ->
        # Simulate async validation delay
        :timer.sleep(2000)
        Patron.valid_height?(p)
      end,
      fn -> "Patron's height is not valid" end
    )
  end

  @doc """
  Asynchronously checks if the patron has enough tickets (at least 1). If the patron has tickets, it returns `Right(patron)`; otherwise, it returns `Left("Patron is out of tickets")`.

  This function uses a simulated delay (`:timer.sleep/1`) to represent an asynchronous check process.

  ## Examples

      iex> task = Examples.RideEffectMonad.register_patron("John", 170, 2)
      iex> task = Examples.RideEffectMonad.check_ticket_availability(task)
      iex> Monex.Effect.run(task)
      %Monex.Either.Right{value: %Examples.Patron{...}}

      iex> task = Examples.RideEffectMonad.register_patron("Ticketless", 180, 0)
      iex> task = Examples.RideEffectMonad.check_ticket_availability(task)
      iex> Monex.Effect.run(task)
      %Monex.Either.Left{left: "Patron is out of tickets"}

  """
  @spec check_ticket_availability(effect_t()) :: effect_t()
  def check_ticket_availability(patron) do
    patron
    |> Effect.lift_predicate(
      fn p ->
        # Simulate async check delay
        :timer.sleep(2000)
        Patron.has_ticket?(p)
      end,
      fn -> "Patron is out of tickets" end
    )
  end

  @doc """
  Chains together asynchronous validations for the patron’s height and ticket availability, and if both pass, decrements the patron's ticket count.

  This function demonstrates how to chain monadic operations using `bind` and `map` for deferred asynchronous tasks.

  ## Examples

      iex> task = Examples.RideEffectMonad.register_patron("John", 170, 2)
      iex> task = Examples.RideEffectMonad.take_ride(task)
      iex> Monex.Effect.run(task)
      %Monex.Either.Right{value: %Examples.Patron{tickets: 1}}

      iex> task = Examples.RideEffectMonad.register_patron("Shorty", 140, 2)
      iex> task = Examples.RideEffectMonad.take_ride(task)
      iex> Monex.Effect.run(task)
      %Monex.Either.Left{left: "Patron's height is not valid"}

  """
  @spec take_ride(effect_t()) :: effect_t()
  def take_ride(patron) do
    patron
    |> bind(&check_valid_height/1)
    |> bind(&check_ticket_availability/1)
    |> map(&Patron.decrement_ticket/1)
  end

  @doc """
  Adds a ticket to the patron asynchronously using function application within the `Effect` monad.

  ## Examples

      iex> task = Examples.RideEffectMonad.register_patron("John", 170, 2)
      iex> task = Examples.RideEffectMonad.add_ticket(task)
      iex> Monex.Effect.run(task)
      %Monex.Either.Right{value: %Examples.Patron{tickets: 3}}

  """
  @spec add_ticket(effect_t()) :: effect_t()
  def add_ticket(patron) do
    Effect.pure(&Patron.increment_ticket/1)
    |> ap(patron)
  end
end
