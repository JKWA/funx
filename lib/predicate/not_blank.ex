defmodule Funx.Predicate.NotBlank do
  @moduledoc """
  Predicate that checks if a string is not blank (has content after trimming whitespace).

  Options

  None required.

  ## Examples

      use Funx.Predicate

      alias Funx.Predicate.NotBlank

      # Check if name is not blank
      pred do
        check :name, NotBlank
      end

      # Combined with other predicates
      pred do
        check :title, NotBlank
        check :title, {MaxLength, max: 100}
      end
  """

  @behaviour Funx.Predicate.Dsl.Behaviour

  @impl true
  def pred(_opts \\ []) do
    fn
      value when is_binary(value) -> String.trim(value) != ""
      _non_string -> false
    end
  end
end
