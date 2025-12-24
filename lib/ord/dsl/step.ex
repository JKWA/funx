defmodule Funx.Ord.Dsl.Step do
  @moduledoc false
  # Represents a single normalized ordering step in the Ord DSL compilation pipeline.
  #
  # ## Normalization Invariant
  #
  # A Step represents a fully normalized ordering operation with all syntax sugar
  # resolved. Each field contains quoted AST that will be compiled into the final Ord:
  #
  #   - `direction`: Either `:asc` or `:desc`
  #   - `projection`: Quoted AST that evaluates to one of contramap's canonical types:
  #       * `Lens.t()`
  #       * `Prism.t()`
  #       * `{Prism.t(), or_else}`
  #       * `(a -> b)` function
  #   - `ord`: Module atom or quoted AST that evaluates to an Ord implementation
  #   - `__meta__`: Compile-time metadata (line, column) for error reporting
  #
  # ## Single-Path Guarantee
  #
  # After the parser creates Steps, there is no branching on projection type.
  # The executor simply wraps each step in `Utils.contramap(projection, ord)` and
  # optionally `Utils.reverse(...)` for `:desc` direction.
  #
  # All projection-type-specific logic lives in:
  #   1. Parser: syntax → canonical AST
  #   2. contramap/2: canonical types → executable functions
  #
  # This module is just a data container with no logic.

  @type direction :: :asc | :desc
  @type projection :: Macro.t()
  @type ord :: module() | Macro.t()

  @type t :: %__MODULE__{
          direction: direction(),
          projection: projection(),
          ord: ord(),
          __meta__: map()
        }

  defstruct [:direction, :projection, :ord, :__meta__]

  @doc """
  Creates a new step with the given direction, projection AST, ord module, and metadata.

  The projection AST must evaluate to one of contramap's canonical types.
  """
  @spec new(direction(), projection(), ord(), map()) :: t()
  def new(direction, projection, ord, meta \\ %{}) do
    %__MODULE__{
      direction: direction,
      projection: projection,
      ord: ord,
      __meta__: meta
    }
  end
end
