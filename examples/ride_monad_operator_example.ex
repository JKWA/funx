defmodule Examples.RideMonadOperator do
  @moduledoc """
  The `Examples.RideMonadOperator` module demonstrates how to use monadic operators from the `Monex` library to manage ride operations.
  These operators provide a more concise syntax for chaining operations, simplifying monadic code.

  The key operators used in this module are:
  - `~>>`: Chains together monadic operations, like `bind/2`.
  - `~>`: Maps a function over a monadic value, like `map/2`.
  - `<<~`: Applies a function to a monadic value, like `ap/2`.

  ### Key Functions:
  - `register_patron/3`: Registers a new patron and wraps them in the `Either` monad.
  - `check_valid_height/1`: Checks if the patron’s height is valid using monadic operators.
  - `check_ticket_availability/1`: Checks if the patron has enough tickets using monadic operators.
  - `take_ride/1`: Chains together height and ticket validations and decrements the patron’s ticket count.
  - `add_ticket/1`: Adds a ticket to the patron using function application via monadic operators.
  """

  import Monex.Operators, only: [~>: 2, ~>>: 2, <<~: 2]

  alias Monex.Either
  alias Examples.Patron

  @type either_t :: Either.t(String.t(), Patron.t())

  @doc """
  Registers a new patron with the given name, height, and number of tickets, returning the result wrapped in the `Either` monad.

  ## Examples

      iex> patron = Examples.RideMonadOperator.register_patron("John", 170, 2)
      %Monex.Either.Right{value: %Examples.Patron{name: "John", height: 170, tickets: 2}}

  """
  @spec register_patron(String.t(), integer(), integer()) :: either_t()
  def register_patron(name, height, tickets) do
    Either.pure(Patron.new(name, height, tickets))
  end

  @doc """
  Checks if the patron’s height is valid (between 150 and 200 cm) using the `Either` monad.
  If valid, returns `Right(patron)`; otherwise, returns `Left("Patron's height is not valid")`.

  ## Examples

      iex> patron = Examples.RideMonadOperator.register_patron("John", 170, 2)
      iex> Examples.RideMonadOperator.check_valid_height(patron)
      %Monex.Either.Right{value: %Examples.Patron{...}}

      iex> patron = Examples.RideMonadOperator.register_patron("Shorty", 140, 1)
      iex> Examples.RideMonadOperator.check_valid_height(patron)
      %Monex.Either.Left{left: "Patron's height is not valid"}

  """
  @spec check_valid_height(either_t()) :: either_t()
  def check_valid_height(patron) do
    patron
    |> Either.lift_predicate(&Patron.valid_height?/1, fn -> "Patron's height is not valid" end)
  end

  @doc """
  Checks if the patron has enough tickets (at least 1) using the `Either` monad.
  If the patron has tickets, returns `Right(patron)`; otherwise, returns `Left("Patron is out of tickets")`.

  ## Examples

      iex> patron = Examples.RideMonadOperator.register_patron("John", 170, 2)
      iex> Examples.RideMonadOperator.check_ticket_availability(patron)
      %Monex.Either.Right{value: %Examples.Patron{...}}

      iex> patron = Examples.RideMonadOperator.register_patron("Ticketless", 180, 0)
      iex> Examples.RideMonadOperator.check_ticket_availability(patron)
      %Monex.Either.Left{left: "Patron is out of tickets"}

  """
  @spec check_ticket_availability(either_t()) :: either_t()
  def check_ticket_availability(patron) do
    patron
    |> Either.lift_predicate(&Patron.has_ticket?/1, fn -> "Patron is out of tickets" end)
  end

  @doc """
  Chains together height and ticket validations, and if both pass, decrements the patron's ticket count using monadic operators.

  This function uses the `~>>` operator to bind successive validations, and the `~>` operator to apply a function that decrements the ticket count.

  ## Examples

      iex> patron = Examples.RideMonadOperator.register_patron("John", 170, 2)
      iex> Examples.RideMonadOperator.take_ride(patron)
      %Monex.Either.Right{value: %Examples.Patron{tickets: 1}}

      iex> patron = Examples.RideMonadOperator.register_patron("Shorty", 140, 2)
      iex> Examples.RideMonadOperator.take_ride(patron)
      %Monex.Either.Left{left: "Patron's height is not valid"}

  """
  @spec take_ride(either_t()) :: either_t()
  def take_ride(patron) do
    patron
    ~>> (&check_valid_height/1)
    ~>> (&check_ticket_availability/1)
    ~> (&Patron.decrement_ticket/1)
  end

  @doc """
  Adds a ticket to the patron using function application in the `Either` monad via the `<<~` operator.

  ## Examples

      iex> patron = Examples.RideMonadOperator.register_patron("John", 170, 2)
      iex> Examples.RideMonadOperator.add_ticket(patron)
      %Monex.Either.Right{value: %Examples.Patron{tickets: 3}}

  """
  @spec add_ticket(either_t()) :: either_t()
  def add_ticket(patron) do
    Either.pure(&Patron.increment_ticket/1)
    <<~ patron
  end
end
