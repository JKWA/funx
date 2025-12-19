defmodule Funx.Monad.Maybe.Dsl do
  @moduledoc """
  Provides the `maybe/2` macro for writing declarative pipelines in the Maybe context.

  The DSL lets you express a sequence of operations that may return nothing without manually
  threading values through `bind`, `map`, or `filter`. Input is lifted into Maybe
  automatically, each step runs in order, and the pipeline stops on the first Nothing.

  ## Supported Operations

  - `bind` - for operations that return Maybe, Either, result tuples, or nil
  - `map` - for transformations that return plain values
  - `ap` - for applying a function in a Maybe to a value in a Maybe
  - Maybe functions: `or_else`
  - Protocol functions: `tap` (via Funx.Tappable), `filter`, `filter_map`, `guard` (via Funx.Filterable)

  The result format is controlled by the `:as` option (`:maybe`, `:raise`, or `:nil`).

  ## Short-Circuit Behavior

  The DSL uses fail-fast semantics. When any step returns a `Nothing` value, `Either.Left`, `{:error, _}` tuple, or `nil`,
  the pipeline **stops immediately** and returns `Nothing`. Subsequent steps are never executed.

  Example:

      iex> defmodule GetUser do
      ...>   use Funx.Monad.Maybe
      ...>   @behaviour Funx.Monad.Maybe.Dsl.Behaviour
      ...>   def run_maybe(_value, _env, _opts), do: nothing()
      ...> end
      iex> defmodule CheckPermissions do
      ...>   use Funx.Monad.Maybe
      ...>   @behaviour Funx.Monad.Maybe.Dsl.Behaviour
      ...>   def run_maybe(value, _env, _opts), do: just(value)
      ...> end
      iex> defmodule FormatUser do
      ...>   @behaviour Funx.Monad.Maybe.Dsl.Behaviour
      ...>   def run_maybe(value, _env, _opts), do: "formatted: \#{value}"
      ...> end
      iex> use Funx.Monad.Maybe
      iex> maybe 123 do
      ...>   bind GetUser           # Returns Nothing
      ...>   bind CheckPermissions  # Never runs
      ...>   map FormatUser         # Never runs
      ...> end
      %Funx.Monad.Maybe.Nothing{}

  ## Performance

  The DSL compiles to direct function calls at **compile time**. There is no runtime
  overhead for the DSL itself - it expands into the same code you would write manually
  with `bind`, `map`, etc.

  Example showing compile-time expansion:

      iex> defmodule ParseInt do
      ...>   use Funx.Monad.Maybe
      ...>   @behaviour Funx.Monad.Maybe.Dsl.Behaviour
      ...>   def run_maybe(value, _env, _opts) when is_binary(value) do
      ...>     case Integer.parse(value) do
      ...>       {int, ""} -> just(int)
      ...>       _ -> nothing()
      ...>     end
      ...>   end
      ...> end
      iex> defmodule Double do
      ...>   @behaviour Funx.Monad.Maybe.Dsl.Behaviour
      ...>   def run_maybe(value, _env, _opts), do: value * 2
      ...> end
      iex> use Funx.Monad.Maybe
      iex> maybe "42" do
      ...>   bind ParseInt
      ...>   map Double
      ...> end
      %Funx.Monad.Maybe.Just{value: 84}

  Auto-lifting creates anonymous functions, but these are created at compile time,
  not runtime. For performance-critical hot paths, you may prefer direct combinator
  calls, but the difference is typically negligible.

  ## Transformers

  Transformers allow post-parse optimization and validation of pipelines:

      maybe user_id, transformers: [MyCustomTransformer] do
        bind GetUser
        map Transform
      end

  Transformers run at compile time and create compile-time dependencies.
  See `Funx.Monad.Maybe.Dsl.Transformer` for details on creating custom transformers.

  ## Example

      maybe user_id, as: :nil do
        bind Accounts.get_user()
        bind Policies.ensure_active()
        map fn user -> %{user: user} end
      end

  ## Auto-Lifting of Function Calls

  The DSL automatically lifts certain function call patterns for convenience:

  - `Module.fun()` becomes `&Module.fun/1` (zero-arity qualified calls)
  - `Module.fun(arg)` becomes `fn x -> Module.fun(x, arg) end` (partial application)

  This is particularly useful in filter operations:

      filter &Validator.positive?/1

  This module defines the public DSL entry point. The macro expansion details and
  internal rewrite rules are not part of the public API.
  """

  # credo:disable-for-this-file Credo.Check.Design.AliasUsage
  alias Funx.Monad.Maybe.Dsl.Parser
  alias Funx.Monad.Maybe.Dsl.Transformer

  defmacro __using__(_opts) do
    quote do
      import Funx.Monad.Maybe.Dsl
    end
  end

  # ============================================================================
  # DATA STRUCTURES (DSL STATE)
  # ============================================================================

  defmodule Pipeline do
    @moduledoc false
    defstruct [:input, :steps, :return_as, :user_env]
  end

  # ============================================================================
  # SECTION 1 — PUBLIC MACROS (ENTRY POINT)
  # ============================================================================

  defmacro maybe(input, do: block) do
    compile_pipeline(input, block, :maybe, [], [], __CALLER__)
  end

  defmacro maybe(input, opts, do: block) when is_list(opts) do
    return_as = Keyword.get(opts, :as, :maybe)
    transformers_ast = Keyword.get(opts, :transformers, [])

    # Validate return_as at compile time
    unless return_as in [:maybe, :raise, nil] do
      raise CompileError,
        description: "Invalid return type: #{inspect(return_as)}. Must be :maybe, :raise, or :nil"
    end

    # Validate transformers list (will be evaluated at compile time)
    unless is_list(transformers_ast) do
      raise CompileError,
        description:
          "Invalid transformers: #{inspect(transformers_ast)}. Must be a list of modules."
    end

    # Expand module aliases at compile time
    transformers = Enum.map(transformers_ast, &Macro.expand(&1, __CALLER__))

    # Ensure transformers are compiled and track compile-time dependencies
    # This makes Elixir aware that changes to these modules should trigger recompilation
    Enum.each(transformers, fn transformer ->
      Code.ensure_compiled!(transformer)
    end)

    user_opts = opts |> Keyword.delete(:as) |> Keyword.delete(:transformers)
    compile_pipeline(input, block, return_as, transformers, user_opts, __CALLER__)
  end

  # ============================================================================
  # SECTION 2 — PIPELINE CONSTRUCTION (COMPILE-TIME STRUCTURE)
  # ============================================================================

  defp compile_pipeline(input, block, return_as, transformers, user_env, caller_env) do
    # Parse operations into Step structs
    steps = Parser.parse_operations(block, caller_env, user_env)

    # Apply transformers
    transformed_steps =
      case Transformer.apply_transformers(steps, transformers, user_env) do
        {:ok, result_steps} ->
          result_steps

        {:error, message} when is_binary(message) ->
          raise CompileError, description: message

        {:error, %{__exception__: true} = exception} ->
          raise exception
      end

    # Quote the transformed steps
    steps_ast = Enum.map(transformed_steps, &quote_step/1)

    # Build Pipeline struct (at compile time, this becomes quoted AST)
    quote do
      %Funx.Monad.Maybe.Dsl.Pipeline{
        input: unquote(input),
        steps: unquote(steps_ast),
        return_as: unquote(return_as),
        user_env: unquote(user_env)
      }
      |> Funx.Monad.Maybe.Dsl.Executor.execute_pipeline()
    end
  end

  # Quote Step structs - each type gets its own quoted struct
  defp quote_step(%Funx.Monad.Maybe.Dsl.Step.Bind{
         operation: operation,
         opts: opts,
         __meta__: meta
       }) do
    quote do
      %Funx.Monad.Maybe.Dsl.Step.Bind{
        operation: unquote(operation),
        opts: unquote(opts),
        __meta__: unquote(Macro.escape(meta))
      }
    end
  end

  defp quote_step(%Funx.Monad.Maybe.Dsl.Step.Map{
         operation: operation,
         opts: opts,
         __meta__: meta
       }) do
    quote do
      %Funx.Monad.Maybe.Dsl.Step.Map{
        operation: unquote(operation),
        opts: unquote(opts),
        __meta__: unquote(Macro.escape(meta))
      }
    end
  end

  defp quote_step(%Funx.Monad.Maybe.Dsl.Step.Ap{applicative: applicative, __meta__: meta}) do
    quote do
      %Funx.Monad.Maybe.Dsl.Step.Ap{
        applicative: unquote(applicative),
        __meta__: unquote(Macro.escape(meta))
      }
    end
  end

  defp quote_step(%Funx.Monad.Maybe.Dsl.Step.MaybeFunction{
         function: func_name,
         args: args,
         __meta__: meta
       }) do
    quote do
      %Funx.Monad.Maybe.Dsl.Step.MaybeFunction{
        function: unquote(func_name),
        args: unquote(args),
        __meta__: unquote(Macro.escape(meta))
      }
    end
  end

  defp quote_step(%Funx.Monad.Maybe.Dsl.Step.ProtocolFunction{
         protocol: protocol,
         function: func_name,
         args: args,
         __meta__: meta
       }) do
    quote do
      %Funx.Monad.Maybe.Dsl.Step.ProtocolFunction{
        protocol: unquote(protocol),
        function: unquote(func_name),
        args: unquote(args),
        __meta__: unquote(Macro.escape(meta))
      }
    end
  end
end
