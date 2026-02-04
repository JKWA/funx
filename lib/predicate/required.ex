defmodule Funx.Predicate.Required do
  @moduledoc """
  Predicate that checks if a value is present (not nil and not empty string).

  This predicate returns true for all values except:
  - `nil`
  - `""` (empty string)

  Note that falsy values like `0`, `false`, and `[]` are considered present.

  Options

  None required.

  ## Examples

      use Funx.Predicate

      alias Funx.Predicate.Required

      # Check if name has a value
      pred do
        check :name, Required
      end

      # Different from truthy - false and 0 pass
      pred do
        check :enabled, Required  # false passes
        check :count, Required    # 0 passes
      end
  """

  @behaviour Funx.Predicate.Dsl.Behaviour

  @impl true
  def pred(_opts \\ []) do
    fn value ->
      not is_nil(value) and value != ""
    end
  end
end
