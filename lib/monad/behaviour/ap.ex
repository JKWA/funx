defmodule Funx.Monad.Behaviour.Ap do
  @moduledoc """
  Behaviour for applicative operations across monad DSLs.

  Ap (apply) is the applicative functor operation that produces a wrapped function
  to be applied to wrapped values. This allows for function application within
  a computational context.

  ## Contract

  ```elixir
  @callback ap(value :: any(), opts :: keyword(), env :: keyword()) ::
    {:ok, (any() -> any())}
    | {:error, any()}
    | Either.t((any() -> any()), any())
    | Maybe.t((any() -> any()))
  ```

  ## Arguments

  - `value` - The value to use for producing the function
  - `opts` - Keyword list of options (module-specific configuration)
  - `env` - Environment/context from DSL (for Reader-like dependency injection)

  ## Return Values

  **Monad types (preferred)**:
  - `Either.right(fn)` - Success with a function
  - `Either.left(error)` - Failure with error
  - `Maybe.just(fn)` - Success with a function
  - `Maybe.nothing()` - Failure (no function)

  **Tagged tuples (supported)**:
  - `{:ok, fn}` - Operation succeeded with a function
  - `{:error, reason}` - Operation failed with error

  The DSL will normalize all these return values into the appropriate monad type.

  ## Cross-Monad Normalization

  When an `ap` module returns a monad type different from the current DSL context,
  the result is automatically normalized:

  **Maybe → Either**:
  - `Just(fn)` → `Right(fn)`
  - `Nothing` → `Left(:nothing)` (uses `:nothing` atom as error)

  **Either → Maybe**:
  - `Right(fn)` → `Just(fn)`
  - `Left(_error)` → `Nothing` (error information is discarded)

  ## Semantic Rules

  1. **Arguments strictly ordered**: value, opts, env
  2. **May use env** for Reader-like dependency injection (only way to access env - functions cannot)
  3. **Produces a function** - returns a wrapped function, not a wrapped value
  4. **Can fail** - use this for operations that might not produce a function

  ## Examples

  ### Basic Applicative

  ```elixir
  defmodule Multiplier do
    @behaviour Funx.Monad.Behaviour.Ap
    import Funx.Monad.Either

    @impl true
    def ap(factor, _opts, _env) when is_number(factor) do
      right(fn x -> x * factor end)
    end

    def ap(_value, _opts, _env), do: left("Expected number for factor")
  end

  # Usage in Either DSL
  use Funx.Monad.Either

  either 5 do
    ap Multiplier
  end
  # First evaluates Multiplier.ap(5, []) -> Right(fn x -> x * 5 end)
  # Then applies: fn x -> x * 5 end to 5 -> 25
  #=> %Right{right: 25}
  ```

  ### With Options

  ```elixir
  defmodule ConditionalOperator do
    @behaviour Funx.Monad.Behaviour.Ap
    import Funx.Monad.Either

    @impl true
    def ap(value, opts, _env) do
      op = Keyword.get(opts, :operation, :add)

      case op do
        :add -> right(fn x -> x + value end)
        :multiply -> right(fn x -> x * value end)
        :subtract -> right(fn x -> x - value end)
        _ -> left("Unknown operation: \#{op}")
      end
    end
  end

  # Usage
  either 10 do
    ap {ConditionalOperator, operation: :multiply}
  end
  #=> %Right{right: 100}
  ```

  ### Failure Cases

  ```elixir
  defmodule ValidatedOperator do
    @behaviour Funx.Monad.Behaviour.Ap
    import Funx.Monad.Either

    @impl true
    def ap(value, _opts, _env) when is_number(value) and value > 0 do
      right(fn x -> x + value end)
    end

    def ap(value, _opts, _env) when is_number(value) do
      left("Factor must be positive, got: \#{value}")
    end

    def ap(_value, _opts, _env), do: left("Expected number")
  end

  # Success
  either 5 do
    ap ValidatedOperator
  end
  #=> %Right{right: 10}

  # Failure
  either -3 do
    ap ValidatedOperator
  end
  #=> %Left{left: "Factor must be positive, got: -3"}
  ```
  """

  @doc """
  Produces a wrapped function based on the input value.

  Arguments:

    * value - The current value in the pipeline
    * opts - Module-specific options passed in the DSL
    * env - Environment/context from the DSL (for dependency injection)

  Returns a wrapped function that will be applied to the value.

  Examples:

      # Using Either
      import Funx.Monad.Either

      def ap(multiplier, _opts, _env) when is_number(multiplier) do
        right(fn x -> x * multiplier end)
      end

      # Using tagged tuples
      def ap(multiplier, _opts, _env) when is_number(multiplier) do
        {:ok, fn x -> x * multiplier end}
      end

      # With failure case
      def ap(value, _opts, _env) do
        if valid?(value) do
          right(fn x -> transform(x, value) end)
        else
          left("validation failed")
        end
      end

      # With options
      def ap(value, opts, _env) do
        operation = Keyword.get(opts, :operation, :default)
        right(create_function(operation, value))
      end

      # Using env for dependency injection
      def ap(value, _opts, env) do
        transformer = Keyword.get(env, :transformer)
        right(fn x -> transformer.transform(x, value) end)
      end
  """
  @callback ap(value :: any(), opts :: keyword(), env :: keyword()) ::
              {:ok, (any() -> any())}
              | {:error, any()}
              | Funx.Monad.Either.t((any() -> any()), any())
              | Funx.Monad.Maybe.t((any() -> any()))
end
