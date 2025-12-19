defmodule Funx.Monad.Maybe.Dsl.Step do
  @moduledoc """
  Step types for the Maybe DSL pipeline.

  Following Spark's Entity pattern, each step type is a distinct struct.
  This provides strong typing, clearer pattern matching, and compile-time guarantees.

  These are internal implementation details - the user-facing API remains unchanged.
  """

  defmodule Bind do
    @moduledoc """
    Represents a bind operation in the pipeline.

    Bind is used for operations that return Maybe or result tuples.
    """

    @enforce_keys [:operation]
    defstruct [:operation, :__meta__, opts: []]

    @typedoc "A bind step that chains operations returning Maybe or result tuples"
    @type t :: %__MODULE__{
            operation: module() | function(),
            opts: keyword(),
            __meta__: map() | nil
          }
  end

  defmodule Map do
    @moduledoc """
    Represents a map operation in the pipeline.

    Map is used for pure transformations that return plain values.
    """

    @enforce_keys [:operation]
    defstruct [:operation, :__meta__, opts: []]

    @typedoc "A map step that transforms values with pure functions"
    @type t :: %__MODULE__{
            operation: module() | function(),
            opts: keyword(),
            __meta__: map() | nil
          }
  end

  defmodule Ap do
    @moduledoc """
    Represents an applicative functor operation.

    Ap applies a function wrapped in a Maybe to a value wrapped in a Maybe.
    """

    @enforce_keys [:applicative]
    defstruct [:applicative, :__meta__]

    @typedoc "An applicative step that applies wrapped functions to wrapped values"
    @type t :: %__MODULE__{
            applicative: term(),
            __meta__: map() | nil
          }
  end

  defmodule MaybeFunction do
    @moduledoc """
    Represents a call to a Maybe-specific function.

    Maybe functions: or_else.
    """

    @enforce_keys [:function, :args]
    defstruct [:function, :args, :__meta__]

    @typedoc "A step calling a Maybe-specific function (or_else)"
    @type t :: %__MODULE__{
            function: atom(),
            args: list(),
            __meta__: map() | nil
          }
  end

  defmodule ProtocolFunction do
    @moduledoc """
    Represents a call to a Funx protocol function.

    Protocol functions are operations implemented via Elixir protocols rather than
    module functions. This allows the operation to work polymorphically across
    different types while maintaining a clean API.

    Examples:
      - tap (Funx.Tappable) - Execute side effects without changing the value
      - filter, guard, filter_map (Funx.Filterable) - Conditional retention
    """

    @enforce_keys [:protocol, :function, :args]
    defstruct [:protocol, :function, :args, :__meta__]

    @typedoc """
    A step calling a protocol function.

    The protocol module (e.g., Funx.Tappable) is stored explicitly so the executor
    can dispatch to the correct protocol implementation.
    """
    @type t :: %__MODULE__{
            protocol: module(),
            function: atom(),
            args: list(),
            __meta__: map() | nil
          }
  end

  @typedoc """
  Union type representing any Step type in the Maybe DSL pipeline.

  Each step type is a distinct struct with enforced fields and type checking.
  """
  @type t ::
          Bind.t()
          | Map.t()
          | Ap.t()
          | MaybeFunction.t()
          | ProtocolFunction.t()
end
