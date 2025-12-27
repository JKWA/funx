defmodule Funx.Eq.Dsl.Executor do
  @moduledoc false
  # Compile-time executor for Eq DSL - converts steps/blocks to quoted AST
  #
  # ## Recursive Tree Execution
  #
  # This executor recursively walks a tree of Steps (leaf nodes) and Blocks (containers).
  # Each node type generates different AST:
  #
  #   - Step → `Utils.contramap(projection, eq)` (or negated version)
  #   - Block (all) → `Utils.concat_all([children...])`
  #   - Block (any) → `Utils.concat_any([children...])`
  #
  # The tree structure is built by the parser, and this executor just translates
  # it into quoted code.

  alias Funx.Eq.Dsl.{Block, Step}
  alias Funx.Eq.Utils
  alias Funx.Monoid.Eq.All

  @doc """
  Execute (compile) a list of nodes into quoted code that builds an Eq comparator.

  Unlike Ord DSL, Eq DSL has no implicit identity tiebreaker.

  ## Execution Model

  Each node is converted to:
  - Step (on) → `contramap(projection, eq)`
  - Step (not_on) → `contramap(projection, negate(eq))`
  - Block (all) → `concat_all([children...])`
  - Block (any) → `concat_any([children...])`

  Top-level nodes are combined with `concat_all` (implicit all strategy).
  """
  @spec execute_nodes(list(Step.t() | Block.t())) :: Macro.t()
  def execute_nodes([]), do: empty_eq_ast()
  def execute_nodes(nodes), do: build_all_ast(nodes)

  defp build_all_ast(nodes) do
    eq_asts = Enum.map(nodes, &node_to_ast/1)

    quote do
      Utils.concat_all([unquote_splicing(eq_asts)])
    end
  end

  defp build_any_ast(nodes) do
    eq_asts = Enum.map(nodes, &node_to_ast/1)

    quote do
      Utils.concat_any([unquote_splicing(eq_asts)])
    end
  end

  # Projection type - use contramap (non-negated)
  defp node_to_ast(%Step{projection: projection_ast, eq: eq_ast, negate: false, type: :projection}) do
    quote do
      Utils.contramap(unquote(projection_ast), unquote(eq_ast))
    end
  end

  # Module with eq?/2 - convert to Eq map (non-negated)
  defp node_to_ast(%Step{projection: module_ast, negate: false, type: :module_eq}) do
    quote do
      Utils.to_eq_map(unquote(module_ast))
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
          Utils.to_eq_map(module)

        _ ->
          # It's a projection - wrap in contramap
          Utils.contramap(projection, unquote(eq_ast))
      end
    end
  end

  # Projection type - use contramap with negated eq (negated)
  defp node_to_ast(%Step{projection: projection_ast, eq: eq_ast, negate: true, type: :projection}) do
    negated_eq_ast = build_negated_eq_ast(eq_ast)

    quote do
      Utils.contramap(unquote(projection_ast), unquote(negated_eq_ast))
    end
  end

  # Module with eq?/2 - convert to Eq map and negate (negated)
  defp node_to_ast(%Step{projection: module_ast, negate: true, type: :module_eq}) do
    quote do
      eq_map = Utils.to_eq_map(unquote(module_ast))

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
          eq_map = Utils.to_eq_map(module)

          %{
            eq?: eq_map.not_eq?,
            not_eq?: eq_map.eq?
          }

        _ ->
          # It's a projection - wrap in contramap with negated eq
          Utils.contramap(projection, unquote(negated_eq_ast))
      end
    end
  end

  defp node_to_ast(%Block{strategy: :all, children: children}) do
    build_all_ast(children)
  end

  defp node_to_ast(%Block{strategy: :any, children: children}) do
    build_any_ast(children)
  end

  defp empty_eq_ast do
    quote do
      %All{}
    end
  end

  defp build_negated_eq_ast(eq_ast) do
    quote do
      %{
        eq?: fn a, b ->
          eq = unquote(eq_ast)
          eq_map = if is_atom(eq), do: Utils.to_eq_map(eq), else: eq
          eq_map.not_eq?.(a, b)
        end,
        not_eq?: fn a, b ->
          eq = unquote(eq_ast)
          eq_map = if is_atom(eq), do: Utils.to_eq_map(eq), else: eq
          eq_map.eq?.(a, b)
        end
      }
    end
  end
end
