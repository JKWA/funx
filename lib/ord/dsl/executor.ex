defmodule Funx.Ord.Dsl.Executor do
  @moduledoc false
  # Compile-time code generator that converts parsed DSL nodes into quoted AST.
  #
  # ## Type-Specific Code Generation
  #
  # Uses type information from parser to generate specific code paths without
  # runtime branching. Each Step type gets specialized handling:
  #
  #   - `:projection` - Optics/functions → wrap in contramap
  #   - `:module_ord` - Module with compare/2 → convert via to_ord_map
  #   - `:ord_map` - Behaviour returning Ord map → use directly
  #   - `:dynamic` - 0-arity helper → runtime type detection
  #   - `:ord_variable` - Variable holding ord map → runtime validation
  #
  # Pattern matching on the `type` field at compile time eliminates unreachable
  # case branches, avoiding compiler warnings.

  alias Funx.Monoid.Ord
  alias Funx.Ord
  alias Funx.Ord.Dsl.Step

  @doc """
  Execute (compile) a list of steps into quoted code that builds an Ord.

  Unlike Maybe DSL's runtime executor, this runs at compile time and returns
  quoted AST that will be compiled into the calling module.

  ## Execution Model

  Each Step is converted to:
  - `:asc` → `contramap(projection, ord)`
  - `:desc` → `reverse(contramap(projection, ord))`

  Multiple steps are combined with `concat([...])` (monoid append).

  If two values are equal on all specified fields, they compare as equal.
  Users can add an explicit tiebreaker if needed (e.g., `asc &Function.identity/1`).
  """
  @spec execute_steps(list(Step.t())) :: Macro.t()
  def execute_steps([]), do: empty_ord_ast()
  def execute_steps([step]), do: step_to_ord_ast(step)
  def execute_steps(steps), do: build_concat_ast(steps)

  # ============================================================================
  # AST BUILDING
  # ============================================================================

  defp build_concat_ast(steps) do
    ord_asts = Enum.map(steps, &step_to_ord_ast/1)

    quote do
      Ord.concat([unquote_splicing(ord_asts)])
    end
  end

  # === Projection type ===
  # Optics or functions - wrap in contramap

  defp step_to_ord_ast(%Step{
         direction: direction,
         projection: projection_ast,
         ord: ord_ast,
         type: :projection
       }) do
    base_ord_ast =
      quote do
        Ord.contramap(unquote(projection_ast), unquote(ord_ast))
      end

    case direction do
      :asc -> base_ord_ast
      :desc -> build_reverse_ast(base_ord_ast)
    end
  end

  # === Module with compare/2 ===
  # Convert module to Ord map using to_ord_map

  defp step_to_ord_ast(%Step{direction: direction, projection: module_ast, type: :module_ord}) do
    base_ord_ast =
      quote do
        Ord.to_ord_map(unquote(module_ast))
      end

    case direction do
      :asc -> base_ord_ast
      :desc -> build_reverse_ast(base_ord_ast)
    end
  end

  # === Ord map from behaviour ===
  # Use the Ord map directly (no contramap needed)

  defp step_to_ord_ast(%Step{direction: direction, projection: ord_map_ast, type: :ord_map}) do
    base_ord_ast = ord_map_ast

    case direction do
      :asc -> base_ord_ast
      :desc -> build_reverse_ast(base_ord_ast)
    end
  end

  # === Dynamic type ===
  # Runtime detection for 0-arity helpers

  defp step_to_ord_ast(%Step{
         direction: direction,
         projection: projection_ast,
         ord: ord_ast,
         type: :dynamic
       }) do
    base_ord_ast =
      quote do
        projection = unquote(projection_ast)

        case projection do
          %{compare: compare_fun} when is_function(compare_fun, 2) ->
            # Already an Ord map - use it directly
            projection

          module when is_atom(module) ->
            # It's a module - convert to Ord map
            Ord.to_ord_map(module)

          _ ->
            # It's a projection - wrap in contramap
            Ord.contramap(projection, unquote(ord_ast))
        end
      end

    case direction do
      :asc -> base_ord_ast
      :desc -> build_reverse_ast(base_ord_ast)
    end
  end

  # === Ord variable ===
  # Runtime validation of ord map variable

  defp step_to_ord_ast(%Step{direction: direction, projection: var_ast, type: :ord_variable}) do
    base_ord_ast =
      quote do
        ord_var = unquote(var_ast)

        case ord_var do
          %{lt?: lt_fun, le?: le_fun, gt?: gt_fun, ge?: ge_fun}
          when is_function(lt_fun, 2) and is_function(le_fun, 2) and
                 is_function(gt_fun, 2) and is_function(ge_fun, 2) ->
            # Valid ord map - use it directly
            ord_var

          _ ->
            raise RuntimeError, """
            Expected an Ord map, got: #{inspect(ord_var)}

            An Ord map must have the following structure:
              %{
                lt?: fn(a, b) -> boolean end,
                le?: fn(a, b) -> boolean end,
                gt?: fn(a, b) -> boolean end,
                ge?: fn(a, b) -> boolean end
              }

            You can create ord maps using:
              - ord do ... end
              - Ord.contramap(...)
              - Ord.reverse(...)
              - Ord.concat([...])
            """
        end
      end

    case direction do
      :asc -> base_ord_ast
      :desc -> build_reverse_ast(base_ord_ast)
    end
  end

  # ============================================================================
  # HELPERS
  # ============================================================================

  defp build_reverse_ast(ord_ast) do
    quote do
      Ord.reverse(unquote(ord_ast))
    end
  end

  # Monoid identity: everything compares equal
  defp empty_ord_ast do
    quote do
      %Funx.Monoid.Ord{}
    end
  end
end
