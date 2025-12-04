defmodule Funx.Monad.Either.Dsl.Step do
  @moduledoc """
  Step types for the Either DSL pipeline.

  Following Spark's Entity pattern, each step type is a distinct struct.
  This provides strong typing and clearer pattern matching in the executor.

  These are internal implementation details - the user-facing API remains unchanged.
  """

  defmodule Bind do
    @moduledoc """
    Represents a bind operation in the pipeline.

    Bind is used for operations that return Either or result tuples.
    """

    @enforce_keys [:operation]
    defstruct [:operation, :__meta__, opts: []]

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

    @type t :: %__MODULE__{
            function: atom(),
            args: list(),
            __meta__: map() | nil
          }
  end

  @type t ::
          Bind.t()
          | Map.t()
          | Ap.t()
          | EitherFunction.t()
          | BindableFunction.t()
end
