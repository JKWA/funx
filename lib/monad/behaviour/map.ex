defmodule Funx.Monad.Behaviour.Map do
  @moduledoc """
  Behaviour for map operations across monad DSLs.

  Map is a **universal functor operation** that works identically across all monads.
  Unlike `bind`, which handles failure, `map` simply transforms values when they exist.

  The same `map` module can be used in Either DSL, Maybe DSL, List, IO, or any
  other monad - the transformation logic is completely generic.

  ## Contract

  ```elixir
  @callback map(value :: any(), opts :: keyword(), env :: keyword()) :: any()
  ```

  ## Arguments

  - `value` - The value to transform
  - `opts` - Keyword list of options (module-specific configuration)
  - `env` - Environment/context from DSL (for Reader-like dependency injection)

  ## Return Values

  Map should return **the transformed value directly** as a plain value.
  The DSL handles wrapping the result in the appropriate monad type.

  **Important**: Unlike `Bind`, map does not return Either, Maybe, or result tuples.
  It returns plain values because map is about transformation, not control flow.

  ## Semantic Rules

  1. **Arguments strictly ordered**: value, opts, env
  2. **May use env** for Reader-like dependency injection (only way to access env - functions cannot)
  3. **Pure transformation** - should not fail (use Behaviour.Bind for operations that can fail)
  4. **Returns plain value** - not wrapped in monad (DSL handles wrapping)
  5. **Monad-agnostic** - same transformation works across all monad DSLs

  ## Monad Universality

  The beauty of `map` is that it works the same way in every monad:

  - **Either**: `Right(value)` → apply map → `Right(transformed)`; `Left` is skipped
  - **Maybe**: `Just(value)` → apply map → `Just(transformed)`; `Nothing` is skipped
  - **List**: `[a, b, c]` → apply map → `[f(a), f(b), f(c)]`

  The same `map` module behaves consistently across all these contexts.

  ## Examples

  ### Basic Transformation

  ```elixir
  defmodule Double do
    @behaviour Funx.Monad.Behaviour.Map

    @impl true
    def map(value, _opts, _env) when is_number(value) do
      value * 2
    end
  end

  # Works identically in Either DSL
  use Funx.Monad.Either

  either 21 do
    map Double
  end
  #=> %Right{right: 42}

  # Works identically in Maybe DSL
  use Funx.Monad.Maybe

  maybe 21 do
    map Double
  end
  #=> %Just{value: 42}

  # Same transformation, different monad contexts
  ```

  ### With Options

  ```elixir
  defmodule Multiplier do
    @behaviour Funx.Monad.Behaviour.Map

    @impl true
    def map(value, opts, _env) when is_number(value) do
      factor = Keyword.get(opts, :factor, 1)
      value * factor
    end
  end

  # In Either DSL
  either 10 do
    map {Multiplier, factor: 5}
  end
  #=> %Right{right: 50}

  # In Maybe DSL
  maybe 10 do
    map {Multiplier, factor: 5}
  end
  #=> %Just{value: 50}
  ```

  ### Composable Transformations

  ```elixir
  defmodule ToUpperCase do
    @behaviour Funx.Monad.Behaviour.Map

    @impl true
    def map(value, _opts, _env) when is_binary(value) do
      String.upcase(value)
    end
  end

  defmodule AddPrefix do
    @behaviour Funx.Monad.Behaviour.Map

    @impl true
    def map(value, opts, _env) when is_binary(value) do
      prefix = Keyword.get(opts, :prefix, "")
      prefix <> value
    end
  end

  # Compose maps in Either
  either "hello" do
    map ToUpperCase
    map {AddPrefix, prefix: ">> "}
  end
  #=> %Right{right: ">> HELLO"}

  # Same composition works in Maybe
  maybe "hello" do
    map ToUpperCase
    map {AddPrefix, prefix: ">> "}
  end
  #=> %Just{value: ">> HELLO"}
  ```
  """

  @doc """
  Transforms a value.

  Arguments:

    * value - The current value in the pipeline
    * opts - Module-specific options passed in the DSL
    * env - Environment/context from the DSL (for dependency injection)

  Returns the transformed value directly (not wrapped in a monad).

  Examples:

      # Simple transformation
      def map(value, _opts, _env) do
        value * 2
      end

      # With options
      def map(value, opts, _env) do
        multiplier = Keyword.get(opts, :multiplier, 1)
        value * multiplier
      end

      # Using env for dependency injection
      def map(value, _opts, env) do
        formatter = Keyword.get(env, :formatter)
        formatter.format(value)
      end
  """
  @callback map(value :: any(), opts :: keyword(), env :: keyword()) :: any()
end
