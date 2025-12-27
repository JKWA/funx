defmodule Funx.Eq.Dsl.Behaviour do
  @moduledoc """
  Behaviour for custom equality logic in the Eq DSL.

  Implement this behaviour to define reusable Eq comparators that can be
  used with `on` directives in the DSL without implementing the Eq protocol.

  This is useful for teams that want to avoid teaching developers about protocols,
  or want struct-specific equality without global protocol implementations.

  ## Basic Example

      defmodule UserById do
        @behaviour Funx.Eq.Dsl.Behaviour

        @impl true
        def eq(_opts) do
          Funx.Eq.Utils.contramap(&(&1.id))
        end
      end

      # In DSL
      use Funx.Eq.Dsl

      eq do
        on UserById  # Compares by id
      end

  ## With Options

      defmodule UserByName do
        @behaviour Funx.Eq.Dsl.Behaviour

        @impl true
        def eq(opts) do
          case_sensitive = Keyword.get(opts, :case_sensitive, true)

          if case_sensitive do
            Funx.Eq.Utils.contramap(&(&1.name))
          else
            Funx.Eq.Utils.contramap(fn u -> String.downcase(u.name) end)
          end
        end
      end

      # In DSL
      eq do
        on UserByName, case_sensitive: false
      end

  ## Why Use This Instead of Protocols?

  - **Simpler**: Just one function returning an Eq map
  - **No protocol knowledge required**: Easier for team onboarding
  - **Module-specific**: Override struct equality without global protocol
  - **Options support**: Built-in support for configuration

  The returned Eq map typically uses `Funx.Eq.Utils.contramap/2` to build
  projection-based equality, but can implement any custom comparison logic.
  """

  @doc """
  Returns an Eq map for comparison.

  Takes options and returns an Eq map (with `:eq?` and `:not_eq?` functions).

  ## Arguments

    * `opts` - Keyword list of options passed from the DSL

  ## Return Value

  An Eq map with the structure:

      %{
        eq?: (any(), any() -> boolean()),
        not_eq?: (any(), any() -> boolean())
      }

  ## Examples

      # Simple projection-based equality
      def eq(_opts) do
        Funx.Eq.Utils.contramap(&(&1.id))
      end

      # With options
      def eq(opts) do
        field = Keyword.get(opts, :field, :id)
        Funx.Eq.Utils.contramap(&Map.get(&1, field))
      end

      # Custom comparison logic
      def eq(_opts) do
        %{
          eq?: fn a, b -> normalize(a) == normalize(b) end,
          not_eq?: fn a, b -> normalize(a) != normalize(b) end
        }
      end

  Most implementations use `Funx.Eq.Utils.contramap/2` for projection-based
  equality, which handles the Eq map creation automatically.
  """
  @callback eq(opts :: keyword()) :: Funx.Eq.Utils.eq_map()
end
