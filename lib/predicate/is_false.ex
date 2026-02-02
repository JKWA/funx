defmodule Funx.Predicate.IsFalse do
  @moduledoc """
  Predicate that checks if a value is `false`.

  This is a convenience predicate for checking boolean flags.
  Uses strict equality (`== false`), not falsiness.

  ## Examples

      use Funx.Predicate

      # Check if a flag is false
      pred do
        check [:bleeding, :staunched], {IsFalse, []}
      end

      # Equivalent to
      pred do
        check [:bleeding, :staunched], fn staunched -> staunched == false end
      end

      # Also equivalent to
      pred do
        negate check [:bleeding, :staunched], {IsTrue, []}
      end
  """

  @behaviour Funx.Predicate.Dsl.Behaviour

  @impl true
  def pred(_opts) do
    fn value -> value == false end
  end
end
