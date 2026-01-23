defmodule Funx.Eq.Dsl.Executor do
  @moduledoc false
  # Compile-time code generator that converts parsed DSL nodes into quoted AST.
  #
  # ## Architecture
  #
  # The executor is the second phase of DSL compilation:
  #   1. Parser - Normalizes syntax → typed Step/Block nodes
  #   2. Executor (this module) - Converts nodes → quoted runtime code
  #   3. Runtime - Executes compiled equality checks
  #
  # ## Type-Specific Code Generation
  #
  # The executor uses the type information from the parser to generate
  # specific code paths for each projection type, eliminating runtime
  # branching and compiler warnings:
  #
  #   - :projection → `Eq.contramap(projection, eq)`
  #   - :module_eq  → `Eq.to_eq_map(module)`
  #   - :eq_map     → Use Eq map directly (no wrapping)
  #   - :dynamic    → Runtime case statement (0-arity helpers only)
  #
  # ## Tree Walking
  #
  # The executor recursively walks the node tree:
  #   - Step nodes → Generate contramap/to_eq_map calls
  #   - Block nodes → Generate compose_all/compose_any calls
  #   - Negate flag → Swap eq?/not_eq? functions
  #
  # Top-level nodes are implicitly combined with compose_all (AND logic).

  alias Funx.Eq
  alias Funx.Eq.Dsl.{Block, Step}
  alias Funx.Monoid.Eq.All

  @doc """
  Execute (compile) a list of nodes into quoted code that builds an Eq comparator.

  Unlike Ord DSL, Eq DSL has no implicit identity tiebreaker.

  ## Execution Model

  Each node is converted to:
  - Step (on) → `contramap(projection, eq)`
  - Step (not_on) → `contramap(projection, negate(eq))`
  - Block (all) → `compose_all([children...])`
  - Block (any) → `compose_any([children...])`

  Top-level nodes are combined with `compose_all` (implicit all strategy).
  """
  @spec execute_nodes(list(Step.t() | Block.t())) :: Macro.t()
  def execute_nodes([]) do
    empty_eq_ast()
  end

  def execute_nodes(nodes), do: build_all_ast(nodes)

  # Block combinators - recursively process children
  defp build_all_ast(nodes) do
    eq_asts = Enum.map(nodes, &node_to_ast/1)

    quote do
      Eq.compose_all([unquote_splicing(eq_asts)])
    end
  end

  defp build_any_ast(nodes) do
    eq_asts = Enum.map(nodes, &node_to_ast/1)

    quote do
      Eq.compose_any([unquote_splicing(eq_asts)])
    end
  end

  # === Non-negated Step nodes ===
  #
  # Each type generates specific code based on compile-time type information.

  # Projection type - use contramap (non-negated)
  defp node_to_ast(%Step{projection: projection_ast, eq: eq_ast, negate: false, type: :projection}) do
    quote do
      Eq.contramap(unquote(projection_ast), unquote(eq_ast))
    end
  end

  # Module with eq?/2 - convert to Eq map (non-negated)
  defp node_to_ast(%Step{projection: module_ast, negate: false, type: :module_eq}) do
    quote do
      Eq.to_eq_map(unquote(module_ast))
    end
  end

  # Eq map from behaviour - use directly (non-negated)
  defp node_to_ast(%Step{projection: eq_map_ast, negate: false, type: :eq_map}) do
    eq_map_ast
  end

  # Dynamic type - runtime detection (non-negated)
  defp node_to_ast(%Step{projection: projection_ast, eq: eq_ast, negate: false, type: :dynamic}) do
    quote do
      projection = unquote(projection_ast)

      case projection do
        %{eq?: eq_fun, not_eq?: not_eq_fun}
        when is_function(eq_fun, 2) and is_function(not_eq_fun, 2) ->
          # Already an Eq map - use it directly
          projection

        module when is_atom(module) ->
          # It's a module - convert to Eq map
          Eq.to_eq_map(module)

        _ ->
          # It's a projection - wrap in contramap
          Eq.contramap(projection, unquote(eq_ast))
      end
    end
  end

  # === Negated Step nodes ===
  #
  # Same as non-negated but swaps eq?/not_eq? functions.

  # Projection type - use contramap with negated eq (negated)
  defp node_to_ast(%Step{projection: projection_ast, eq: eq_ast, negate: true, type: :projection}) do
    negated_eq_ast = build_negated_eq_ast(eq_ast)

    quote do
      Eq.contramap(unquote(projection_ast), unquote(negated_eq_ast))
    end
  end

  # Module with eq?/2 - convert to Eq map and negate (negated)
  defp node_to_ast(%Step{projection: module_ast, negate: true, type: :module_eq}) do
    quote do
      eq_map = Eq.to_eq_map(unquote(module_ast))

      %{
        eq?: eq_map.not_eq?,
        not_eq?: eq_map.eq?
      }
    end
  end

  # Eq map from behaviour - negate it (negated)
  defp node_to_ast(%Step{projection: eq_map_ast, negate: true, type: :eq_map}) do
    quote do
      eq_map = unquote(eq_map_ast)

      %{
        eq?: eq_map.not_eq?,
        not_eq?: eq_map.eq?
      }
    end
  end

  # Dynamic type - runtime detection (negated)
  defp node_to_ast(%Step{projection: projection_ast, eq: eq_ast, negate: true, type: :dynamic}) do
    negated_eq_ast = build_negated_eq_ast(eq_ast)

    quote do
      projection = unquote(projection_ast)

      case projection do
        %{eq?: eq_fun, not_eq?: not_eq_fun}
        when is_function(eq_fun, 2) and is_function(not_eq_fun, 2) ->
          # Already an Eq map - negate it
          %{
            eq?: projection.not_eq?,
            not_eq?: projection.eq?
          }

        module when is_atom(module) ->
          # It's a module - convert to Eq map and negate it
          eq_map = Eq.to_eq_map(module)

          %{
            eq?: eq_map.not_eq?,
            not_eq?: eq_map.eq?
          }

        _ ->
          # It's a projection - wrap in contramap with negated eq
          Eq.contramap(projection, unquote(negated_eq_ast))
      end
    end
  end

  # === Block nodes ===
  #
  # Recursively process children with appropriate combinator.

  defp node_to_ast(%Block{strategy: :all, children: children}) do
    build_all_ast(children)
  end

  defp node_to_ast(%Block{strategy: :any, children: children}) do
    build_any_ast(children)
  end

  # === Helpers ===

  # Empty eq block returns identity Eq (all comparisons pass).
  defp empty_eq_ast do
    quote do
      %All{}
    end
  end

  # Creates an Eq map that swaps eq?/not_eq? functions for negation.
  #
  # Handles both module atoms (converted via to_eq_map) and Eq maps.
  defp build_negated_eq_ast(eq_ast) do
    quote do
      %{
        eq?: fn a, b ->
          eq = unquote(eq_ast)
          eq_map = if is_atom(eq), do: Eq.to_eq_map(eq), else: eq
          eq_map.not_eq?.(a, b)
        end,
        not_eq?: fn a, b ->
          eq = unquote(eq_ast)
          eq_map = if is_atom(eq), do: Eq.to_eq_map(eq), else: eq
          eq_map.eq?.(a, b)
        end
      }
    end
  end
end
