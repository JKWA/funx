defmodule Funx.Predicate.Atom do
  @moduledoc """
  Predicate that checks if a value is an atom.

  Options

  None required.

  ## Examples

      use Funx.Predicate

      alias Funx.Predicate.Atom

      # Check if status is an atom
      pred do
        check :status, Atom
      end

      # Combined with other predicates
      pred do
        check :type, Atom
        check :type, {In, values: [:user, :admin, :guest]}
      end
  """

  @behaviour Funx.Predicate.Dsl.Behaviour

  @impl true
  def pred(_opts \\ []) do
    fn value -> is_atom(value) end
  end
end
