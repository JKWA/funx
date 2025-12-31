defmodule Funx.Ord.Dsl.Behaviour do
  @moduledoc """
  Behaviour for custom ordering logic in the Ord DSL.

  Implement this behaviour to define reusable Ord comparators that can be
  used with `asc` and `desc` directives in the DSL without implementing the Ord protocol.

  This is useful for teams that want to avoid teaching developers about protocols,
  or want struct-specific ordering without global protocol implementations.

  ## Basic Example

      defmodule UserById do
        @behaviour Funx.Ord.Dsl.Behaviour

        @impl true
        def ord(_opts) do
          Funx.Ord.contramap(&(&1.id))
        end
      end

      # In DSL
      use Funx.Ord.Dsl

      ord do
        asc: UserById  # Orders by id ascending
      end

  ## With Options

      defmodule UserByField do
        @behaviour Funx.Ord.Dsl.Behaviour

        @impl true
        def ord(opts) do
          field = Keyword.get(opts, :field, :id)
          Funx.Ord.contramap(&Map.get(&1, field))
        end
      end

      # In DSL
      ord do
        asc: UserByField, field: :name
      end

  ## Why Use This Instead of Protocols?

  - **Simpler**: Just one function returning an Ord map
  - **No protocol knowledge required**: Easier for team onboarding
  - **Module-specific**: Override struct ordering without global protocol
  - **Options support**: Built-in support for configuration

  The returned Ord map typically uses `Funx.Ord.contramap/2` to build
  projection-based ordering, but can implement any custom comparison logic.
  """

  @doc """
  Returns an Ord map for comparison.

  Takes options and returns an Ord map (with `:compare` function).

  ## Arguments

    * `opts` - Keyword list of options passed from the DSL

  ## Return Value

  An Ord map with the structure:

      %{
        compare: (any(), any() -> :lt | :eq | :gt)
      }

  ## Examples

      # Simple projection-based ordering
      def ord(_opts) do
        Funx.Ord.contramap(&(&1.id))
      end

      # With options
      def ord(opts) do
        field = Keyword.get(opts, :field, :id)
        Funx.Ord.contramap(&Map.get(&1, field))
      end

      # Custom comparison logic
      def ord(_opts) do
        %{
          compare: fn a, b ->
            cond do
              normalize(a) < normalize(b) -> :lt
              normalize(a) > normalize(b) -> :gt
              true -> :eq
            end
          end
        }
      end

  Most implementations use `Funx.Ord.contramap/2` for projection-based
  ordering, which handles the Ord map creation automatically.
  """
  @callback ord(opts :: keyword()) :: Funx.Ord.ord_map()
end
