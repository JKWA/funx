defmodule Funx.Eq.Dsl.Step do
  @moduledoc false
  # Data structure representing a single equality check in the DSL.
  #
  # ## Fields
  #
  #   - `projection`: Quoted AST for the projection/Eq map/module
  #   - `eq`: Module or AST for the Eq implementation to use
  #   - `negate`: Boolean - true for `not_on` directives (swaps eq?/not_eq?)
  #   - `type`: Projection type for compile-time optimization
  #   - `__meta__`: Source location for error reporting
  #
  # ## Type Field
  #
  # The `type` field enables compile-time optimization by telling the executor
  # how to handle the projection without runtime type detection:
  #
  #   - `:projection` - Optics or functions → wrap in contramap
  #   - `:module_eq` - Module with eq?/2 → convert via to_eq_map
  #   - `:eq_map` - Behaviour returning Eq map → use directly
  #   - `:dynamic` - Unknown (0-arity helper) → runtime detection
  #
  # This eliminates compiler warnings from unreachable case branches.
  #
  # ## Responsibilities
  #
  # This is a pure data container with no logic:
  #   - Parser: Creates Steps with normalized AST and type
  #   - Executor: Pattern matches on type to generate specific code

  @type projection :: Macro.t()
  @type eq :: module() | Macro.t()
  @type projection_type :: :bare | :behaviour | :projection | :module_eq | :eq_map | :dynamic

  @type t :: %__MODULE__{
          projection: projection(),
          eq: eq(),
          negate: boolean(),
          type: projection_type(),
          __meta__: map()
        }

  defstruct [:projection, :eq, :negate, :type, :__meta__]

  @doc """
  Creates a new step with the given projection AST, eq module, negate flag, type, and metadata.

  The projection AST must evaluate to one of contramap's canonical types.
  The type indicates what kind of projection this is for compile-time optimization.
  """
  @spec new(projection(), eq(), boolean(), projection_type(), map()) :: t()
  def new(projection, eq, negate \\ false, type \\ :projection, meta \\ %{}) do
    %__MODULE__{
      projection: projection,
      eq: eq,
      negate: negate,
      type: type,
      __meta__: meta
    }
  end

  @doc """
  Creates a new bare Eq step that passes through an Eq map directly.

  Used when the DSL contains a bare Eq map expression (variable, helper call, etc.)
  without any projection wrapping.
  """
  @spec new_bare(Macro.t(), boolean(), map()) :: t()
  def new_bare(eq_ast, negate \\ false, meta \\ %{}) do
    %__MODULE__{
      projection: eq_ast,
      eq: nil,
      negate: negate,
      type: :bare,
      __meta__: meta
    }
  end

  @doc """
  Creates a new step for a behaviour module.

  Used when a behaviour module is referenced in the DSL.
  The `eq` field contains the AST for calling `Module.eq(opts)`.
  """
  @spec new_behaviour(Macro.t(), boolean(), map()) :: t()
  def new_behaviour(behaviour_ast, negate \\ false, meta \\ %{}) do
    %__MODULE__{
      projection: behaviour_ast,
      eq: nil,
      negate: negate,
      type: :behaviour,
      __meta__: meta
    }
  end
end
