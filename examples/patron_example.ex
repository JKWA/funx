defmodule Examples.Patron do
  @moduledoc """
  The `Examples.Patron` module provides an example of how to represent a patron visiting a venue or amusement park.
  It shows how to use Funx’s `Predicate` module to combine and work with multiple conditions in an easy-to-understand way.

  This module covers:

  - Creating a `Patron` with `new/3`.
  - Checking the patron’s height using `too_short?/1`, `too_tall?/1`, and `valid_height?/1`.
  - Checking and adjusting the number of tickets with `has_ticket?/1`, `increment_ticket/1`, and `decrement_ticket/1`.

  You will also learn how to use predicates, a powerful concept in Funx, to validate multiple conditions about a patron.
  """

  alias Funx.Predicate

  defstruct name: "", height: 0, tickets: 0

  @type t :: %__MODULE__{
          name: String.t(),
          height: integer(),
          tickets: integer()
        }

  @doc """
  Creates a new `Patron` with the given `name`, `height`, and number of `tickets`.

  ## Examples

      iex> john = Examples.Patron.new("John", 170, 2)
      %Examples.Patron{name: "John", height: 170, tickets: 2}

  """
  def new(name, height, tickets) do
    %__MODULE__{name: name, height: height, tickets: tickets}
  end

  @doc """
  Checks if the patron is too short (less than 150 cm).

  ## Examples

      iex> john = Examples.Patron.new("John", 140, 2)
      iex> Examples.Patron.too_short?(john)
      true

      iex> jane = Examples.Patron.new("Jane", 160, 1)
      iex> Examples.Patron.too_short?(jane)
      false

  """
  @spec too_short?(t()) :: boolean()
  def too_short?(%__MODULE__{height: height}) do
    height < 150
  end

  @doc """
  Checks if the patron is too tall (more than 200 cm).

  ## Examples

      iex> tall_patron = Examples.Patron.new("Tall Guy", 210, 1)
      iex> Examples.Patron.too_tall?(tall_patron)
      true

      iex> average_patron = Examples.Patron.new("Average Joe", 170, 2)
      iex> Examples.Patron.too_tall?(average_patron)
      false

  """
  @spec too_tall?(t()) :: boolean()
  def too_tall?(%__MODULE__{height: height}) do
    height > 200
  end

  @doc """
  Checks if the patron's height is valid, meaning they are neither too short nor too tall.

  This combines the `too_short?/1` and `too_tall?/1` predicates using Funx's `Predicate.p_and/2` and `Predicate.p_not/1`.

  ## Examples

      iex> short_patron = Examples.Patron.new("Shorty", 140, 1)
      iex> Examples.Patron.valid_height?(short_patron)
      false

      iex> perfect_patron = Examples.Patron.new("Perfect Height", 180, 2)
      iex> Examples.Patron.valid_height?(perfect_patron)
      true

  """
  @spec valid_height?(t()) :: boolean()
  def valid_height?(patron) do
    valid_height_predicate =
      Predicate.p_and(Predicate.p_not(&too_short?/1), Predicate.p_not(&too_tall?/1))

    valid_height_predicate.(patron)
  end

  @doc """
  Checks if the patron has at least one ticket.

  ## Examples

      iex> patron_with_ticket = Examples.Patron.new("Ticket Holder", 180, 1)
      iex> Examples.Patron.has_ticket?(patron_with_ticket)
      true

      iex> patron_no_ticket = Examples.Patron.new("No Ticket", 175, 0)
      iex> Examples.Patron.has_ticket?(patron_no_ticket)
      false

  """
  @spec has_ticket?(t()) :: boolean()
  def has_ticket?(%__MODULE__{tickets: tickets}) do
    tickets > 0
  end

  @doc """
  Increments the number of tickets a patron has by 1.

  ## Examples

      iex> patron = Examples.Patron.new("John", 170, 2)
      iex> patron = Examples.Patron.increment_ticket(patron)
      iex> patron.tickets
      3

  """
  @spec increment_ticket(t()) :: t()
  def increment_ticket(%__MODULE__{tickets: tickets} = patron) do
    %{patron | tickets: tickets + 1}
  end

  @doc """
  Decrements the number of tickets a patron has by 1.

  ## Examples

      iex> patron = Examples.Patron.new("John", 170, 2)
      iex> patron = Examples.Patron.decrement_ticket(patron)
      iex> patron.tickets
      1

  """
  @spec decrement_ticket(t()) :: t()
  def decrement_ticket(%__MODULE__{tickets: tickets} = patron) do
    %{patron | tickets: tickets - 1}
  end
end
