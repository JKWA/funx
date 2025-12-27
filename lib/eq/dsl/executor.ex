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

  defp node_to_ast(%Step{projection: projection_ast, eq: eq_ast, negate: false}) do
    quote do
      Utils.contramap(unquote(projection_ast), unquote(eq_ast))
    end
  end

  defp node_to_ast(%Step{projection: projection_ast, eq: eq_ast, negate: true}) do
    negated_eq_ast = build_negated_eq_ast(eq_ast)

    quote do
      Utils.contramap(unquote(projection_ast), unquote(negated_eq_ast))
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
