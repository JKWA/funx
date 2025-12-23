defmodule Funx.Ord.Dsl.Executor do
  @moduledoc false
  # Compile-time executor for Ord DSL - converts steps to quoted AST
  #
  # ## Single-Path Execution
  #
  # This executor has ZERO branching on projection type. It follows a single path:
  #
  #   1. Take normalized Steps (parser already resolved all syntax)
  #   2. Wrap each in `Utils.contramap(projection, ord)`
  #   3. Optionally wrap in `Utils.reverse(...)` for `:desc`
  #   4. Combine with `Utils.concat([...])`
  #
  # All projection-type-specific logic lives in contramap/2.
  # This module just orchestrates the composition.

  alias Funx.Monoid.Ord
  alias Funx.Ord.Dsl.Step
  alias Funx.Ord.Utils

  @doc """
  Execute (compile) a list of steps into quoted code that builds an Ord.

  Unlike Maybe DSL's runtime executor, this runs at compile time and returns
  quoted AST that will be compiled into the calling module.

  ## Execution Model

  Each Step is converted to:
  - `:asc` → `contramap(projection, ord)`
  - `:desc` → `reverse(contramap(projection, ord))`

  Multiple steps are combined with `concat([...])` (monoid append).
  """
  @spec execute_steps(list(Step.t())) :: Macro.t()
  def execute_steps([]), do: empty_ord_ast()
  def execute_steps(steps), do: build_concat_ast(steps)

  # ============================================================================
  # AST BUILDING
  # ============================================================================

  defp build_concat_ast([single_step]) do
    # Optimization: skip concat wrapper for single step
    step_to_ord_ast(single_step)
  end

  defp build_concat_ast(steps) do
    ord_asts = Enum.map(steps, &step_to_ord_ast/1)

    quote do
      Utils.concat([unquote_splicing(ord_asts)])
    end
  end

  defp step_to_ord_ast(%Step{direction: direction, projection: projection_ast, ord: ord_ast}) do
    base_ord_ast = build_contramap_ast(projection_ast, ord_ast)

    case direction do
      :asc -> base_ord_ast
      :desc -> build_reverse_ast(base_ord_ast)
    end
  end

  defp build_contramap_ast(projection_ast, ord_ast) do
    quote do
      Utils.contramap(unquote(projection_ast), unquote(ord_ast))
    end
  end

  defp build_reverse_ast(ord_ast) do
    quote do
      Utils.reverse(unquote(ord_ast))
    end
  end

  # Monoid identity: everything compares equal
  defp empty_ord_ast do
    quote do
      %Ord{}
    end
  end
end
