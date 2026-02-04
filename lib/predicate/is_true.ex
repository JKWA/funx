defmodule Funx.Predicate.IsTrue do
  @moduledoc """
  Predicate that checks if a value is `true`.

  This is a convenience predicate for checking boolean flags.
  Uses strict equality (`== true`), not truthiness.

  ## Examples

      use Funx.Predicate

      # Check if a flag is true
      pred do
        check [:poison, :active], IsTrue
      end

      # Equivalent to
      pred do
        check [:poison, :active], fn active -> active == true end
      end
  """

  @behaviour Funx.Predicate.Dsl.Behaviour

  @impl true
  def pred(_opts) do
    fn value -> value == true end
  end
end
