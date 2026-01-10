defmodule Funx.Monad.Maybe.Dsl.Behaviour do
  @moduledoc """
  Behaviour for modules that participate in the Maybe DSL.

  The Maybe DSL uses specific behaviors based on the operation's purpose:

  - `Funx.Monad.Behaviour.Bind` for operations that can fail (used with `bind`, `tap`, `filter_map`)
  - `Funx.Monad.Behaviour.Map` for pure transformations (used with `map`)
  - `Funx.Monad.Behaviour.Predicate` for boolean tests (used with `filter`, `guard`)
  - `Funx.Monad.Behaviour.Ap` for applicative functors (used with `ap`)

  This provides better type safety and clearer semantics than a generic callback.

  ## Example

  For an operation that can fail:

      defmodule MyParseInt do
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

  For a pure transformation:

      defmodule MyDouble do
        @behaviour Funx.Monad.Behaviour.Map

        @impl true
        def map(value, _opts, _env) when is_number(value) do
          value * 2
        end
      end

  For a predicate test:

      defmodule IsPositive do
        @behaviour Funx.Monad.Behaviour.Predicate

        @impl true
        def predicate(value, _opts, _env) when is_number(value) do
          value > 0
        end

        def predicate(_value, _opts, _env), do: false
      end

  """
end
