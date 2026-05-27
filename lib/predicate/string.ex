defmodule Funx.Predicate.String do
  @moduledoc """
  Predicate that checks if a value is a string (binary).

  Options

  None required.

  ## Examples

      use Funx.Predicate

      alias Funx.Predicate.String

      # Check if name is a string
      pred do
        check :name, String
      end

      # Combined with other predicates
      pred do
        check :email, String
        check :email, Pattern
      end
  """

  @behaviour Funx.Predicate.Dsl.Behaviour

  @impl true
  def pred(_opts \\ []) do
    fn value -> is_binary(value) end
  end
end
