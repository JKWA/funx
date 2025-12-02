defmodule Funx.Monad.Either.Dsl do
  @moduledoc """
  Provides the `either/2` macro for writing declarative pipelines in the Either context.

  The DSL lets you express a sequence of operations that may fail without manually
  threading values through `bind`, `map`, or `map_left`. Input is lifted into Either
  automatically, each step runs in order, and the pipeline stops on the first error.

  ## Supported Operations

  - `bind` - for operations that return Either or result tuples
  - `map` - for transformations that return plain values
  - Either functions: `filter_or_else`, `or_else`, `map_left`, `flip`
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
  - `fun()` becomes `&fun/1` (zero-arity bare calls)
  - `fun(arg)` becomes `fn x -> fun(x, arg) end` (partial application)
  - `Module.fun(arg)` becomes `fn x -> Module.fun(x, arg) end` (partial application)

  This is particularly useful in validator lists:

      validate [Validator.positive?(), Validator.even?()]
      # Becomes: validate [&Validator.positive?/1, &Validator.even?/1]

  If you prefer explicit syntax, you can always use function captures directly:

      validate [&Validator.positive?/1, &Validator.even?/1]

  This module defines the public DSL entry point. The macro expansion details and
  internal rewrite rules are not part of the public API.
  """

  # credo:disable-for-this-file Credo.Check.Design.AliasUsage
  alias Funx.Monad.Either

  # Functions that operate on Either directly (not unwrapped)
  @either_functions [:filter_or_else, :or_else, :map_left, :flip]

  # Functions that work on unwrapped values (auto-bind)
  @bindable_functions [
    :validate
  ]

  defmacro __using__(_opts) do
    quote do
      import Funx.Monad.Either.Dsl
    end
  end

  # ============================================================================
  # Helper: Auto-pipe lifting of Module.fun(args...) or fun(args...)
  # ============================================================================

  # Determines if a function call should be lifted to partial application.
  # Returns true if the function needs an extra argument prepended, false otherwise.
  defp should_lift_function?(caller_module, fun_atom, current_arity, lifted_arity) do
    current_arity_defined = Module.defines?(caller_module, {fun_atom, current_arity})
    lifted_arity_defined = Module.defines?(caller_module, {fun_atom, lifted_arity})

    cond do
      # Function returns a function - don't lift
      current_arity_defined and not lifted_arity_defined -> false
      # Function needs partial application - lift
      lifted_arity_defined -> true
      # External function - lift
      not current_arity_defined and not lifted_arity_defined -> true
      # Default - don't lift
      true -> false
    end
  end

  # Lifts Module.fun(args) to fn x -> Module.fun(x, args) end
  # Matches qualified calls like String.pad_leading(3, "0"), not variable calls
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
  # Uses arity checking to avoid lifting functions that return functions
  defp lift_call_to_unary({fun_atom, _meta, args_ast}, caller_env)
       when is_atom(fun_atom) and fun_atom not in [:__aliases__, :fn, :&] and
              is_list(args_ast) and args_ast != [] do
    current_arity = length(args_ast)
    lifted_arity = current_arity + 1
    caller_module = caller_env.module

    if should_lift_function?(caller_module, fun_atom, current_arity, lifted_arity) do
      quote do
        fn x ->
          unquote(fun_atom)(x, unquote_splicing(args_ast))
        end
      end
    else
      nil
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
  # Helper: validate bind return types at compile time
  # ============================================================================

  # Validates anonymous functions used with bind to catch type errors early
  defp validate_bind_return_type({:fn, _meta, clauses}, caller_env) do
    Enum.each(clauses, fn {:->, _arrow_meta, [_args, body]} ->
      check_return_value(body, caller_env)
    end)

    :ok
  end

  # Named functions and modules are validated at runtime
  defp validate_bind_return_type(_other, _caller_env), do: :ok

  # Classifies return values as safe, unsafe, or unknown
  defp check_return_value(ast, caller_env) do
    case classify_return_type(ast) do
      :safe -> :ok
      :unsafe -> emit_compile_warning(ast, caller_env)
      :unknown -> :ok
    end
  end

  # Extracts the return value from block expressions
  defp classify_return_type({:__block__, _, exprs}) when is_list(exprs) do
    classify_return_type(List.last(exprs))
  end

  # Safe: Either constructors
  defp classify_return_type({:right, _, _}), do: :safe
  defp classify_return_type({:left, _, _}), do: :safe

  defp classify_return_type({{:., _, [{:__aliases__, _, [:Either]}, :right]}, _, _}),
    do: :safe

  defp classify_return_type({{:., _, [{:__aliases__, _, [:Either]}, :left]}, _, _}),
    do: :safe

  # Safe: Result tuples
  defp classify_return_type({:{}, _, [:ok | _]}), do: :safe
  defp classify_return_type({:{}, _, [:error | _]}), do: :safe

  # Unsafe: Plain literals
  defp classify_return_type(value) when is_binary(value), do: :unsafe
  defp classify_return_type(value) when is_number(value), do: :unsafe
  defp classify_return_type(nil), do: :unsafe
  defp classify_return_type(true), do: :unsafe
  defp classify_return_type(false), do: :unsafe

  defp classify_return_type(value) when is_atom(value),
    do: :unsafe

  defp classify_return_type({:%{}, _, _}), do: :unsafe
  defp classify_return_type([_ | _]), do: :unsafe
  defp classify_return_type([]), do: :unsafe

  # Unknown: Function calls, variables, control flow (validated at runtime)
  defp classify_return_type(_), do: :unknown

  # Emits compile-time warning for unsafe bind operations
  defp emit_compile_warning(ast, caller_env) do
    IO.warn(
      """
      Potential type error in bind operation.

      The function returns: #{Macro.to_string(ast)}

      Functions used with 'bind' must return:
        - An Either value: right(x) or left(y)
        - A result tuple: {:ok, x} or {:error, y}

      This will raise an ArgumentError at runtime if the return type is incorrect.
      """,
      Macro.Env.stacktrace(caller_env)
    )
  end

  # ============================================================================
  # Helper: validate map return types at compile time
  # ============================================================================

  # Validates anonymous functions used with map to catch incorrect usage
  defp validate_map_return_type({:fn, _meta, clauses}, caller_env) do
    Enum.each(clauses, fn {:->, _arrow_meta, [_args, body]} ->
      check_map_return_value(body, caller_env)
    end)

    :ok
  end

  # Named functions and modules are validated at runtime
  defp validate_map_return_type(_other, _caller_env), do: :ok

  # Classifies return values as problematic or ok for map operations
  defp check_map_return_value(ast, caller_env) do
    case classify_map_return_type(ast) do
      :problematic -> emit_map_warning(ast, caller_env)
      :ok -> :ok
    end
  end

  # Extracts the return value from block expressions
  defp classify_map_return_type({:__block__, _, exprs}) when is_list(exprs) do
    classify_map_return_type(List.last(exprs))
  end

  # Problematic: Either constructors (causes double-wrapping)
  defp classify_map_return_type({:right, _, _}), do: :problematic
  defp classify_map_return_type({:left, _, _}), do: :problematic

  defp classify_map_return_type({{:., _, [{:__aliases__, _, [:Either]}, :right]}, _, _}),
    do: :problematic

  defp classify_map_return_type({{:., _, [{:__aliases__, _, [:Either]}, :left]}, _, _}),
    do: :problematic

  defp classify_map_return_type(
         {{:., _, [{:__aliases__, _, [:Funx, :Monad, :Either]}, :right]}, _, _}
       ),
       do: :problematic

  defp classify_map_return_type(
         {{:., _, [{:__aliases__, _, [:Funx, :Monad, :Either]}, :left]}, _, _}
       ),
       do: :problematic

  # Problematic: Result tuples (use bind instead)
  defp classify_map_return_type({:ok, _}), do: :problematic
  defp classify_map_return_type({:error, _}), do: :problematic
  defp classify_map_return_type({:{}, _, [:ok | _]}), do: :problematic
  defp classify_map_return_type({:{}, _, [:error | _]}), do: :problematic

  # OK: Plain values, function calls, variables
  defp classify_map_return_type(_), do: :ok

  # Emits compile-time warning for incorrect map usage
  defp emit_map_warning(ast, caller_env) do
    IO.warn(
      """
      Potential incorrect usage of map operation.

      The function returns: #{Macro.to_string(ast)}

      Functions used with 'map' should return plain values, not Either or result tuples.

      If your function returns an Either or result tuple, use 'bind' instead of 'map':
        - Use 'bind' when the function returns: right(x), left(y), {:ok, x}, {:error, y}
        - Use 'map' when the function returns: plain values (strings, numbers, etc.)

      Using 'map' with Either/tuple returns will cause double-wrapping.
      """,
      Macro.Env.stacktrace(caller_env)
    )
  end

  # ============================================================================
  # Helper: validate bare modules used with bind/map
  # ============================================================================

  defp ensure_step_module_has_run!(module_alias_ast, env) do
    expanded = Macro.expand(module_alias_ast, env)

    mod =
      case expanded do
        {:__aliases__, _, parts} -> Module.concat(parts)
        atom when is_atom(atom) -> atom
        other -> other
      end

    if is_atom(mod) do
      validate_module_exports!(mod, module_alias_ast)
    end

    :ok
  end

  defp validate_module_exports!(mod, module_alias_ast) do
    case Code.ensure_compiled(mod) do
      {:module, _} ->
        unless function_exported?(mod, :run, 3) do
          raise CompileError,
            description: """
            Invalid operation: #{Macro.to_string(module_alias_ast)}

            Modules used with 'bind' or 'map' must implement run/3
            via the @behaviour Funx.Monad.Either.Dsl.Behaviour.

            Example:

                defmodule #{inspect(mod)} do
                  @behaviour Funx.Monad.Either.Dsl.Behaviour

                  @impl true
                  def run(value, _env, _opts) do
                    # your logic here
                  end
                end
            """
        end

        # Check if module implements the behaviour (optional but recommended)
        behaviours = mod.module_info(:attributes)[:behaviour] || []
        either_behaviour = Funx.Monad.Either.Dsl.Behaviour

        unless either_behaviour in behaviours do
          IO.warn("""
          Module #{inspect(mod)} implements run/3 but does not declare @behaviour #{inspect(either_behaviour)}.

          This may cause issues if multiple DSLs are used in the same codebase.
          Consider adding:

              @behaviour #{inspect(either_behaviour)}
          """)
        end

      _ ->
        raise CompileError,
          description: """
          Invalid operation: #{Macro.to_string(module_alias_ast)}

          Module #{inspect(mod)} is not available at compile time.
          """
    end
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
  # Compile the pipeline
  # ============================================================================

  defp compile_pipeline(input, [first | rest], return_as, user_env, caller_env) do
    wrapped_input =
      quote do
        Funx.Monad.Either.Dsl.lift_input(unquote(input))
      end

    initial = compile_first_operation(wrapped_input, first, user_env, caller_env)

    pipeline =
      Enum.reduce(rest, initial, fn operation, acc ->
        compile_operation(acc, operation, user_env, caller_env)
      end)

    result = wrap_with_return_type(pipeline, return_as)

    quote do
      (fn ->
         import Either,
           only: [
             # Constructors (needed for callbacks and fallbacks)
             right: 1,
             left: 1,
             # Either functions (work on Either directly)
             filter_or_else: 3,
             or_else: 2,
             map_left: 2,
             flip: 1,
             # Bindable functions (work on unwrapped values)
             validate: 2
           ]

         unquote(result)
       end).()
    end
  end

  # ============================================================================
  # Helper: parse operation syntax
  # ============================================================================

  # Parses operation arguments: {Module, opts} or Module -> {Module, opts}
  defp parse_operation_args([{_, _} = tuple_op]), do: tuple_op
  defp parse_operation_args([operation]), do: {operation, []}

  # ============================================================================
  # First operation
  # ============================================================================

  defp compile_first_operation(input, operation_ast, user_env, caller_env) do
    case operation_ast do
      {:bind, _, args} ->
        {operation, opts} = parse_operation_args(args)
        compile_first_bind_operation(input, operation, opts, user_env, caller_env)

      {:map, _, args} ->
        {operation, opts} = parse_operation_args(args)
        compile_first_map_operation(input, operation, opts, user_env, caller_env)

      {func_name, meta, args} when is_atom(func_name) and is_list(args) ->
        compile_either_function(input, func_name, meta, args, user_env, caller_env)

      {:__aliases__, _, _} = module_alias ->
        raise CompileError,
          description: """
          Invalid operation: #{Macro.to_string(module_alias)}

          Modules must be used with a keyword:
            bind #{Macro.to_string(module_alias)}
            map #{Macro.to_string(module_alias)}
          """

      other ->
        raise CompileError,
          description:
            "Invalid operation: #{inspect(other)}. Use 'bind', 'map', or Either functions."
    end
  end

  # ============================================================================
  # First bind
  # ============================================================================

  defp compile_first_bind_operation(input, operation, opts, user_env, caller_env) do
    compile_bind_operation(input, operation, opts, user_env, caller_env)
  end

  # ============================================================================
  # First map
  # ============================================================================

  defp compile_first_map_operation(input, operation, opts, user_env, caller_env) do
    compile_map_operation(input, operation, opts, user_env, caller_env)
  end

  # ============================================================================
  # Subsequent operations
  # ============================================================================

  defp compile_operation(previous, operation_ast, user_env, caller_env) do
    case operation_ast do
      {:bind, _, args} ->
        {operation, opts} = parse_operation_args(args)
        compile_bind_operation(previous, operation, opts, user_env, caller_env)

      {:map, _, args} ->
        {operation, opts} = parse_operation_args(args)
        compile_map_operation(previous, operation, opts, user_env, caller_env)

      {func_name, meta, args} when is_atom(func_name) and is_list(args) ->
        compile_either_function(previous, func_name, meta, args, user_env, caller_env)

      {:__aliases__, _, _} = module_alias ->
        raise CompileError,
          description: """
          Invalid operation: #{Macro.to_string(module_alias)}

          Use bind/map with modules.
          """

      other ->
        raise CompileError,
          description: "Invalid operation: #{inspect(other)}."
    end
  end

  # ============================================================================
  # bind (unified)
  # ============================================================================

  defp compile_bind_operation(input_or_previous, operation, opts, user_env, caller_env) do
    validate_bind_return_type(operation, caller_env)

    operation =
      case lift_call_to_unary(operation, caller_env) do
        nil -> operation
        lifted -> lifted
      end

    case operation do
      {:__aliases__, _, _} = module_alias ->
        ensure_step_module_has_run!(module_alias, caller_env)

        quote do
          Funx.Monad.bind(unquote(input_or_previous), fn value ->
            Funx.Monad.Either.Dsl.normalize_run_result(
              unquote(module_alias).run(value, unquote(opts), unquote(user_env))
            )
          end)
        end

      module when is_atom(module) ->
        quote do
          Funx.Monad.bind(unquote(input_or_previous), fn value ->
            Funx.Monad.Either.Dsl.normalize_run_result(
              unquote(module).run(value, unquote(opts), unquote(user_env))
            )
          end)
        end

      func ->
        quote do
          Funx.Monad.bind(unquote(input_or_previous), fn value ->
            Funx.Monad.Either.Dsl.normalize_run_result(unquote(func).(value))
          end)
        end
    end
  end

  # ============================================================================
  # map (unified)
  # ============================================================================

  defp compile_map_operation(input_or_previous, operation, opts, user_env, caller_env) do
    validate_map_return_type(operation, caller_env)

    operation =
      case lift_call_to_unary(operation, caller_env) do
        nil -> operation
        lifted -> lifted
      end

    case operation do
      {:__aliases__, _, _} = module_alias ->
        ensure_step_module_has_run!(module_alias, caller_env)

        quote do
          Funx.Monad.map(unquote(input_or_previous), fn value ->
            unquote(module_alias).run(value, unquote(opts), unquote(user_env))
          end)
        end

      module when is_atom(module) ->
        quote do
          Funx.Monad.map(unquote(input_or_previous), fn value ->
            unquote(module).run(value, unquote(opts), unquote(user_env))
          end)
        end

      func ->
        quote do
          Funx.Monad.map(unquote(input_or_previous), unquote(func))
        end
    end
  end

  # ============================================================================
  # Either.function support
  # ============================================================================

  defp compile_either_function(previous, func_name, _meta, args, user_env, caller_env) do
    # First lift function calls, then transform modules
    lifted_args =
      Enum.map(args, fn arg ->
        case lift_call_to_unary(arg, caller_env) do
          nil -> arg
          lifted -> lifted
        end
      end)

    transformed_args = Enum.map(lifted_args, &transform_modules_to_functions(&1, user_env, caller_env))

    cond do
      func_name in @either_functions ->
        quote do
          unquote(func_name)(unquote(previous), unquote_splicing(transformed_args))
        end

      func_name in @bindable_functions ->
        quote do
          Funx.Monad.bind(unquote(previous), fn value ->
            unquote(func_name)(value, unquote_splicing(transformed_args))
          end)
        end

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

          Or create a module that implements the Funx.Monad.Either.Dsl.Behaviour.
          """
    end
  end

  # ============================================================================
  # Transform modules in validator lists
  # ============================================================================

  defp transform_modules_to_functions(arg, user_env, caller_env) do
    case arg do
      items when is_list(items) ->
        Enum.map(items, &transform_list_item(&1, user_env, caller_env))

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

  # Validates that list items are functions, not literals
  defp validate_list_item!({:fn, _, _}), do: :ok  # Anonymous function
  defp validate_list_item!({:&, _, _}), do: :ok   # Function capture
  defp validate_list_item!({name, _, context}) when is_atom(name) and is_atom(context), do: :ok  # Variable or function call
  defp validate_list_item!({:__aliases__, _, _}), do: :ok  # Module alias (handled by other clauses)
  defp validate_list_item!({{:., _, _}, _, _}), do: :ok  # Qualified call like Module.fun()

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
  # normalize tuple/Either returns
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
  # return type wrapping
  # ============================================================================

  defp wrap_with_return_type(pipeline_ast, return_as) do
    case return_as do
      :either ->
        quote do
          result = unquote(pipeline_ast)

          case result do
            %Either.Right{} -> result
            %Either.Left{} -> result
            other ->
              raise ArgumentError, """
              Expected Either struct when using as: :either, but got: #{inspect(other)}

              The pipeline must return an Either value (Right or Left).
              This typically happens when a function in the pipeline returns a plain value
              instead of an Either or result tuple.
              """
          end
        end

      :tuple ->
        quote do
          Either.to_result(unquote(pipeline_ast))
        end

      :raise ->
        quote do
          Either.to_try!(unquote(pipeline_ast))
        end

      _ ->
        raise CompileError,
          description:
            "Invalid return type: #{inspect(return_as)}. Must be :either, :tuple, or :raise"
    end
  end
end
