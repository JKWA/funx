defmodule Funx.Monad.Either.Dsl do
  @moduledoc """
  Provides the `either/2` macro for writing declarative pipelines in the Either context.

  The DSL lets you express a sequence of operations that may fail without manually
  threading values through `bind`, `map`, or `map_left`. Input is lifted into Either
  automatically, each step runs in order, and the pipeline stops on the first error.

  ## Core Principle

  This DSL is **pure syntax sugar** over `Funx.Monad.bind/2`, `Funx.Monad.map/2`, and
  related functions. It transforms nice block syntax into Elixir pipe chains. All the
  actual monad logic, error handling, and validation happens at runtime in the
  underlying `Funx.Monad` and `Funx.Monad.Either` modules.

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
  alias Funx.Monad.Either
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

  defmodule Step do
    @moduledoc false
    defstruct [:type, :operation, :opts]
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
      |> Funx.Monad.Either.Dsl.execute_pipeline()
    end
  end

  # Quote a Step struct, handling functions specially
  defp quote_step(%Step{type: type, operation: operation, opts: opts}) do
    quote do
      %Funx.Monad.Either.Dsl.Step{
        type: unquote(type),
        operation: unquote(operation),
        opts: unquote(opts)
      }
    end
  end

  # ============================================================================
  # SECTION 3 — RUNTIME HELPERS
  # ============================================================================

  # Lift input into Either context

  @doc false
  @spec lift_input(any() | Either.t(any(), any()) | {:ok, any()} | {:error, any()}) ::
          Either.t(any(), any())
  def lift_input(input) do
    case input do
      %Either.Right{} = either -> either
      %Either.Left{} = either -> either
      {:ok, value} -> Either.right(value)
      {:error, reason} -> Either.left(reason)
      value -> Either.pure(value)
    end
  end

  # ============================================================================
  # Normalize tuple/Either returns (runtime normalization)
  # ============================================================================

  @doc false
  @spec normalize_run_result(tuple() | Either.t(any(), any())) :: Either.t(any(), any())
  def normalize_run_result(result) do
    case result do
      {:ok, value} ->
        Either.right(value)

      {:error, reason} ->
        Either.left(reason)

      %Either.Right{} = either ->
        either

      %Either.Left{} = either ->
        either

      other ->
        raise ArgumentError, """
        Module run/3 callback must return either an Either struct or a result tuple.
        Got: #{inspect(other)}

        Expected return types:
          - Either: right(value) or left(error)
          - Result tuple: {:ok, value} or {:error, reason}
        """
    end
  end

  # ============================================================================
  # SECTION 4 — RUNTIME EXECUTION ENGINE
  # ============================================================================

  @doc false
  def execute_pipeline(%Pipeline{} = pipeline) do
    # Lift input
    initial = lift_input(pipeline.input)

    # Execute each step
    result =
      Enum.reduce(pipeline.steps, initial, fn step, acc ->
        execute_step(acc, step, pipeline.user_env)
      end)

    # Wrap with return type
    wrap_result(result, pipeline.return_as)
  end

  # Step execution dispatcher
  defp execute_step(either_value, %Step{type: type} = step, user_env) do
    case type do
      :bind -> handle_bind(either_value, step, user_env)
      :map -> handle_map(either_value, step, user_env)
      :ap -> handle_ap(either_value, step)
      :either_function -> handle_either_function(either_value, step)
      :bindable_function -> handle_bindable_function(either_value, step)
    end
  end

  # Step handlers
  defp handle_bind(either_value, %Step{operation: operation, opts: opts}, user_env) do
    Funx.Monad.bind(either_value, fn value ->
      result = call_operation(operation, value, opts, user_env)
      normalize_run_result(result)
    end)
  end

  defp handle_map(either_value, %Step{operation: operation, opts: opts}, user_env) do
    Funx.Monad.map(either_value, fn value ->
      call_operation(operation, value, opts, user_env)
    end)
  end

  defp handle_ap(either_value, %Step{operation: operation}) do
    Funx.Monad.ap(either_value, operation)
  end

  defp handle_either_function(either_value, %Step{operation: {func_name, args}}) do
    apply(Either, func_name, [either_value | args])
  end

  defp handle_bindable_function(either_value, %Step{operation: {func_name, args}}) do
    Funx.Monad.bind(either_value, fn value ->
      apply(Either, func_name, [value | args])
    end)
  end

  # Call an operation (module or function)
  defp call_operation(module, value, opts, user_env) when is_atom(module) do
    module.run(value, opts, user_env)
  end

  defp call_operation(func, value, _opts, _user_env) when is_function(func) do
    func.(value)
  end

  # Wrap result based on return type
  @doc false
  def wrap_result(result, :either) do
    case result do
      %Either.Right{} -> result
      %Either.Left{} -> result
      other ->
        raise ArgumentError, """
        Expected Either struct when using as: :either, but got: #{inspect(other)}
        """
    end
  end

  @doc false
  def wrap_result(result, :tuple), do: Either.to_result(result)

  @doc false
  def wrap_result(result, :raise), do: Either.to_try!(result)
end
