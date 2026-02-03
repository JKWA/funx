defmodule Funx.Predicate.MaxLength do
  @moduledoc """
  Predicate that checks if a string does not exceed a maximum length.

  Options

  - `:max` (required)
    Maximum length (integer).

  ## Examples

      use Funx.Predicate

      # Check if name is at most 100 characters
      pred do
        check :name, {MaxLength, max: 100}
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
    max = Keyword.fetch!(opts, :max)

    fn
      string when is_binary(string) -> String.length(string) <= max
      _non_string -> false
    end
  end
end
