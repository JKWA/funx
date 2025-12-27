defmodule Funx.Ord.Dsl.Step do
  @moduledoc false
  # Data structure representing a single ordering step in the DSL.
  #
  # ## Fields
  #
  #   - `direction`: Either `:asc` or `:desc`
  #   - `projection`: Quoted AST for the projection/Ord map/module
  #   - `ord`: Module or AST for the Ord implementation to use
  #   - `type`: Projection type for compile-time optimization
  #   - `__meta__`: Source location for error reporting
  #
  # ## Type Field
  #
  # The `type` field enables compile-time optimization by telling the executor
  # how to handle the projection without runtime type detection:
  #
  #   - `:projection` - Optics or functions → wrap in contramap
  #   - `:module_ord` - Module with compare/2 → convert via to_ord_map
  #   - `:ord_map` - Behaviour returning Ord map → use directly
  #   - `:dynamic` - Unknown (0-arity helper) → runtime detection
  #
  # This eliminates compiler warnings from unreachable case branches.
  #
  # ## Responsibilities
  #
  # This is a pure data container with no logic:
  #   - Parser: Creates Steps with normalized AST and type
  #   - Executor: Pattern matches on type to generate specific code

  @type direction :: :asc | :desc
  @type projection :: Macro.t()
  @type ord :: module() | Macro.t()
  @type projection_type :: :projection | :module_ord | :ord_map | :dynamic

  @type t :: %__MODULE__{
          direction: direction(),
          projection: projection(),
          ord: ord(),
          type: projection_type(),
          __meta__: map()
        }

  defstruct [:direction, :projection, :ord, :type, :__meta__]

  @doc """
  Creates a new step with the given direction, projection AST, ord module, type, and metadata.

  The projection AST must evaluate to one of contramap's canonical types.
  The type indicates what kind of projection this is for compile-time optimization.
  """
  @spec new(direction(), projection(), ord(), projection_type(), map()) :: t()
  def new(direction, projection, ord, type \\ :projection, meta \\ %{}) do
    %__MODULE__{
      direction: direction,
      projection: projection,
      ord: ord,
      type: type,
      __meta__: meta
    }
  end
end
