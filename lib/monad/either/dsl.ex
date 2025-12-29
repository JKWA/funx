defmodule Funx.Monad.Either.Dsl do
  @moduledoc """
  Provides the `either/2` macro for writing declarative pipelines in the Either context.

  The DSL lets you express a sequence of operations that may fail without manually
  threading values through `bind`, `map`, or `map_left`. Input is lifted into Either
  automatically, each step runs in order, and the pipeline stops on the first error.

  ## Supported Operations

  - `bind` - for operations that return Either or result tuples
  - `map` - for transformations that return plain values
  - `ap` - for applying a function in an Either to a value in an Either
  - Either functions: `filter_or_else`, `or_else`, `map_left`, `flip`
  - Protocol functions: `tap` (via Funx.Tappable)
  - Validation: `validate` for accumulating multiple errors

  The result format is controlled by the `:as` option (`:either`, `:tuple`, or `:raise`).

  ## Error Handling Strategy

  **Short-Circuit Behavior:** The DSL uses fail-fast semantics. When any step returns
  a `Left` value or `{:error, reason}` tuple, the pipeline **stops immediately** and
  returns that error. Subsequent steps are never executed.

  Example:

      iex> defmodule GetUser do
      ...>   use Funx.Monad.Either
      ...>   @behaviour Funx.Monad.Either.Dsl.Behaviour
      ...>   def run(_value, _env, _opts), do: left("not found")
      ...> end
      iex> defmodule CheckPermissions do
      ...>   use Funx.Monad.Either
      ...>   @behaviour Funx.Monad.Either.Dsl.Behaviour
      ...>   def run(value, _env, _opts), do: right(value)
      ...> end
      iex> defmodule FormatUser do
      ...>   @behaviour Funx.Monad.Either.Dsl.Behaviour
      ...>   def run(value, _env, _opts), do: "formatted: \#{value}"
      ...> end
      iex> use Funx.Monad.Either
      iex> either 123 do
      ...>   bind GetUser           # Returns Left("not found")
      ...>   bind CheckPermissions  # Never runs
      ...>   map FormatUser         # Never runs
      ...> end
      %Funx.Monad.Either.Left{left: "not found"}

  **Exception:** The `validate` operation uses applicative semantics and accumulates
  **all** validation errors before returning:

  Example:

      iex> use Funx.Monad.Either
      iex> positive? = fn x -> if x > 0, do: right(x), else: left("not positive") end
      iex> even? = fn x -> if rem(x, 2) == 0, do: right(x), else: left("not even") end
      iex> less_than_100? = fn x -> if x < 100, do: right(x), else: left("too large") end
      iex> either -5 do
      ...>   validate [positive?, even?, less_than_100?]
      ...> end
      %Funx.Monad.Either.Left{left: ["not positive", "not even"]}

  ## Performance

  The DSL compiles to direct function calls at **compile time**. There is no runtime
  overhead for the DSL itself - it expands into the same code you would write manually
  with `bind`, `map`, etc.

  Example showing compile-time expansion:

      iex> defmodule ParseInt do
      ...>   use Funx.Monad.Either
      ...>   @behaviour Funx.Monad.Either.Dsl.Behaviour
      ...>   def run(value, _env, _opts) when is_binary(value) do
      ...>     case Integer.parse(value) do
      ...>       {int, ""} -> right(int)
      ...>       _ -> left("invalid integer")
      ...>     end
      ...>   end
      ...> end
      iex> defmodule Double do
      ...>   @behaviour Funx.Monad.Either.Dsl.Behaviour
      ...>   def run(value, _env, _opts), do: value * 2
      ...> end
      iex> use Funx.Monad.Either
      iex> either "42" do
      ...>   bind ParseInt
      ...>   map Double
      ...> end
      %Funx.Monad.Either.Right{right: 84}

  Auto-lifting creates anonymous functions, but these are created at compile time,
  not runtime. For performance-critical hot paths, you may prefer direct combinator
  calls, but the difference is typically negligible.

  ## Transformers

  Transformers allow post-parse optimization and validation of pipelines:

      either user_id, transformers: [MyCustomTransformer] do
        bind GetUser
        map Transform
      end

  Transformers run at compile time and create compile-time dependencies.

  ## Example

      either user_id, as: :tuple do
        bind Accounts.get_user()
        bind Policies.ensure_active()
        map fn user -> %{user: user} end
      end

  ## Auto-Lifting of Function Calls

  The DSL automatically lifts certain function call patterns for convenience:

  - `Module.fun()` becomes `&Module.fun/1` (zero-arity qualified calls)
  - `Module.fun(arg)` becomes `fn x -> Module.fun(x, arg) end` (partial application)

  This is particularly useful in validator lists:

      validate [Validator.positive?(), Validator.even?()]
      # Becomes: validate [&Validator.positive?/1, &Validator.even?/1]

  This module defines the public DSL entry point. The macro expansion details and
  internal rewrite rules are not part of the public API.
  """

  # credo:disable-for-this-file Credo.Check.Design.AliasUsage
  alias Funx.Monad.Either.Dsl.Parser
  alias Funx.Monad.Either.Dsl.Transformer

  defmacro __using__(_opts) do
    quote do
      import Funx.Monad.Either.Dsl
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

  defmacro either(input, do: block) do
    compile_pipeline(input, block, :either, [], [], __CALLER__)
  end

  defmacro either(input, opts, do: block) when is_list(opts) do
    return_as = Keyword.get(opts, :as, :either)
    transformers_ast = Keyword.get(opts, :transformers, [])

    # Validate return_as at compile time
    unless return_as in [:either, :tuple, :raise] do
      raise CompileError,
        description:
          "Invalid return type: #{inspect(return_as)}. Must be :either, :tuple, or :raise"
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
      %Funx.Monad.Either.Dsl.Pipeline{
        input: unquote(input),
        steps: unquote(steps_ast),
        return_as: unquote(return_as),
        user_env: unquote(user_env)
      }
      |> Funx.Monad.Either.Dsl.Executor.execute_pipeline()
    end
  end

  # Quote Step structs - each type gets its own quoted struct
  defp quote_step(%Funx.Monad.Either.Dsl.Step.Bind{
         operation: operation,
         opts: opts,
         __meta__: meta
       }) do
    quote do
      %Funx.Monad.Either.Dsl.Step.Bind{
        operation: unquote(operation),
        opts: unquote(opts),
        __meta__: unquote(Macro.escape(meta))
      }
    end
  end

  defp quote_step(%Funx.Monad.Either.Dsl.Step.Map{
         operation: operation,
         opts: opts,
         __meta__: meta
       }) do
    quote do
      %Funx.Monad.Either.Dsl.Step.Map{
        operation: unquote(operation),
        opts: unquote(opts),
        __meta__: unquote(Macro.escape(meta))
      }
    end
  end

  defp quote_step(%Funx.Monad.Either.Dsl.Step.Ap{applicative: applicative, __meta__: meta}) do
    quote do
      %Funx.Monad.Either.Dsl.Step.Ap{
        applicative: unquote(applicative),
        __meta__: unquote(Macro.escape(meta))
      }
    end
  end

  defp quote_step(%Funx.Monad.Either.Dsl.Step.EitherFunction{
         function: func_name,
         args: args,
         __meta__: meta
       }) do
    quote do
      %Funx.Monad.Either.Dsl.Step.EitherFunction{
        function: unquote(func_name),
        args: unquote(args),
        __meta__: unquote(Macro.escape(meta))
      }
    end
  end

  defp quote_step(%Funx.Monad.Either.Dsl.Step.BindableFunction{
         function: func_name,
         args: args,
         __meta__: meta
       }) do
    quote do
      %Funx.Monad.Either.Dsl.Step.BindableFunction{
        function: unquote(func_name),
        args: unquote(args),
        __meta__: unquote(Macro.escape(meta))
      }
    end
  end

  defp quote_step(%Funx.Monad.Either.Dsl.Step.ProtocolFunction{
         protocol: protocol,
         function: func_name,
         args: args,
         __meta__: meta
       }) do
    quote do
      %Funx.Monad.Either.Dsl.Step.ProtocolFunction{
        protocol: unquote(protocol),
        function: unquote(func_name),
        args: unquote(args),
        __meta__: unquote(Macro.escape(meta))
      }
    end
  end
end
