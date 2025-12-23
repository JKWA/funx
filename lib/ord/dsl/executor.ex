defmodule Funx.Ord.Dsl.Executor do
  @moduledoc false
  # Compile-time executor for Ord DSL - converts steps to quoted AST

  alias Funx.Monoid.Ord, as: OrdStruct
  alias Funx.Ord.Dsl.Step
  alias Funx.Ord.Utils

  @doc """
  Execute (compile) a list of steps into quoted code that builds an Ord.

  Unlike Maybe DSL's runtime executor, this runs at compile time and returns
  quoted AST that will be compiled into the calling module.
  """
  @spec execute_steps(list(Step.t())) :: Macro.t()
  def execute_steps([]), do: empty_ord_ast()
  def execute_steps(steps), do: build_concat_ast(steps)

  # ============================================================================
  # AST BUILDING
  # ============================================================================

  # Build concat([contramap(...), contramap(...), ...])
  defp build_concat_ast([single_step]) do
    # For a single step, don't use concat - just return the ord directly
    step_to_ord_ast(single_step)
  end

  defp build_concat_ast(steps) do
    ord_asts = Enum.map(steps, &step_to_ord_ast/1)

    quote do
      Utils.concat([unquote_splicing(ord_asts)])
    end
  end

  # Convert a single step to its Ord AST
  defp step_to_ord_ast(%Step{direction: direction, projection: projection_ast, ord: ord_ast}) do
    base_ord_ast = build_contramap_ast(projection_ast, ord_ast)

    case direction do
      :asc -> base_ord_ast
      :desc -> build_reverse_ast(base_ord_ast)
    end
  end

  # Build contramap(projection_ast, ord_ast)
  # Note: contramap handles all projection types (functions, Lens, Prism, {Prism, default})
  defp build_contramap_ast(projection_ast, ord_ast) do
    quote do
      Utils.contramap(unquote(projection_ast), unquote(ord_ast))
    end
  end

  # Build reverse(ord_ast)
  defp build_reverse_ast(ord_ast) do
    quote do
      Utils.reverse(unquote(ord_ast))
    end
  end

  # Empty ord (identity ordering - always returns :eq)
  defp empty_ord_ast do
    quote do
      %OrdStruct{}
    end
  end
end
