defmodule Funx.Predicate.Dsl.Executor do
  @moduledoc false
  # Compile-time code generator that converts parsed DSL nodes into quoted AST.
  #
  # ## Architecture
  #
  # The executor is the second phase of DSL compilation:
  #   1. Parser - Normalizes syntax → Step/Block nodes
  #   2. Executor (this module) - Converts nodes → quoted runtime code
  #   3. Runtime - Executes compiled predicate checks
  #
  # ## Code Generation
  #
  # The executor converts nodes to calls to existing Predicate functions:
  #
  #   - Step (negate: false) → Pass through predicate AST
  #   - Step (negate: true)  → `Predicate.p_not(predicate)`
  #   - Block (all)          → `Predicate.p_all([children...])`
  #   - Block (any)          → `Predicate.p_any([children...])`
  #
  # ## Tree Walking
  #
  # The executor recursively walks the node tree, generating code for each node.
  # Top-level nodes are implicitly combined with p_all (AND logic).

  alias Funx.Predicate
  alias Funx.Predicate.Dsl.{Block, Step}

  @doc """
  Execute (compile) a list of nodes into quoted code that builds a predicate.

  ## Execution Model

  Each node is converted to:
  - Step (negate: false) → predicate AST
  - Step (negate: true) → `Predicate.p_not(predicate)`
  - Block (all) → `Predicate.p_all([children...])`
  - Block (any) → `Predicate.p_any([children...])`

  Top-level nodes are combined with `p_all` (implicit all strategy).
  """
  @spec execute_nodes(list(Step.t() | Block.t())) :: Macro.t()
  def execute_nodes([]), do: empty_predicate_ast()
  def execute_nodes([single_node]), do: node_to_ast(single_node)
  def execute_nodes(nodes), do: build_all_ast(nodes)

  # === Block combinators ===

  defp build_all_ast(nodes) do
    pred_asts = Enum.map(nodes, &node_to_ast/1)

    quote do
      Predicate.p_all([unquote_splicing(pred_asts)])
    end
  end

  defp build_any_ast(nodes) do
    pred_asts = Enum.map(nodes, &node_to_ast/1)

    quote do
      Predicate.p_any([unquote_splicing(pred_asts)])
    end
  end

  # === Step nodes ===

  # Bare step (no projection), non-negated - pass through predicate AST
  defp node_to_ast(%Step{type: :bare, predicate: predicate_ast, negate: false}) do
    predicate_ast
  end

  # Bare step (no projection), negated - wrap with p_not
  defp node_to_ast(%Step{type: :bare, predicate: predicate_ast, negate: true}) do
    quote do
      Predicate.p_not(unquote(predicate_ast))
    end
  end

  # Step with projection, non-negated - compose projection with predicate
  defp node_to_ast(%Step{
         type: :projection,
         projection: projection_ast,
         predicate: predicate_ast,
         negate: false
       }) do
    quote do
      Funx.Predicate.compose_projection(unquote(projection_ast), unquote(predicate_ast))
    end
  end

  # Step with projection, negated - compose and negate
  defp node_to_ast(%Step{
         type: :projection,
         projection: projection_ast,
         predicate: predicate_ast,
         negate: true
       }) do
    quote do
      Predicate.p_not(
        Funx.Predicate.compose_projection(unquote(projection_ast), unquote(predicate_ast))
      )
    end
  end

  # Behaviour step, non-negated - return the predicate from Module.pred(opts)
  defp node_to_ast(%Step{type: :behaviour, predicate: behaviour_ast, negate: false}) do
    behaviour_ast
  end

  # Behaviour step, negated - wrap with p_not
  defp node_to_ast(%Step{type: :behaviour, predicate: behaviour_ast, negate: true}) do
    quote do
      Predicate.p_not(unquote(behaviour_ast))
    end
  end

  # === Block nodes ===

  defp node_to_ast(%Block{strategy: :all, children: children}) do
    build_all_ast(children)
  end

  defp node_to_ast(%Block{strategy: :any, children: children}) do
    build_any_ast(children)
  end

  # === Empty predicate ===

  # Empty predicate always returns true (identity for AND)
  defp empty_predicate_ast do
    quote do
      fn _ -> true end
    end
  end
end
