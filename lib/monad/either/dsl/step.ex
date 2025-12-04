defmodule Funx.Monad.Either.Dsl.Step do
  @moduledoc """
  Step types for the Either DSL pipeline.

  Following Spark's Entity pattern, each step type is a distinct struct.
  This provides strong typing, clearer pattern matching, and compile-time guarantees.

  These are internal implementation details - the user-facing API remains unchanged.
  """

  defmodule Bind do
    @moduledoc """
    Represents a bind operation in the pipeline.

    Bind is used for operations that return Either or result tuples.
    """

    @enforce_keys [:operation]
    defstruct [:operation, :__meta__, opts: []]

    @typedoc "A bind step that chains operations returning Either or result tuples"
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

    Ap applies a function wrapped in an Either to a value wrapped in an Either.
    """

    @enforce_keys [:applicative]
    defstruct [:applicative, :__meta__]

    @typedoc "An applicative step that applies wrapped functions to wrapped values"
    @type t :: %__MODULE__{
            applicative: term(),
            __meta__: map() | nil
          }
  end

  defmodule EitherFunction do
    @moduledoc """
    Represents a call to an Either-specific function.

    Either functions: filter_or_else, or_else, map_left, flip, tap.
    """

    @enforce_keys [:function, :args]
    defstruct [:function, :args, :__meta__]

    @typedoc "A step calling an Either-specific function (filter_or_else, or_else, map_left, flip, tap)"
    @type t :: %__MODULE__{
            function: atom(),
            args: list(),
            __meta__: map() | nil
          }
  end

  defmodule BindableFunction do
    @moduledoc """
    Represents a function that needs to be wrapped in bind.

    Bindable functions: validate
    """

    @enforce_keys [:function, :args]
    defstruct [:function, :args, :__meta__]

    @typedoc "A step calling a function that returns Either and needs bind wrapping (validate)"
    @type t :: %__MODULE__{
            function: atom(),
            args: list(),
            __meta__: map() | nil
          }
  end

  @typedoc """
  Union type representing any Step type in the Either DSL pipeline.

  Each step type is a distinct struct with enforced fields and type checking.
  """
  @type t ::
          Bind.t()
          | Map.t()
          | Ap.t()
          | EitherFunction.t()
          | BindableFunction.t()
end
