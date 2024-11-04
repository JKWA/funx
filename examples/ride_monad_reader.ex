defmodule Examples.RideMonadReader do
  @moduledoc """
  Provides a validation system for amusement park rides using the Reader monad
  to manage environment-based configuration.

  This module enables dynamic configuration for height requirements and ticket
  availability, allowing flexible, context-based validation for each ride.

  ## Example Usage

      # Define two different ride configurations
      child_config = %{min_height: 80, max_height: 160}
      adult_config = %{min_height: 150, max_height: 220}

      # Register a patron with specific height and ticket count
      alice = Examples.RideMonadReader.register_patron("Alice", 140, 2)

      # Prepare the ride validation for Alice
      alice_ride = Examples.RideMonadReader.take_ride(alice)

      # Running the validation with the child ride configuration
      alice_ride |> Monex.Reader.run(child_config)
      # Expected Output:
      # %Monex.Either.Right{
      #   value: %Examples.Patron{name: "Alice", height: 140, tickets: 1}
      # }

      # Running the validation with the adult ride configuration
      alice_ride |> Monex.Reader.run(adult_config)
      # Expected Output:
      # %Monex.Either.Left{left: ["Patron's height is not valid for this ride"]}
  """

  import Monex.Monad, only: [map: 2]
  import Monex.Reader

  alias Monex.Either
  alias Examples.Patron

  @doc """
  Registers a new patron with the given `name`, `height`, and `tickets`.

  Returns a `Patron` struct with the provided information.
  """
  def register_patron(name, height, tickets) do
    Patron.new(name, height, tickets)
  end

  @doc """
  Creates a ride configuration map with `min_height` and `max_height` values.

  This configuration will be used to dynamically validate a patron's eligibility
  based on height requirements.
  """
  def create_configuration(min_height, max_height) do
    %{min_height: min_height, max_height: max_height}
  end

  @doc """
  Checks if the given `patron` meets the height requirements defined in the environment.

  Retrieves the `min_height` and `max_height` from the environment using `ask`
  and calls `validate_height/3` to check if the patron's height falls within
  the specified range.
  """
  def check_valid_height(patron) do
    asks(fn %{min_height: min_height, max_height: max_height} ->
      validate_height(patron, min_height, max_height)
    end)
  end

  @doc false
  defp validate_height(patron, min_height, max_height) do
    Either.lift_predicate(
      patron,
      fn p -> p.height >= min_height and p.height <= max_height end,
      fn -> "Patron's height is not valid for this ride" end
    )
  end

  @doc """
  Checks if the given `patron` has tickets available to take the ride.

  Uses the `Either.lift_predicate` function to verify the patron's ticket
  availability, returning an error if no tickets remain.
  """
  def check_ticket_availability(patron) do
    Either.lift_predicate(
      patron,
      &Patron.has_ticket?/1,
      fn -> "Patron is out of tickets" end
    )
  end

  @doc """
  Validates a `patron` based on the environment's height and ticket requirements.

  Uses `check_valid_height/1` and `check_ticket_availability/1` to determine
  eligibility, injecting the environment using `run` to adapt to the current
  configuration.
  """
  def validate_patron(patron) do
    asks(fn env ->
      Either.validate(patron, [
        fn p -> run(check_valid_height(p), env) end,
        &check_ticket_availability/1
      ])
    end)
  end

  @doc """
  Attempts to take a ride with the given `patron`, decrementing a ticket if eligible.

  Runs `validate_patron/1` to check eligibility and, if successful, decrements the
  patron's ticket count. The validation logic adapts based on the current environment.
  """
  def take_ride(patron) do
    asks(fn env ->
      validate_patron(patron)
      |> run(env)
      |> map(&Patron.decrement_ticket/1)
    end)
  end
end
