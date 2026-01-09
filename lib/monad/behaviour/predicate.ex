defmodule Funx.Monad.Behaviour.Predicate do
  @moduledoc """
  Behaviour for predicate operations across monad DSLs.

  Predicate is a **universal filtering operation** that works identically across all monads.
  It evaluates a condition and returns a boolean to determine if a value should pass through.

  The same `predicate` module can be used in Either DSL (filter_or_else), Maybe DSL (filter),
  or any other monad - the logic is completely generic.

  ## Contract

  ```elixir
  @callback predicate(value :: any(), opts :: keyword(), env :: map()) :: boolean()
  ```

  ## Arguments

  - `value` - The value to test
  - `opts` - Keyword list of options (module-specific configuration)
  - `env` - Environment/context from DSL (for Reader-like dependency injection)

  ## Return Values

  Predicate should return **a boolean** indicating whether the value passes the test.
  The DSL handles the filtering logic based on the boolean result.

  ## Semantic Rules

  1. **Arguments strictly ordered**: value, opts, env
  2. **May use env** for Reader-like dependency injection (same as other behaviors)
  3. **Returns boolean** - `true` to keep the value, `false` to filter it out
  4. **Monad-agnostic** - same predicate works across all monad DSLs

  ## Monad Universality

  The beauty of `predicate` is that it works the same way in every monad:

  - **Either**: `filter_or_else` uses predicate to keep `Right` or convert to `Left`
  - **Maybe**: `filter` uses predicate to keep `Just` or convert to `Nothing`
  - **List**: `filter` uses predicate to keep or remove elements

  The same `predicate` module behaves consistently across all these contexts.

  ## Examples

  ### Basic Predicate

  ```elixir
  defmodule IsPositive do
    @behaviour Funx.Monad.Behaviour.Predicate

    @impl true
    def predicate(value, _opts, _env) when is_number(value) do
      value > 0
    end

    def predicate(_value, _opts, _env), do: false
  end

  # Works in Either DSL
  use Funx.Monad.Either

  either 10 do
    filter_or_else IsPositive, fn -> "not positive" end
  end
  #=> %Right{right: 10}

  either -5 do
    filter_or_else IsPositive, fn -> "not positive" end
  end
  #=> %Left{left: "not positive"}

  # Works in Maybe DSL
  use Funx.Monad.Maybe

  maybe 10 do
    filter IsPositive
  end
  #=> %Just{value: 10}

  maybe -5 do
    filter IsPositive
  end
  #=> %Nothing{}
  ```

  ### With Options

  ```elixir
  defmodule InRange do
    @behaviour Funx.Monad.Behaviour.Predicate

    @impl true
    def predicate(value, opts, _env) when is_number(value) do
      min = Keyword.get(opts, :min, 0)
      max = Keyword.get(opts, :max, 100)
      value >= min and value <= max
    end

    def predicate(_value, _opts, _env), do: false
  end

  # In Either DSL
  either 50 do
    filter_or_else {InRange, min: 0, max: 100}, fn -> "out of range" end
  end
  #=> %Right{right: 50}

  # In Maybe DSL
  maybe 50 do
    filter {InRange, min: 0, max: 100}
  end
  #=> %Just{value: 50}
  ```

  ### Composable Predicates

  ```elixir
  defmodule IsEven do
    @behaviour Funx.Monad.Behaviour.Predicate

    @impl true
    def predicate(value, _opts, _env) when is_integer(value) do
      rem(value, 2) == 0
    end

    def predicate(_value, _opts, _env), do: false
  end

  defmodule IsPositive do
    @behaviour Funx.Monad.Behaviour.Predicate

    @impl true
    def predicate(value, _opts, _env) when is_number(value) do
      value > 0
    end

    def predicate(_value, _opts, _env), do: false
  end

  # Compose predicates in Either
  either 10 do
    filter_or_else IsPositive, fn -> "not positive" end
    filter_or_else IsEven, fn -> "not even" end
  end
  #=> %Right{right: 10}

  either 11 do
    filter_or_else IsPositive, fn -> "not positive" end
    filter_or_else IsEven, fn -> "not even" end
  end
  #=> %Left{left: "not even"}

  # Same composition works in Maybe
  maybe 10 do
    filter IsPositive
    filter IsEven
  end
  #=> %Just{value: 10}
  ```

  ## Environment Support

  Predicates support the `env` parameter for Reader-like dependency injection, maintaining
  consistency with other monad behaviors. While most predicates are pure boolean tests that
  only need the value and options, the `env` parameter allows for stateful or context-dependent
  predicates when needed (e.g., checking against a dynamic threshold from a database).
  """

  @doc """
  Tests whether a value satisfies a condition.

  Arguments:

    * value - The current value in the pipeline
    * opts - Module-specific options passed in the DSL
    * env - Environment/context from the DSL (for Reader-like dependency injection)

  Returns a boolean indicating whether the value passes the test.

  Examples:

      # Simple predicate
      def predicate(value, _opts, _env) do
        value > 0
      end

      # With options
      def predicate(value, opts, _env) do
        threshold = Keyword.get(opts, :threshold, 0)
        value > threshold
      end

      # Using env for context-dependent predicates
      def predicate(value, _opts, env) do
        max_allowed = Map.get(env, :max_threshold, 100)
        value <= max_allowed
      end

      # Type-specific predicates
      def predicate(value, _opts, _env) when is_number(value) do
        value > 0
      end

      def predicate(_value, _opts, _env), do: false
  """
  @callback predicate(value :: any(), opts :: keyword(), env :: map()) :: boolean()
end
