defmodule Funx.Monad.Maybe.Dsl.Parser do
  @moduledoc false
  # Internal parser for Maybe DSL - converts AST into Step structs

  alias Funx.Monad.Maybe.Dsl.Step

  # Operation type classification (for error messages)
  @maybe_functions [:or_else]
  @protocol_functions %{
    tap: Funx.Tappable,
    filter: Funx.Filterable,
    filter_map: Funx.Filterable,
    guard: Funx.Filterable
  }

  # DSL operation → Behavior routing:
  #   bind, tap, filter_map → Bind behavior (bind/3)
  #   map → Map behavior (map/3)
  #   filter, guard → Predicate behavior (predicate/3)
  #   ap → Ap behavior (ap/3)
  #   or_else → No module support (passes function through)

  @all_allowed_functions @maybe_functions ++ Map.keys(@protocol_functions)

  # ============================================================================
  # PUBLIC API
  # ============================================================================

  @doc """
  Parse a DSL block into a list of Step structs
  """
  def parse_operations(block, caller_env, user_env) do
    block
    |> extract_operations()
    |> Enum.map(&parse_operation_to_step(&1, user_env, caller_env))
  end

  # ============================================================================
  # OPERATION PARSING
  # ============================================================================

  defp extract_operations({:__block__, _meta, lines}) when is_list(lines), do: lines
  defp extract_operations(single_line), do: [single_line]

  defp parse_operation_to_step(operation_ast, user_env, caller_env) do
    case operation_ast do
      {:bind, meta, args} ->
        parse_monad_operation(:bind, args, meta, user_env, caller_env)

      {:map, meta, args} ->
        parse_monad_operation(:map, args, meta, user_env, caller_env)

      {:ap, meta, args} ->
        {operation, opts} = parse_operation_args(args)
        # Don't lift for ap - it receives Maybe values directly, not functions
        # Lifting would incorrectly transform just(42) to fn x -> just(x, 42) end
        transformed_op = ast_transform_module_for_monad_op(operation, opts, :ap, user_env)
        %Step.Ap{applicative: transformed_op, __meta__: extract_meta(meta)}

      {:__aliases__, _, _} = module_alias ->
        raise_bare_module_error(module_alias)

      {func_name, meta, args} when is_atom(func_name) and is_list(args) ->
        parse_maybe_function_to_step(func_name, args, meta, user_env, caller_env)

      other ->
        raise_invalid_operation_error(other)
    end
  end

  # Extract common logic for bind and map operations
  defp parse_monad_operation(type, args, meta, user_env, caller_env) do
    {operation, opts} = parse_operation_args(args)
    lifted_op = ast_lift_call_to_unary(operation, caller_env) || operation

    # Transform modules to call bind/3 or map/3 based on operation type
    transformed_op = ast_transform_module_for_monad_op(lifted_op, opts, type, user_env)

    metadata = extract_meta(meta)

    case type do
      :bind -> %Step.Bind{operation: transformed_op, opts: [], __meta__: metadata}
      :map -> %Step.Map{operation: transformed_op, opts: [], __meta__: metadata}
    end
  end

  # Transform modules for bind/map/ap operations to call behavior methods
  defp ast_transform_module_for_monad_op(operation, opts, type, user_env) do
    case operation do
      # Module: transform to call bind/3, map/3, or ap/3
      {:__aliases__, _, _} = module_alias ->
        method = behavior_method_for_type(type)

        quote do
          fn value ->
            unquote(module_alias).unquote(method)(value, unquote(opts), unquote(user_env))
          end
        end

      # Not a module (function, etc.) - pass through
      other ->
        other
    end
  end

  defp parse_maybe_function_to_step(func_name, args, meta, user_env, caller_env) do
    transformed_args = transform_function_args(func_name, args, user_env, caller_env)
    metadata = extract_meta(meta)

    cond do
      func_name in @maybe_functions ->
        %Step.MaybeFunction{function: func_name, args: transformed_args, __meta__: metadata}

      protocol = Map.get(@protocol_functions, func_name) ->
        %Step.ProtocolFunction{
          protocol: protocol,
          function: func_name,
          args: transformed_args,
          __meta__: metadata
        }

      true ->
        raise_invalid_function_error(func_name)
    end
  end

  # Transform arguments based on the function type
  defp transform_function_args(func_name, args, user_env, caller_env) do
    Enum.map(args, fn arg ->
      lifted = ast_lift_call_to_unary(arg, caller_env) || arg
      transform_arg_for_function(func_name, lifted, user_env, caller_env)
    end)
  end

  defp transform_arg_for_function(:tap, arg, user_env, caller_env) do
    ast_transform_module_to_bind(arg, user_env, caller_env)
  end

  defp transform_arg_for_function(:filter, arg, user_env, caller_env) do
    ast_transform_module_to_predicate(arg, user_env, caller_env)
  end

  defp transform_arg_for_function(:filter_map, arg, user_env, caller_env) do
    # filter_map returns Maybe/tuple like bind, not boolean like predicate
    ast_transform_module_to_bind(arg, user_env, caller_env)
  end

  defp transform_arg_for_function(:guard, arg, user_env, caller_env) do
    ast_transform_module_to_predicate(arg, user_env, caller_env)
  end

  # Default: pass through (for or_else which doesn't accept modules)
  defp transform_arg_for_function(_func_name, arg, _user_env, _caller_env) do
    arg
  end

  # Parses operation arguments: {Module, opts} or Module -> {Module, opts}
  defp parse_operation_args([{_, _} = tuple_op]), do: tuple_op
  defp parse_operation_args([operation]), do: {operation, []}

  # ============================================================================
  # METADATA EXTRACTION
  # ============================================================================

  # Extract relevant metadata from AST meta keyword list
  # Note: Elixir AST metadata is always a keyword list, so we don't need a fallback
  defp extract_meta(meta) when is_list(meta) do
    %{
      line: Keyword.get(meta, :line),
      column: Keyword.get(meta, :column)
    }
  end

  # ============================================================================
  # AST TRANSFORMATIONS
  # ============================================================================

  # Returns the behavior method name for the operation type
  defp behavior_method_for_type(:bind), do: :bind
  defp behavior_method_for_type(:map), do: :map
  defp behavior_method_for_type(:ap), do: :ap

  # Generic helper to transform modules to call a specific behavior method
  # Used by bind, map, tap, filter, filter_map, guard, and ap
  defp ast_transform_module_to_behavior(arg, method, env) do
    case arg do
      # Module with options: {Module, opts}
      {{:__aliases__, _, _} = module_alias, opts_ast} when is_list(opts_ast) ->
        quote do
          fn value ->
            unquote(module_alias).unquote(method)(value, unquote(opts_ast), unquote(env))
          end
        end

      # Bare module: Module
      {:__aliases__, _, _} = module_alias ->
        quote do
          fn value -> unquote(module_alias).unquote(method)(value, [], unquote(env)) end
        end

      # Not a module - return as-is (function, etc.)
      other ->
        other
    end
  end

  # Transform modules to call bind/3 (for bind, tap, filter_map operations)
  defp ast_transform_module_to_bind(arg, user_env, _caller_env) do
    ast_transform_module_to_behavior(arg, :bind, user_env)
  end

  # Transform modules to call predicate/3 (for filter and guard operations)
  defp ast_transform_module_to_predicate(arg, user_env, _caller_env) do
    ast_transform_module_to_behavior(arg, :predicate, user_env)
  end

  # Lifts Module.fun(args) to fn x -> Module.fun(x, args) end
  # Matches qualified calls like String.pad_leading(3, "0")
  defp ast_lift_call_to_unary({{:., _, [mod_ast, fun_atom]}, _, args_ast}, _caller_env)
       when is_atom(fun_atom) and is_list(args_ast) and args_ast != [] do
    quote do
      fn x ->
        unquote(mod_ast).unquote(fun_atom)(x, unquote_splicing(args_ast))
      end
    end
  end

  # Lifts Module.fun() (zero-arity) to &Module.fun/1
  # Matches qualified calls like Validators.positive?()
  defp ast_lift_call_to_unary({{:., meta, [mod_ast, fun_atom]}, _call_meta, []}, _caller_env)
       when is_atom(fun_atom) do
    {:&, meta, [{:/, meta, [{{:., meta, [mod_ast, fun_atom]}, meta, []}, 1]}]}
  end

  # Lifts bare function calls with arguments: fun(args) to fn x -> fun(x, args) end
  # Simple structural transformation - no arity checking
  defp ast_lift_call_to_unary({fun_atom, _meta, args_ast}, _caller_env)
       when is_atom(fun_atom) and fun_atom not in [:__aliases__, :fn, :&] and
              is_list(args_ast) and args_ast != [] do
    quote do
      fn x ->
        unquote(fun_atom)(x, unquote_splicing(args_ast))
      end
    end
  end

  # Lifts zero-arity function calls to function captures: fun() to &fun/1
  defp ast_lift_call_to_unary({fun_atom, meta, args_ast}, _caller_env)
       when is_atom(fun_atom) and fun_atom not in [:__aliases__, :fn, :&] and
              is_list(args_ast) and args_ast == [] do
    fun_tuple = {fun_atom, meta, Elixir}
    {:&, meta, [{:/, meta, [fun_tuple, 1]}]}
  end

  # Non-liftable expressions return nil
  defp ast_lift_call_to_unary(_other, _caller_env), do: nil

  # ============================================================================
  # ERROR HELPERS
  # ============================================================================

  defp raise_bare_module_error(module_alias) do
    raise CompileError,
      description: """
      Invalid operation: #{Macro.to_string(module_alias)}

      Modules must be used with a keyword:
        bind #{Macro.to_string(module_alias)}
        map #{Macro.to_string(module_alias)}
        ap #{Macro.to_string(module_alias)}
      """
  end

  defp raise_invalid_operation_error(other) do
    raise CompileError,
      description:
        "Invalid operation: #{inspect(other)}. Use 'bind', 'map', 'ap', or Maybe functions."
  end

  defp raise_invalid_function_error(func_name) do
    raise CompileError,
      description: """
      Invalid operation: #{func_name}

      Bare function calls are not allowed in the DSL pipeline.

      If you meant to call a Maybe function, only these are allowed:
        #{inspect(@all_allowed_functions)}

      If you meant to use a custom function, you must use 'bind' or 'map':
        bind #{func_name}(...)
        map #{func_name}(...)

      Or use a function capture:
        map &#{func_name}/1

      Or create a module that implements the appropriate behavior:
        - Funx.Monad.Behaviour.Bind for bind operations
        - Funx.Monad.Behaviour.Map for map operations
        - Funx.Monad.Behaviour.Predicate for filter operations
      """
  end
end
