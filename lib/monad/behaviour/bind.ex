defmodule Funx.Monad.Behaviour.Bind do
  @moduledoc """
  Behaviour for bind operations across monad DSLs.

  This behaviour defines a generic interface for operations that can fail,
  usable with the `bind` operation in any monad DSL (Either, Maybe, etc.).

  ## Contract

  ```elixir
  @callback bind(value :: any(), opts :: keyword(), env :: keyword()) ::
    {:ok, any()}
    | {:error, any()}
    | Either.t()
    | Maybe.t()
  ```

  The DSL will normalize all these return formats.

  Note: Plain values can also be returned and will be treated as success,
  but using the explicit formats above is preferred for clarity.

  ## Arguments

  - `value` - The value to operate on
  - `opts` - Keyword list of options (module-specific configuration)
  - `env` - Environment/context from DSL (for Reader-like dependency injection)

  ## Return Values

  **Monad types (preferred)**:
  - `Either.right(value)` - Success with value
  - `Either.left(error)` - Failure with error
  - `Maybe.just(value)` - Success with value
  - `Maybe.nothing()` - Failure (no value)

  **Tagged tuples (supported)**:
  - `{:ok, value}` - Operation succeeded with new value
  - `{:error, reason}` - Operation failed with error

  The DSL will normalize all these return values into the appropriate monad type.

  ## Cross-Monad Normalization

  When a `bind` module returns a monad type different from the current DSL context,
  the result is automatically normalized:

  **Maybe → Either**:
  - `Just(value)` → `Right(value)`
  - `Nothing` → `Left(:nothing)` (uses `:nothing` atom as error)

  **Either → Maybe**:
  - `Right(value)` → `Just(value)`
  - `Left(_error)` → `Nothing` (error information is discarded)

  This allows `Bind` modules to be reused across different monad DSLs while
  maintaining predictable behavior. Note that error information is lost when
  converting `Left` to `Nothing`, as Maybe does not carry error details.

  ## Semantic Rules

  1. **Arguments strictly ordered**: value, opts, env
  2. **May use env** for Reader-like dependency injection (only way to access env - functions cannot)
  3. **Can fail** - use this for operations that might not succeed
  4. **Returns result** in tagged tuple or monad type

  ## Examples

  ### Using Either (Preferred)

  ```elixir
  defmodule ParseInt do
    @behaviour Funx.Monad.Behaviour.Bind
    import Funx.Monad.Either

    @impl true
    def bind(value, _opts, _env) when is_binary(value) do
      case Integer.parse(value) do
        {int, ""} -> right(int)
        _ -> left("Invalid integer")
      end
    end

    def bind(_value, _opts, _env), do: left("Expected string")
  end

  # Usage in Either DSL
  use Funx.Monad.Either

  either "42" do
    bind ParseInt
  end
  #=> %Right{right: 42}

  either "not a number" do
    bind ParseInt
  end
  #=> %Left{left: "Invalid integer"}
  ```

  ### Using Tagged Tuples (Supported)

  ```elixir
  defmodule ParseIntTuple do
    @behaviour Funx.Monad.Behaviour.Bind

    @impl true
    def bind(value, _opts, _env) when is_binary(value) do
      case Integer.parse(value) do
        {int, ""} -> {:ok, int}
        _ -> {:error, "Invalid integer"}
      end
    end

    def bind(_value, _opts, _env), do: {:error, "Expected string"}
  end

  # Also works in Either DSL (tuples are normalized)
  either "42" do
    bind ParseIntTuple
  end
  #=> %Right{right: 42}
  ```

  ## Using Either Types (Preferred)

  ```elixir
  defmodule ParseIntEither do
    @behaviour Funx.Monad.Behaviour.Bind
    import Funx.Monad.Either

    @impl true
    def bind(value, _opts, _env) when is_binary(value) do
      case Integer.parse(value) do
        {int, ""} -> right(int)
        _ -> left("Invalid integer")
      end
    end

    def bind(_value, _opts, _env), do: left("Expected string")
  end
  ```

  ## Using Maybe Types (Preferred)

  ```elixir
  defmodule ParseIntMaybe do
    @behaviour Funx.Monad.Behaviour.Bind
    import Funx.Monad.Maybe

    @impl true
    def bind(value, _opts, _env) when is_binary(value) do
      case Integer.parse(value) do
        {int, ""} -> just(int)
        _ -> nothing()
      end
    end

    def bind(_value, _opts, _env), do: nothing()
  end

  # Can be used in Either DSL - Nothing becomes Left(:nothing)
  use Funx.Monad.Either

  either "42" do
    bind ParseIntMaybe
  end
  #=> %Right{right: 42}

  either "invalid" do
    bind ParseIntMaybe
  end
  #=> %Left{left: :nothing}
  ```

  ## With Options

  ```elixir
  defmodule ParseIntWithBase do
    @behaviour Funx.Monad.Behaviour.Bind

    @impl true
    def bind(value, opts, _env) when is_binary(value) do
      base = Keyword.get(opts, :base, 10)

      case Integer.parse(value, base) do
        {int, ""} -> {:ok, int}
        _ -> {:error, "Invalid integer for base \#{base}"}
      end
    end

    def bind(_value, _opts, _env), do: {:error, "Expected string"}
  end

  # Usage
  either "FF" do
    bind {ParseIntWithBase, base: 16}
  end
  #=> %Right{right: 255}
  ```
  """

  @doc """
  Performs an operation that can fail.

  Arguments:

    * value - The current value in the pipeline
    * opts - Module-specific options passed in the DSL
    * env - Environment/context from the DSL (for dependency injection)

  Returns a result indicating success or failure.

  Examples:

      # Using tagged tuples (generic)
      def bind(value, _opts, _env) when is_binary(value) do
        case Integer.parse(value) do
          {int, ""} -> {:ok, int}
          _ -> {:error, "invalid"}
        end
      end

      # Using Either (monad-specific)
      import Funx.Monad.Either

      def bind(value, _opts, _env) do
        if valid?(value) do
          right(transform(value))
        else
          left("validation failed")
        end
      end

      # With options
      def bind(value, opts, _env) do
        threshold = Keyword.get(opts, :min, 0)
        if value > threshold do
          {:ok, value}
        else
          {:error, "below threshold"}
        end
      end

      # Using env for dependency injection
      def bind(user_id, _opts, env) do
        database = Keyword.get(env, :database)
        database.fetch_user(user_id)
      end
  """
  @callback bind(value :: any(), opts :: keyword(), env :: keyword()) ::
              {:ok, any()}
              | {:error, any()}
              | Funx.Monad.Either.t(any(), any())
              | Funx.Monad.Maybe.t(any())
end
