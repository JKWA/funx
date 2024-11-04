defmodule Examples.RideValidationMonad do
  @moduledoc """
  The `Examples.RideValidationMonad` module demonstrates how to manage ride operations using the `Either` monad from the `Monex` library,
  with a focus on validating multiple conditions for a patron before allowing them to take a ride.

  This module showcases how to:
  - Use `Either.validate/2` to validate multiple conditions in a single step.
  - Chain monadic operations using functions like `bind/2`, `map/2`, and `ap/2`.
  - Handle errors (via `Left`) when validation fails, ensuring that only patrons with valid height and ticket availability can take a ride.

  The validation approach simplifies the checking of multiple conditions, making the code cleaner and easier to read.

  ### Key Functions:
  - `register_patron/3`: Registers a new patron, wrapping them in the `Either` monad.
  - `check_valid_height/1`: Validates a patron’s height.
  - `check_ticket_availability/1`: Checks if the patron has enough tickets.
  - `validate_patron/1`: Validates both height and ticket availability using `Either.validate/2`.
  - `take_ride/1`: Chains the validation and ticket deduction using monadic operations.
  - `add_ticket/1`: Adds a ticket to the patron using function application in the monad.
  """

  import Monex.Monad, only: [ap: 2, bind: 2, map: 2]

  alias Monex.Either
  alias Examples.Patron

  @type either_t :: Either.t(String.t(), Patron.t())

  @doc """
  Registers a new patron with the given name, height, and number of tickets, returning the result wrapped in the `Either` monad.

  ## Examples

      iex> patron = Examples.RideValidationMonad.register_patron("John", 170, 2)
      %Monex.Either.Right{value: %Examples.Patron{name: "John", height: 170, tickets: 2}}

  """
  @spec register_patron(String.t(), integer(), integer()) :: either_t
  def register_patron(name, height, tickets) do
    Either.pure(Patron.new(name, height, tickets))
  end

  @doc """
  Checks if the patron’s height is valid (between 150 and 200 cm). If valid, returns `Right(patron)`; otherwise, returns `Left("Patron's height is not valid")`.

  ## Examples

      iex> patron = Examples.RideValidationMonad.register_patron("John", 170, 2)
      iex> Examples.RideValidationMonad.check_valid_height(patron)
      %Monex.Either.Right{value: %Examples.Patron{...}}

      iex> patron = Examples.RideValidationMonad.register_patron("Shorty", 140, 1)
      iex> Examples.RideValidationMonad.check_valid_height(patron)
      %Monex.Either.Left{left: "Patron's height is not valid"}

  """
  @spec check_valid_height(Patron.t()) :: either_t
  def check_valid_height(patron) do
    patron
    |> Either.lift_predicate(&Patron.valid_height?/1, fn -> "Patron's height is not valid" end)
  end

  @doc """
  Checks if the patron has enough tickets (at least 1). If the patron has tickets, returns `Right(patron)`; otherwise, returns `Left("Patron is out of tickets")`.

  ## Examples

      iex> patron = Examples.RideValidationMonad.register_patron("John", 170, 2)
      iex> Examples.RideValidationMonad.check_ticket_availability(patron)
      %Monex.Either.Right{value: %Examples.Patron{...}}

      iex> patron = Examples.RideValidationMonad.register_patron("Ticketless", 180, 0)
      iex> Examples.RideValidationMonad.check_ticket_availability(patron)
      %Monex.Either.Left{left: "Patron is out of tickets"}

  """
  @spec check_ticket_availability(Patron.t()) :: either_t
  def check_ticket_availability(patron) do
    patron
    |> Either.lift_predicate(&Patron.has_ticket?/1, fn -> "Patron is out of tickets" end)
  end

  @doc """
  Validates that the patron meets all conditions (valid height and ticket availability) using `Either.validate/2`.
  If all conditions pass, it returns `Right(patron)`; otherwise, returns `Left` with the appropriate validation error.

  This function demonstrates the use of `Either.validate/2` to combine multiple validation functions.

  ## Examples

      iex> patron = Examples.RideValidationMonad.register_patron("John", 170, 2)
      iex> Examples.RideValidationMonad.validate_patron(patron)
      %Monex.Either.Right{value: %Examples.Patron{...}}

      iex> patron = Examples.RideValidationMonad.register_patron("Shorty", 140, 1)
      iex> Examples.RideValidationMonad.validate_patron(patron)
      %Monex.Either.Left{left: "Patron's height is not valid"}

  """
  @spec validate_patron(Patron.t()) :: either_t
  def validate_patron(patron) do
    patron
    |> Either.validate([&check_valid_height/1, &check_ticket_availability/1])
  end

  @doc """
  Validates the patron and, if successful, decrements the number of tickets they have. If validation fails, returns the `Left` value with the appropriate error message.

  ## Examples

      iex> patron = Examples.RideValidationMonad.register_patron("John", 170, 2)
      iex> Examples.RideValidationMonad.take_ride(patron)
      %Monex.Either.Right{value: %Examples.Patron{tickets: 1}}

      iex> patron = Examples.RideValidationMonad.register_patron("Shorty", 140, 2)
      iex> Examples.RideValidationMonad.take_ride(patron)
      %Monex.Either.Left{left: "Patron's height is not valid"}

  """
  @spec take_ride(either_t) :: either_t
  def take_ride(patron) do
    patron
    |> bind(&validate_patron/1)
    |> map(&Patron.decrement_ticket/1)
  end

  @doc """
  Adds a ticket to the patron using function application in the `Either` monad.

  ## Examples

      iex> patron = Examples.RideValidationMonad.register_patron("John", 170, 2)
      iex> Examples.RideValidationMonad.add_ticket(patron)
      %Monex.Either.Right{value: %Examples.Patron{tickets: 3}}

  """
  @spec add_ticket(either_t) :: either_t
  def add_ticket(patron) do
    Either.pure(&Patron.increment_ticket/1)
    |> ap(patron)
  end
end
