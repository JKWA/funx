defmodule Funx.Monad.Either.Dsl.Behaviour do
  @moduledoc """
  Behaviour for modules that participate in the Either DSL.

  A module implementing this behaviour must define `run/3`. The DSL calls
  `run/3` with the current value, the global environment provided to the
  `either` macro, and any options given alongside the module inside the DSL.
  How the return value is treated depends on whether the module is used with
  `bind`, `map`, or `run`.

  ## Examples

  An operation that may fail:

      iex> defmodule MyParseInt do
      ...>   use Funx.Monad.Either
      ...>   @behaviour Funx.Monad.Either.Dsl.Behaviour
      ...>
      ...>   @impl true
      ...>   def run(value, _env, opts) when is_binary(value) do
      ...>     base = Keyword.get(opts, :base, 10)
      ...>
      ...>     case Integer.parse(value, base) do
      ...>       {int, ""} -> right(int)
      ...>       _ -> left("Invalid integer")
      ...>     end
      ...>   end
      ...> end
      iex> MyParseInt.run("42", [], [])
      %Funx.Monad.Either.Right{right: 42}
      iex> MyParseInt.run("FF", [], [base: 16])
      %Funx.Monad.Either.Right{right: 255}
      iex> MyParseInt.run("invalid", [], [])
      %Funx.Monad.Either.Left{left: "Invalid integer"}

  A pure transformation:

      iex> defmodule MyDouble do
      ...>   @behaviour Funx.Monad.Either.Dsl.Behaviour
      ...>
      ...>   @impl true
      ...>   def run(value, _env, _opts) when is_number(value) do
      ...>     value * 2
      ...>   end
      ...> end
      iex> MyDouble.run(21, [], [])
      42

  A validator that uses options:

      iex> defmodule MyPositiveNumber do
      ...>   use Funx.Monad.Either
      ...>   @behaviour Funx.Monad.Either.Dsl.Behaviour
      ...>
      ...>   @impl true
      ...>   def run(value, _env, opts) do
      ...>     min = Keyword.get(opts, :min, 0)
      ...>
      ...>     if value > min do
      ...>       right(value)
      ...>     else
      ...>       left("must be > \#{min}, got: \#{value}")
      ...>     end
      ...>   end
      ...> end
      iex> MyPositiveNumber.run(10, [], [])
      %Funx.Monad.Either.Right{right: 10}
      iex> MyPositiveNumber.run(100, [], [min: 50])
      %Funx.Monad.Either.Right{right: 100}
      iex> MyPositiveNumber.run(-5, [], [min: 0])
      %Funx.Monad.Either.Left{left: "must be > 0, got: -5"}

  ## Usage in the DSL

      iex> defmodule DslParseInt do
      ...>   use Funx.Monad.Either
      ...>   @behaviour Funx.Monad.Either.Dsl.Behaviour
      ...>   @impl true
      ...>   def run(value, _env, _opts) when is_binary(value) do
      ...>     case Integer.parse(value) do
      ...>       {int, ""} -> right(int)
      ...>       _ -> left("Invalid integer")
      ...>     end
      ...>   end
      ...> end
      iex> defmodule DslPositive do
      ...>   use Funx.Monad.Either
      ...>   @behaviour Funx.Monad.Either.Dsl.Behaviour
      ...>   @impl true
      ...>   def run(value, _env, opts) do
      ...>     min = Keyword.get(opts, :min, 0)
      ...>     if value > min, do: right(value), else: left("too small")
      ...>   end
      ...> end
      iex> defmodule DslDouble do
      ...>   @behaviour Funx.Monad.Either.Dsl.Behaviour
      ...>   @impl true
      ...>   def run(value, _env, _opts), do: value * 2
      ...> end
      iex> use Funx.Monad.Either
      iex> either "42" do
      ...>   bind DslParseInt
      ...>   bind {DslPositive, min: 10}
      ...>   map DslDouble
      ...> end
      %Funx.Monad.Either.Right{right: 84}

  `bind` unwraps the current Either value, calls `run/3`, and normalizes the
  result back into Either. `map` unwraps the value, calls `run/3`, and wraps the
  plain result back into Either.
  """

  @doc """
  Runs a single step in an Either pipeline.

  Arguments:

    * value
      The current value provided by the pipeline.

    * env
      The read-only environment supplied by the `either` macro. It is threaded
      through the pipeline unchanged.

    * opts
      Module-specific options passed in the DSL, for example:

          bind ParseInt, base: 16

  Return expectations:

    * With `bind`, `run/3` may return an Either or a result tuple.
    * With `map`, `run/3` should return a plain value.

  Examples:

      # Suitable for bind
      def run(value, _env, _opts) do
        if valid?(value), do: right(value), else: left("invalid")
      end

      # Suitable for map
      def run(value, _env, opts) do
        value * Keyword.get(opts, :multiplier, 2)
      end

      # Returning a result tuple (also suitable for bind)
      def run(value, _env, _opts) do
        case process(value) do
          {:ok, result} -> {:ok, result}
          error -> error
        end
      end
  """
  @callback run(value :: any(), env :: keyword(), opts :: keyword()) ::
              any()
              | Funx.Monad.Either.t(any(), any())
              | {:ok, any()}
              | {:error, any()}
end
