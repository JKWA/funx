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

  # Functions that operate on Either directly (not unwrapped)
  @either_functions [:filter_or_else, :or_else, :map_left, :flip, :tap]

  # Functions that work on unwrapped values (auto-bind)
  @bindable_functions [:validate]

  defmacro __using__(_opts) do
    quote do
      import Funx.Monad.Either.Dsl
    end
  end

  # ============================================================================
  # Data structures - the "DSL state"
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
  # Entry: either(...)
  # ============================================================================

  defmacro either(input, do: block) do
    operations = extract_operations(block)
    compile_pipeline(input, operations, :either, [], __CALLER__)
  end

  defmacro either(input, opts, do: block) when is_list(opts) do
    return_as = Keyword.get(opts, :as, :either)

    # Validate return_as at compile time
    unless return_as in [:either, :tuple, :raise] do
      raise CompileError,
        description: "Invalid return type: #{inspect(return_as)}. Must be :either, :tuple, or :raise"
    end

    user_opts = Keyword.delete(opts, :as)
    operations = extract_operations(block)
    compile_pipeline(input, operations, return_as, user_opts, __CALLER__)
  end

  # ============================================================================
  # Extract operations
  # ============================================================================

  defp extract_operations({:__block__, _meta, lines}) when is_list(lines), do: lines
  defp extract_operations(single_line), do: [single_line]

  # ============================================================================
  # Compile the pipeline - builds data, not code
  # ============================================================================

  defp compile_pipeline(input, operations, return_as, user_env, caller_env) do
    # Parse operations into Step structs (as quoted AST)
    steps_ast =
      Enum.map(operations, fn operation ->
        step = parse_operation_to_step(operation, user_env, caller_env)
        # Quote the step struct, preserving functions properly
        quote_step(step)
      end)

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
  # Parse operations into Step structs (data, not code)
  # ============================================================================

  defp parse_operation_to_step(operation_ast, user_env, caller_env) do
    case operation_ast do
      {:bind, _, args} ->
        {operation, opts} = parse_operation_args(args)
        lifted_op = lift_call_to_unary(operation, caller_env) || operation
        # Expand module aliases to actual atoms at compile time
        expanded_op = expand_module_alias(lifted_op, caller_env)
        %Step{type: :bind, operation: expanded_op, opts: opts}

      {:map, _, args} ->
        {operation, opts} = parse_operation_args(args)
        lifted_op = lift_call_to_unary(operation, caller_env) || operation
        # Expand module aliases to actual atoms at compile time
        expanded_op = expand_module_alias(lifted_op, caller_env)
        %Step{type: :map, operation: expanded_op, opts: opts}

      {:ap, _, args} ->
        {operation, opts} = parse_operation_args(args)
        %Step{type: :ap, operation: operation, opts: opts}

      {func_name, _meta, args} when is_atom(func_name) and is_list(args) ->
        parse_either_function_to_step(func_name, args, user_env, caller_env)

      {:__aliases__, _, _} = module_alias ->
        raise CompileError,
          description: """
          Invalid operation: #{Macro.to_string(module_alias)}

          Modules must be used with a keyword:
            bind #{Macro.to_string(module_alias)}
            map #{Macro.to_string(module_alias)}
            ap #{Macro.to_string(module_alias)}
          """

      other ->
        raise CompileError,
          description:
            "Invalid operation: #{inspect(other)}. Use 'bind', 'map', 'ap', or Either functions."
    end
  end

  # Expand module aliases to actual module atoms at compile time
  defp expand_module_alias({:__aliases__, _, _} = module_alias, caller_env) do
    Macro.expand(module_alias, caller_env)
  end

  defp expand_module_alias(other, _caller_env), do: other

  # ============================================================================
  # Parse Either.function calls into Step structs
  # ============================================================================

  defp parse_either_function_to_step(func_name, args, user_env, caller_env) do
    # Lift function calls and transform modules in arguments
    transformed_args =
      Enum.map(args, fn arg ->
        lifted = lift_call_to_unary(arg, caller_env) || arg
        transform_modules_to_functions(lifted, user_env, caller_env)
      end)

    cond do
      func_name in @either_functions ->
        %Step{type: :either_function, operation: {func_name, transformed_args}, opts: []}

      func_name in @bindable_functions ->
        %Step{type: :bindable_function, operation: {func_name, transformed_args}, opts: []}

      true ->
        raise CompileError,
          description: """
          Invalid operation: #{func_name}

          Bare function calls are not allowed in the DSL pipeline.

          If you meant to call an Either function, only these are allowed:
            #{inspect(@either_functions ++ @bindable_functions)}

          If you meant to use a custom function, you must use 'bind' or 'map':
            bind #{func_name}(...)
            map #{func_name}(...)

          Or use a function capture:
            map &#{func_name}/1

          Or create a module that implements run/3.
          """
    end
  end

  # ============================================================================
  # Helper: Auto-pipe lifting of Module.fun(args...) and fun(args...)
  # ============================================================================

  # Lifts Module.fun(args) to fn x -> Module.fun(x, args) end
  # Matches qualified calls like String.pad_leading(3, "0")
  defp lift_call_to_unary({{:., _, [mod_ast, fun_atom]}, _, args_ast}, _caller_env)
       when is_atom(fun_atom) and is_list(args_ast) and args_ast != [] do
    quote do
      fn x ->
        unquote(mod_ast).unquote(fun_atom)(x, unquote_splicing(args_ast))
      end
    end
  end

  # Lifts Module.fun() (zero-arity) to &Module.fun/1
  # Matches qualified calls like Validators.positive?()
  defp lift_call_to_unary({{:., meta, [mod_ast, fun_atom]}, _call_meta, []}, _caller_env)
       when is_atom(fun_atom) do
    {:&, meta, [{:/, meta, [{{:., meta, [mod_ast, fun_atom]}, meta, []}, 1]}]}
  end

  # Lifts bare function calls with arguments: fun(args) to fn x -> fun(x, args) end
  # Simple structural transformation - no arity checking
  defp lift_call_to_unary({fun_atom, _meta, args_ast}, _caller_env)
       when is_atom(fun_atom) and fun_atom not in [:__aliases__, :fn, :&] and
              is_list(args_ast) and args_ast != [] do
    quote do
      fn x ->
        unquote(fun_atom)(x, unquote_splicing(args_ast))
      end
    end
  end

  # Lifts zero-arity function calls to function captures: fun() to &fun/1
  defp lift_call_to_unary({fun_atom, meta, args_ast}, _caller_env)
       when is_atom(fun_atom) and fun_atom not in [:__aliases__, :fn, :&] and
              is_list(args_ast) and args_ast == [] do
    fun_tuple = {fun_atom, meta, Elixir}
    {:&, meta, [{:/, meta, [fun_tuple, 1]}]}
  end

  # Non-liftable expressions return nil
  defp lift_call_to_unary(_other, _caller_env), do: nil

  # ============================================================================
  # Transform modules in validator lists and arguments
  # ============================================================================

  defp transform_modules_to_functions(arg, user_env, caller_env) do
    case arg do
      # Transform list of validators
      items when is_list(items) ->
        Enum.map(items, &transform_list_item(&1, user_env, caller_env))

      # Transform {Module, opts} tuple syntax to function calls
      {{:__aliases__, _, _} = module_alias, opts_ast} when is_list(opts_ast) ->
        quote do
          fn value -> unquote(module_alias).run(value, unquote(opts_ast), unquote(user_env)) end
        end

      # Transform bare module syntax to function calls
      {:__aliases__, _, _} = module_alias ->
        quote do
          fn value -> unquote(module_alias).run(value, [], unquote(user_env)) end
        end

      other ->
        other
    end
  end

  # Transforms {Module, opts} tuple syntax to function calls
  defp transform_list_item(
         {{:__aliases__, _, _} = module_alias, opts_ast},
         user_env,
         _caller_env
       )
       when is_list(opts_ast) do
    quote do
      fn value -> unquote(module_alias).run(value, unquote(opts_ast), unquote(user_env)) end
    end
  end

  # Transforms bare module syntax to function calls
  defp transform_list_item({:__aliases__, _, _} = module_alias, user_env, _caller_env) do
    quote do
      fn value -> unquote(module_alias).run(value, [], unquote(user_env)) end
    end
  end

  # Try to lift function calls, or validate that it's a valid validator
  defp transform_list_item(other, _user_env, caller_env) do
    # First validate - reject literals before attempting to lift
    validate_list_item!(other)

    case lift_call_to_unary(other, caller_env) do
      nil -> other
      lifted -> lifted
    end
  end

  # ============================================================================
  # Validate list items (reject literals, keep this as syntax checking)
  # ============================================================================

  # Validates that list items are functions, not literals
  defp validate_list_item!({:fn, _, _}), do: :ok  # Anonymous function
  defp validate_list_item!({:&, _, _}), do: :ok   # Function capture
  defp validate_list_item!({name, _, context}) when is_atom(name) and is_atom(context), do: :ok
  defp validate_list_item!({:__aliases__, _, _}), do: :ok
  defp validate_list_item!({{:., _, _}, _, _}), do: :ok

  # Reject literals
  defp validate_list_item!(literal) when is_number(literal) do
    raise_invalid_validator(literal)
  end

  defp validate_list_item!(literal) when is_binary(literal) do
    raise_invalid_validator(literal)
  end

  defp validate_list_item!(literal) when is_atom(literal) do
    raise_invalid_validator(literal)
  end

  defp validate_list_item!({:%{}, _, _}) do
    raise_invalid_validator("map literal")
  end

  defp validate_list_item!([_ | _] = list) do
    raise_invalid_validator(list)
  end

  defp validate_list_item!([]) do
    raise_invalid_validator([])
  end

  # Allow other AST nodes (these will be validated at runtime)
  defp validate_list_item!(_), do: :ok

  defp raise_invalid_validator(literal) do
    raise CompileError,
      description: """
      Invalid validator in list: #{inspect(literal)}

      Validator lists must contain only:
        - Module names: MyValidator
        - Module with options: {MyValidator, opts}
        - Function calls: my_function()
        - Function captures: &my_function/1
        - Anonymous functions: fn x -> ... end

      Literals (numbers, strings, maps, etc.) are not allowed.
      """
  end

  # ============================================================================
  # Helper: parse operation syntax
  # ============================================================================

  # Parses operation arguments: {Module, opts} or Module -> {Module, opts}
  defp parse_operation_args([{_, _} = tuple_op]), do: tuple_op
  defp parse_operation_args([operation]), do: {operation, []}

  # ============================================================================
  # Lift input into Either context
  # ============================================================================

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
  # Runtime executor - interprets Pipeline data
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
    case pipeline.return_as do
      :either ->
        case result do
          %Either.Right{} -> result
          %Either.Left{} -> result
          other ->
            raise ArgumentError, """
            Expected Either struct when using as: :either, but got: #{inspect(other)}
            """
        end

      :tuple ->
        Either.to_result(result)

      :raise ->
        Either.to_try!(result)
    end
  end

  # Execute individual steps
  defp execute_step(either_value, %Step{type: :bind, operation: operation, opts: opts}, user_env) do
    Funx.Monad.bind(either_value, fn value ->
      result = call_operation(operation, value, opts, user_env)
      normalize_run_result(result)
    end)
  end

  defp execute_step(either_value, %Step{type: :map, operation: operation, opts: opts}, user_env) do
    Funx.Monad.map(either_value, fn value ->
      call_operation(operation, value, opts, user_env)
    end)
  end

  defp execute_step(either_value, %Step{type: :ap, operation: operation}, _user_env) do
    Funx.Monad.ap(either_value, operation)
  end

  defp execute_step(either_value, %Step{type: :either_function, operation: {func_name, args}}, _user_env) do
    apply(Either, func_name, [either_value | args])
  end

  defp execute_step(either_value, %Step{type: :bindable_function, operation: {func_name, args}}, _user_env) do
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
end
