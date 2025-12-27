defmodule Funx.Eq.Dsl.Step do
  @moduledoc false
  # Represents a single normalized equality check step in the Eq DSL compilation pipeline.
  #
  # ## Normalization Invariant
  #
  # A Step represents a fully normalized equality operation with all syntax sugar
  # resolved. Each field contains quoted AST that will be compiled into the final Eq:
  #
  #   - `projection`: Quoted AST that evaluates to one of contramap's canonical types:
  #       * `Lens.t()`
  #       * `Prism.t()`
  #       * `{Prism.t(), or_else}`
  #       * `(a -> b)` function
  #   - `eq`: Module atom or quoted AST that evaluates to an Eq implementation
  #   - `negate`: Boolean indicating if this is a `not_on` directive
  #   - `__meta__`: Compile-time metadata (line, column) for error reporting
  #
  # ## Single-Path Guarantee
  #
  # After the parser creates Steps, there is no branching on projection type.
  # The executor simply wraps each step in `Utils.contramap(projection, eq)` and
  # optionally negates for `not_on` directives.
  #
  # All projection-type-specific logic lives in:
  #   1. Parser: syntax → canonical AST
  #   2. contramap/2: canonical types → executable functions
  #
  # This module is just a data container with no logic.

  @type projection :: Macro.t()
  @type eq :: module() | Macro.t()

  @type t :: %__MODULE__{
          projection: projection(),
          eq: eq(),
          negate: boolean(),
          __meta__: map()
        }

  defstruct [:projection, :eq, :negate, :__meta__]

  @doc """
  Creates a new step with the given projection AST, eq module, negate flag, and metadata.

  The projection AST must evaluate to one of contramap's canonical types.
  """
  @spec new(projection(), eq(), boolean(), map()) :: t()
  def new(projection, eq, negate \\ false, meta \\ %{}) do
    %__MODULE__{
      projection: projection,
      eq: eq,
      negate: negate,
      __meta__: meta
    }
  end
end
