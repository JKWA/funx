defmodule Funx.Predicate.MinLength do
  @moduledoc """
  Predicate that checks if a string meets a minimum length requirement.

  Options

  - `:min` (required)
    Minimum length (integer).

  ## Examples

      use Funx.Predicate

      # Check if name is at least 2 characters
      pred do
        check :name, {MinLength, min: 2}
      end

      # Combined with other predicates
      pred do
        check :password, {MinLength, min: 8}
        check :password, {MaxLength, max: 128}
      end
  """

  @behaviour Funx.Predicate.Dsl.Behaviour

  @impl true
  def pred(opts) do
    min = Keyword.fetch!(opts, :min)

    fn
      string when is_binary(string) -> String.length(string) >= min
      _non_string -> false
    end
  end
end
