defmodule Funx.Predicate.Pattern do
  @moduledoc """
  Predicate that checks if a string matches a regular expression pattern.

  Returns false for non-strings.

  Options

  - `:regex` (required)
    Regular expression pattern (Regex.t()).

  ## Examples

      use Funx.Predicate

      alias Funx.Predicate.Pattern

      # Check if code matches pattern
      pred do
        check :code, {Pattern, regex: ~r/^[A-Z]{3}$/}
      end

      # Combined with other predicates
      pred do
        check :email, Required
        check :email, {Pattern, regex: ~r/@/}
      end
  """

  @behaviour Funx.Predicate.Dsl.Behaviour

  @impl true
  def pred(opts) do
    regex = Keyword.fetch!(opts, :regex)

    fn
      string when is_binary(string) -> Regex.match?(regex, string)
      _non_string -> false
    end
  end
end
