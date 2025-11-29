defmodule Funx.Monad.Dsl.Behaviour do
  @moduledoc """
  Behaviour for modules that can be used with the Either DSL.

  Modules implementing this behaviour must define `run/2` which receives a value and environment.
  The DSL keywords (`bind`, `map`, `run`) determine how the result is handled.

  ## Examples

  An operation that might fail:

      defmodule ParseInt do
        @behaviour Funx.Monad.Dsl.Behaviour

        import Funx.Monad.Either

        @impl true
        def run(value, env \\ []) when is_binary(value) do
          base = Keyword.get(env, :base, 10)
          case Integer.parse(value, base) do
            {int, ""} -> right(int)
            _ -> left("Invalid integer")
          end
        end
      end

  A pure transformation:

      defmodule Double do
        @behaviour Funx.Monad.Dsl.Behaviour

        @impl true
        def run(value, _env \\ []) when is_number(value) do
          value * 2
        end
      end

  A validator that uses environment:

      defmodule PositiveNumber do
        @behaviour Funx.Monad.Dsl.Behaviour

        import Funx.Monad.Either

        @impl true
        def run(value, env \\ []) do
          min = Keyword.get(env, :min, 0)
          if value > min do
            right(value)
          else
            left("must be > \#{min}, got: \#{value}")
          end
        end
      end

  ## Usage in DSL

      use Funx.Monad.Either

      either "FF", base: 16, min: 10 do
        bind ParseInt        # Unwraps, calls run/2, normalizes (Either or tuple → Either)
        bind PositiveNumber  # Unwraps, calls run/2, normalizes
        map Double           # Unwraps, calls run/2, wraps (plain value → Either)
      end

  The DSL keywords determine behavior:
  - `bind` - Unwraps Either, calls `run/2`, normalizes result to Either
  - `map` - Unwraps Either, calls `run/2`, wraps result in Either
  - `run` - Calls `run/2` with Either directly, no normalization
  """

  @doc """
  Processes a value with environment.

  The second argument receives read-only environment passed to the `either` macro (minus `as:`).
  This environment acts like a Reader monad, providing configuration that is threaded through
  the entire pipeline without mutation.

  The return value depends on how the module is used:
  - With `bind`: Can return Either or result tuple - will be normalized
  - With `map`: Should return a plain value - will be wrapped in Either
  - With `run`: Returns anything - passed as-is to next operation

  ## Examples

      # Returns Either (for use with bind)
      def run(value, env) do
        if valid?(value, env) do
          right(value)
        else
          left("invalid")
        end
      end

      # Returns plain value (for use with map)
      def run(value, env) do
        value * Keyword.get(env, :multiplier, 2)
      end

      # Returns tuple (for use with bind)
      def run(value, _env) do
        case process(value) do
          {:ok, result} -> {:ok, result}
          error -> error
        end
      end
  """
  @callback run(value :: any(), env :: keyword()) ::
              any() | Funx.Monad.Either.t() | {:ok, any()} | {:error, any()}
end
