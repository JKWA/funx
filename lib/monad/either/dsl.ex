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
  - Either functions: `filter_or_else`, `or_else`, `map_left`, `flip`, `tap`
  - Validation: `validate` for accumulating multiple errors

  The result format is controlled by the `:as` option (`:either`, `:tuple`, or `:raise`).

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
    compile_pipeline(input, block, :either, [], __CALLER__)
  end

  defmacro either(input, opts, do: block) when is_list(opts) do
    return_as = Keyword.get(opts, :as, :either)

    # Validate return_as at compile time
    unless return_as in [:either, :tuple, :raise] do
      raise CompileError,
        description: "Invalid return type: #{inspect(return_as)}. Must be :either, :tuple, or :raise"
    end

    user_opts = Keyword.delete(opts, :as)
    compile_pipeline(input, block, return_as, user_opts, __CALLER__)
  end

  # ============================================================================
  # SECTION 2 — PIPELINE CONSTRUCTION (COMPILE-TIME STRUCTURE)
  # ============================================================================

  defp compile_pipeline(input, block, return_as, user_env, caller_env) do
    # Parse operations into Step structs (as quoted AST)
    steps_ast =
      block
      |> Parser.parse_operations(caller_env, user_env)
      |> Enum.map(&quote_step/1)

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
  defp quote_step(%Funx.Monad.Either.Dsl.Step.Bind{operation: operation, opts: opts}) do
    quote do
      %Funx.Monad.Either.Dsl.Step.Bind{
        operation: unquote(operation),
        opts: unquote(opts)
      }
    end
  end

  defp quote_step(%Funx.Monad.Either.Dsl.Step.Map{operation: operation, opts: opts}) do
    quote do
      %Funx.Monad.Either.Dsl.Step.Map{
        operation: unquote(operation),
        opts: unquote(opts)
      }
    end
  end

  defp quote_step(%Funx.Monad.Either.Dsl.Step.Ap{applicative: applicative}) do
    quote do
      %Funx.Monad.Either.Dsl.Step.Ap{
        applicative: unquote(applicative)
      }
    end
  end

  defp quote_step(%Funx.Monad.Either.Dsl.Step.EitherFunction{function: func_name, args: args}) do
    quote do
      %Funx.Monad.Either.Dsl.Step.EitherFunction{
        function: unquote(func_name),
        args: unquote(args)
      }
    end
  end

  defp quote_step(%Funx.Monad.Either.Dsl.Step.BindableFunction{function: func_name, args: args}) do
    quote do
      %Funx.Monad.Either.Dsl.Step.BindableFunction{
        function: unquote(func_name),
        args: unquote(args)
      }
    end
  end

end
