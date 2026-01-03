defmodule Funx.Predicate.Dsl.Step do
  @moduledoc false
  # Data structure representing a single predicate check in the DSL.
  #
  # ## Fields
  #
  #   - `projection`: Optional projection (optic, field, or function) to focus on
  #   - `predicate`: Quoted AST for the predicate function
  #   - `negate`: Boolean - true for `negate` directives
  #   - `type`: Projection type for optimization (:bare or :projection)
  #   - `__meta__`: Source location for error reporting
  #
  # ## Type Field
  #
  # The `type` field indicates the step type:
  #
  #   - `:bare` - No projection, just a predicate
  #   - `:projection` - Has projection (optic, field, or function)
  #   - `:behaviour` - Behaviour module that returns a predicate
  #
  # ## Responsibilities
  #
  # This is a pure data container with no logic:
  #   - Parser: Creates Steps with optional projection and predicate AST
  #   - Executor: Composes projection with predicate if needed

  @type projection :: Macro.t() | nil
  @type projection_type :: :bare | :projection | :behaviour

  @type t :: %__MODULE__{
          projection: projection(),
          predicate: Macro.t(),
          negate: boolean(),
          type: projection_type(),
          __meta__: map()
        }

  defstruct [:projection, :predicate, :negate, :type, :__meta__]

  @doc """
  Creates a new step with the given predicate AST, negate flag, and metadata.

  For bare predicates (no projection), pass nil for projection.
  """
  @spec new(Macro.t(), boolean(), map()) :: t()
  def new(predicate, negate \\ false, meta \\ %{}) do
    %__MODULE__{
      projection: nil,
      predicate: predicate,
      negate: negate,
      type: :bare,
      __meta__: meta
    }
  end

  @doc """
  Creates a new step with a projection and predicate.

  Used for `on` directives that focus on a specific part of the data.
  """
  @spec new_with_projection(Macro.t(), Macro.t(), boolean(), map()) :: t()
  def new_with_projection(projection, predicate, negate \\ false, meta \\ %{}) do
    %__MODULE__{
      projection: projection,
      predicate: predicate,
      negate: negate,
      type: :projection,
      __meta__: meta
    }
  end

  @doc """
  Creates a new step for a behaviour module.

  Used when a behaviour module is referenced in the DSL.
  The `predicate` field contains the AST for calling `Module.pred(opts)`.
  """
  @spec new_behaviour(Macro.t(), boolean(), map()) :: t()
  def new_behaviour(behaviour_ast, negate \\ false, meta \\ %{}) do
    %__MODULE__{
      projection: nil,
      predicate: behaviour_ast,
      negate: negate,
      type: :behaviour,
      __meta__: meta
    }
  end
end
