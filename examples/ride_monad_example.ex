defmodule Examples.RideMonad do
  @moduledoc """
  The `Examples.RideMonad` module demonstrates how to handle ride management using monads with the `Monex` library.
  Monads help chain together operations like validation and ticket management, especially when dealing with success (`Right`) and failure (`Left`) cases.

  This module replaces typical Elixir pattern matching with monads, providing a way to elegantly handle sequences of operations, where each operation can succeed or fail.

  The key functions in this module:
  - `register_patron/3`: Registers a new patron, wrapping them in the `Either` monad.
  - `check_valid_height/1`: Validates a patron’s height, returning either success (`Right`) or failure (`Left`).
  - `check_ticket_availability/1`: Checks if the patron has enough tickets, using the same success/failure monad approach.
  - `take_ride/1`: Combines validations and ticket deduction using monadic binding (`bind`).
  - `add_ticket/1`: Adds a ticket to the patron using function application in the monad.

  The `Either` monad is used to handle success (`Right`) and failure (`Left`) results in all functions.
  """

  import Monex.Monad, only: [ap: 2, bind: 2, map: 2]

  alias Monex.Either
  alias Examples.Patron

  @type either_t :: Either.t(String.t(), Patron.t())

  @doc """
  Registers a new patron with the given name, height, and number of tickets, returning the result wrapped in the `Either` monad.

  ## Examples

      iex> patron = Examples.RideMonad.register_patron("John", 170, 2)
      %Monex.Either.Right{value: %Examples.Patron{name: "John", height: 170, tickets: 2}}

  """
  @spec register_patron(String.t(), integer(), integer()) :: either_t()
  def register_patron(name, height, tickets) do
    Either.pure(Patron.new(name, height, tickets))
  end

  @doc """
  Checks if the patron’s height is valid (between 150 and 200 cm).
  If the height is valid, returns `Right(patron)`, otherwise returns `Left("Patron's height is not valid")`.

  This function uses `Either.lift_predicate/3` to apply the predicate and handle success or failure.

  ## Examples

      iex> {:ok, patron} = Examples.RideMonad.register_patron("John", 170, 2)
      iex> Examples.RideMonad.check_valid_height(patron)
      %Monex.Either.Right{value: %Examples.Patron{...}}

      iex> {:ok, patron} = Examples.RideMonad.register_patron("Shorty", 140, 1)
      iex> Examples.RideMonad.check_valid_height(patron)
      %Monex.Either.Left{left: "Patron's height is not valid"}

  """
  @spec check_valid_height(either_t()) :: either_t()
  def check_valid_height(patron) do
    patron
    |> Either.lift_predicate(&Patron.valid_height?/1, fn -> "Patron's height is not valid" end)
  end

  @doc """
  Checks if the patron has at least one ticket.
  If the patron has tickets, returns `Right(patron)`, otherwise returns `Left("Patron is out of tickets")`.

  ## Examples

      iex> {:ok, patron} = Examples.RideMonad.register_patron("John", 170, 2)
      iex> Examples.RideMonad.check_ticket_availability(patron)
      %Monex.Either.Right{value: %Examples.Patron{...}}

      iex> {:ok, patron} = Examples.RideMonad.register_patron("Ticketless", 180, 0)
      iex> Examples.RideMonad.check_ticket_availability(patron)
      %Monex.Either.Left{left: "Patron is out of tickets"}

  """
  @spec check_ticket_availability(either_t()) :: either_t()
  def check_ticket_availability(patron) do
    patron
    |> Either.lift_predicate(&Patron.has_ticket?/1, fn -> "Patron is out of tickets" end)
  end

  @doc """
  Validates the patron’s height and ticket availability, and if both checks pass, decrements the patron's ticket count.

  This function demonstrates how to chain monadic operations using `bind`, applying successive computations that depend on the previous result.

  ## Examples

      iex> {:ok, patron} = Examples.RideMonad.register_patron("John", 170, 2)
      iex> Examples.RideMonad.take_ride(patron)
      %Monex.Either.Right{value: %Examples.Patron{tickets: 1}}

      iex> {:ok, patron} = Examples.RideMonad.register_patron("Shorty", 140, 2)
      iex> Examples.RideMonad.take_ride(patron)
      %Monex.Either.Left{left: "Patron's height is not valid"}

  """
  @spec take_ride(either_t()) :: either_t()
  def take_ride(patron) do
    patron
    |> bind(&check_valid_height/1)
    |> bind(&check_ticket_availability/1)
    |> map(&Patron.decrement_ticket/1)
  end

  @doc """
  Adds a ticket to the patron using function application within the `Either` monad.

  ## Examples

      iex> {:ok, patron} = Examples.RideMonad.register_patron("John", 170, 2)
      iex> Examples.RideMonad.add_ticket(patron)
      %Monex.Either.Right{value: %Examples.Patron{tickets: 3}}

  """
  @spec add_ticket(either_t()) :: either_t()
  def add_ticket(patron) do
    Either.pure(&Patron.increment_ticket/1)
    |> ap(patron)
  end
end
