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
  #
  # Pattern matching on the `type` field at compile time eliminates unreachable
  # case branches, avoiding compiler warnings.

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

  ## Implicit Tiebreaker

  A final identity projection is automatically appended to ensure deterministic
  total ordering. This uses the value's `Ord` protocol implementation, falling
  back to `Funx.Ord.Any` if no implementation exists.

  This means:
    - Custom orderings are refinements of the domain's natural ordering
    - No arbitrary tiebreaking via Elixir term ordering
    - Sorts are always deterministic and reproducible
  """
  @spec execute_steps(list(Step.t())) :: Macro.t()
  def execute_steps([]), do: empty_ord_ast()
  def execute_steps(steps), do: build_concat_ast(append_identity_tiebreaker(steps))

  # ============================================================================
  # IMPLICIT TIEBREAKER
  # ============================================================================

  # Append identity projection as final tiebreaker
  # This ensures deterministic ordering by falling back to the value's Ord protocol
  defp append_identity_tiebreaker(steps) do
    identity_step = %Step{
      direction: :asc,
      projection: quote(do: fn x -> x end),
      ord: quote(do: Funx.Ord),
      type: :projection,
      __meta__: %{line: nil, column: nil}
    }

    steps ++ [identity_step]
  end

  # ============================================================================
  # AST BUILDING
  # ============================================================================

  # Note: With implicit identity tiebreaker, we always have at least 2 steps
  # (user steps + identity), so we always use concat
  defp build_concat_ast(steps) do
    ord_asts = Enum.map(steps, &step_to_ord_ast/1)

    quote do
      Utils.concat([unquote_splicing(ord_asts)])
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
        Utils.contramap(unquote(projection_ast), unquote(ord_ast))
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
        Utils.to_ord_map(unquote(module_ast))
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
            Utils.to_ord_map(module)

          _ ->
            # It's a projection - wrap in contramap
            Utils.contramap(projection, unquote(ord_ast))
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
