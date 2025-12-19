defmodule Funx.Monad.Maybe.Dsl.Behaviour do
  @moduledoc """
  Behaviour for modules that participate in the Maybe DSL.

  A module implementing this behaviour must define `run_maybe/3`. The DSL calls
  `run_maybe/3` with the current value, the global environment provided to the
  `maybe` macro, and any options given alongside the module inside the DSL.
  How the return value is treated depends on whether the module is used with
  `bind` or `map`.

  ## Examples

  An operation that may return nothing:

      iex> defmodule MyParseInt do
      ...>   use Funx.Monad.Maybe
      ...>   @behaviour Funx.Monad.Maybe.Dsl.Behaviour
      ...>
      ...>   @impl true
      ...>   def run_maybe(value, _env, opts) when is_binary(value) do
      ...>     base = Keyword.get(opts, :base, 10)
      ...>
      ...>     case Integer.parse(value, base) do
      ...>       {int, ""} -> just(int)
      ...>       _ -> nothing()
      ...>     end
      ...>   end
      ...> end
      iex> MyParseInt.run_maybe("42", [], [])
      %Funx.Monad.Maybe.Just{value: 42}
      iex> MyParseInt.run_maybe("FF", [], [base: 16])
      %Funx.Monad.Maybe.Just{value: 255}
      iex> MyParseInt.run_maybe("invalid", [], [])
      %Funx.Monad.Maybe.Nothing{}

  A pure transformation:

      iex> defmodule MyDouble do
      ...>   @behaviour Funx.Monad.Maybe.Dsl.Behaviour
      ...>
      ...>   @impl true
      ...>   def run_maybe(value, _env, _opts) when is_number(value) do
      ...>     value * 2
      ...>   end
      ...> end
      iex> MyDouble.run_maybe(21, [], [])
      42

  A validator that uses options:

      iex> defmodule MyPositiveNumber do
      ...>   use Funx.Monad.Maybe
      ...>   @behaviour Funx.Monad.Maybe.Dsl.Behaviour
      ...>
      ...>   @impl true
      ...>   def run_maybe(value, _env, opts) do
      ...>     min = Keyword.get(opts, :min, 0)
      ...>
      ...>     if value > min do
      ...>       just(value)
      ...>     else
      ...>       nothing()
      ...>     end
      ...>   end
      ...> end
      iex> MyPositiveNumber.run_maybe(10, [], [])
      %Funx.Monad.Maybe.Just{value: 10}
      iex> MyPositiveNumber.run_maybe(100, [], [min: 50])
      %Funx.Monad.Maybe.Just{value: 100}
      iex> MyPositiveNumber.run_maybe(-5, [], [min: 0])
      %Funx.Monad.Maybe.Nothing{}

  ## Usage in the DSL

      iex> defmodule DslParseInt do
      ...>   use Funx.Monad.Maybe
      ...>   @behaviour Funx.Monad.Maybe.Dsl.Behaviour
      ...>   @impl true
      ...>   def run_maybe(value, _env, _opts) when is_binary(value) do
      ...>     case Integer.parse(value) do
      ...>       {int, ""} -> just(int)
      ...>       _ -> nothing()
      ...>     end
      ...>   end
      ...> end
      iex> defmodule DslPositive do
      ...>   use Funx.Monad.Maybe
      ...>   @behaviour Funx.Monad.Maybe.Dsl.Behaviour
      ...>   @impl true
      ...>   def run_maybe(value, _env, opts) do
      ...>     min = Keyword.get(opts, :min, 0)
      ...>     if value > min, do: just(value), else: nothing()
      ...>   end
      ...> end
      iex> defmodule DslDouble do
      ...>   @behaviour Funx.Monad.Maybe.Dsl.Behaviour
      ...>   @impl true
      ...>   def run_maybe(value, _env, _opts), do: value * 2
      ...> end
      iex> use Funx.Monad.Maybe
      iex> maybe "42" do
      ...>   bind DslParseInt
      ...>   bind {DslPositive, min: 10}
      ...>   map DslDouble
      ...> end
      %Funx.Monad.Maybe.Just{value: 84}

  `bind` unwraps the current Maybe value, calls `run_maybe/3`, and normalizes the
  result back into Maybe. `map` unwraps the value, calls `run_maybe/3`, and wraps the
  plain result back into Maybe.
  """

  @doc """
  Runs a single step in a Maybe pipeline.

  Arguments:

    * value
      The current value provided by the pipeline.

    * env
      The read-only environment supplied by the `maybe` macro. It is threaded
      through the pipeline unchanged.

    * opts
      Module-specific options passed in the DSL, for example:

          bind ParseInt, base: 16

  Return expectations:

    * With `bind`, `run_maybe/3` may return a Maybe or a result tuple.
    * With `map`, `run_maybe/3` should return a plain value.

  Examples:

      # Suitable for bind
      def run_maybe(value, _env, _opts) do
        if valid?(value), do: just(value), else: nothing()
      end

      # Suitable for map
      def run_maybe(value, _env, opts) do
        value * Keyword.get(opts, :multiplier, 2)
      end

      # Returning a result tuple (also suitable for bind)
      def run_maybe(value, _env, _opts) do
        case process(value) do
          {:ok, result} -> {:ok, result}
          error -> error
        end
      end
  """
  @callback run_maybe(value :: any(), env :: keyword(), opts :: keyword()) ::
              any()
              | Funx.Monad.Maybe.t(any())
              | {:ok, any()}
              | {:error, any()}
end
