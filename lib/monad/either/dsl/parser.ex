defmodule Funx.Monad.Either.Dsl.Parser do
  @moduledoc false
  # Internal parser for Either DSL - converts AST into Step structs

  alias Funx.Monad.Either.Dsl.Errors
  alias Funx.Monad.Either.Dsl.Step

  # Operation type classification (for error messages)
  @either_functions [:filter_or_else, :or_else, :map_left, :flip]
  @protocol_functions %{tap: Funx.Tappable}
  @bindable_functions [:validate]
  @all_allowed_functions @either_functions ++ Map.keys(@protocol_functions) ++ @bindable_functions

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
        lifted_op = ast_lift_call_to_unary(operation, caller_env) || operation
        transformed_op = ast_transform_module_for_monad_op(lifted_op, opts, :ap, user_env)
        %Step.Ap{applicative: transformed_op, __meta__: extract_meta(meta)}

      {:__aliases__, _, _} = module_alias ->
        raise_bare_module_error(module_alias)

      {func_name, meta, args} when is_atom(func_name) and is_list(args) ->
        parse_either_function_to_step(func_name, args, meta, user_env, caller_env)

      other ->
        raise_invalid_operation_error(other)
    end
  end

  # Extract common logic for bind and map operations
  defp parse_monad_operation(type, args, meta, user_env, caller_env) do
    {operation, opts} = parse_operation_args(args)
    lifted_op = ast_lift_call_to_unary(operation, caller_env) || operation

    # Transform modules to call bind/3 or map/3 based on operation type
    # Don't expand aliases before transforming - let the quote block handle it
    transformed_op = ast_transform_module_for_monad_op(lifted_op, opts, type, user_env)

    metadata = extract_meta(meta)

    case type do
      :bind -> %Step.Bind{operation: transformed_op, opts: [], __meta__: metadata}
      :map -> %Step.Map{operation: transformed_op, opts: [], __meta__: metadata}
    end
  end

  defp parse_either_function_to_step(func_name, args, meta, user_env, caller_env) do
    transformed_args = transform_function_args(func_name, args, user_env, caller_env)
    metadata = extract_meta(meta)

    cond do
      func_name in @either_functions ->
        %Step.EitherFunction{function: func_name, args: transformed_args, __meta__: metadata}

      protocol = Map.get(@protocol_functions, func_name) ->
        %Step.ProtocolFunction{
          protocol: protocol,
          function: func_name,
          args: transformed_args,
          __meta__: metadata
        }

      func_name in @bindable_functions ->
        %Step.BindableFunction{function: func_name, args: transformed_args, __meta__: metadata}

      true ->
        raise_invalid_function_error(func_name)
    end
  end

  # Transform arguments based on the function type
  # validate uses validate/3, tap uses bind/3, map_left uses map/3, filter_or_else uses predicate/3
  defp transform_function_args(func_name, args, user_env, caller_env) do
    # filter_or_else has a predicate as first arg and error function as second arg
    # Only transform the predicate (first arg), leave error function as-is
    if func_name == :filter_or_else do
      case args do
        [predicate_arg | rest] ->
          lifted = ast_lift_call_to_unary(predicate_arg, caller_env) || predicate_arg

          transformed_predicate =
            transform_arg_for_function(:filter_or_else, lifted, user_env, caller_env)

          [transformed_predicate | rest]

        [] ->
          []
      end
    else
      Enum.map(args, fn arg ->
        lifted = ast_lift_call_to_unary(arg, caller_env) || arg
        transform_arg_for_function(func_name, lifted, user_env, caller_env)
      end)
    end
  end

  defp transform_arg_for_function(:validate, arg, user_env, caller_env) do
    ast_transform_modules_to_functions(arg, user_env, caller_env)
  end

  defp transform_arg_for_function(:tap, arg, user_env, caller_env) do
    ast_transform_module_to_bind(arg, user_env, caller_env)
  end

  defp transform_arg_for_function(:map_left, arg, _user_env, caller_env) do
    ast_transform_module_to_map(arg, caller_env)
  end

  defp transform_arg_for_function(:filter_or_else, arg, user_env, caller_env) do
    ast_transform_module_to_predicate(arg, user_env, caller_env)
  end

  # Default case: pass through as-is (for functions like or_else that don't accept modules)
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

  # Lifts Module.fun(args) to fn x -> Module.fun(x, args) end
  # Matches qualified calls like String.pad_leading(3, "0")
  defp ast_lift_call_to_unary({{:., _, [mod_ast, fun_atom]}, _, args_ast}, _caller_env)
       when is_atom(fun_atom) and is_list(args_ast) and args_ast != [] do
    # Skip Either/Maybe constructors even when module-qualified
    if fun_atom in [:right, :left, :just, :nothing] do
      nil
    else
      quote do
        fn x ->
          unquote(mod_ast).unquote(fun_atom)(x, unquote_splicing(args_ast))
        end
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
  # Skip Either/Maybe constructors (right, left, just, nothing)
  defp ast_lift_call_to_unary({fun_atom, _meta, args_ast}, _caller_env)
       when is_atom(fun_atom) and
              fun_atom not in [:__aliases__, :fn, :&, :right, :left, :just, :nothing] and
              is_list(args_ast) and args_ast != [] do
    quote do
      fn x ->
        unquote(fun_atom)(x, unquote_splicing(args_ast))
      end
    end
  end

  # Lifts zero-arity function calls to function captures: fun() to &fun/1
  # Skip Either/Maybe constructors
  defp ast_lift_call_to_unary({fun_atom, meta, args_ast}, _caller_env)
       when is_atom(fun_atom) and
              fun_atom not in [:__aliases__, :fn, :&, :right, :left, :just, :nothing] and
              is_list(args_ast) and args_ast == [] do
    fun_tuple = {fun_atom, meta, Elixir}
    {:&, meta, [{:/, meta, [fun_tuple, 1]}]}
  end

  # Non-liftable expressions return nil
  defp ast_lift_call_to_unary(_other, _caller_env), do: nil

  # Transform modules in validator lists and arguments (for validate function only)
  # All validators use validate/3 behavior
  defp ast_transform_modules_to_functions(arg, user_env, caller_env) do
    case arg do
      # Transform list of validators
      items when is_list(items) ->
        Enum.map(items, &ast_transform_list_item(&1, user_env, caller_env))

      # Transform {Module, opts} tuple syntax to function calls
      {{:__aliases__, _, _} = module_alias, opts_ast} when is_list(opts_ast) ->
        ast_module_with_opts_to_function(module_alias, opts_ast)

      # Transform bare module syntax to function calls
      {:__aliases__, _, _} = module_alias ->
        ast_bare_module_to_function(module_alias)

      other ->
        other
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

  # Returns the behavior method name for the operation type
  defp behavior_method_for_type(:bind), do: :bind
  defp behavior_method_for_type(:map), do: :map
  defp behavior_method_for_type(:ap), do: :ap

  # Generic helper to transform modules to call a specific behavior method
  # Used by tap (bind/3), map_left (map/3), and filter_or_else (predicate/3)
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

  # Transform modules to call bind/3 (for tap operations)
  defp ast_transform_module_to_bind(arg, user_env, _caller_env) do
    ast_transform_module_to_behavior(arg, :bind, user_env)
  end

  # Transform modules to call map/3 (for map_left operations)
  # Note: map_left is a pure transformation, so we pass empty env
  defp ast_transform_module_to_map(arg, _caller_env) do
    ast_transform_module_to_behavior(arg, :map, Macro.escape(%{}))
  end

  # Transform modules to call predicate/3 (for filter_or_else operations)
  defp ast_transform_module_to_predicate(arg, user_env, _caller_env) do
    ast_transform_module_to_behavior(arg, :predicate, user_env)
  end

  # Generates AST for module with options
  # All validators are arity-3: validate(value, opts, env)
  defp ast_module_with_opts_to_function(module_alias, opts_ast) do
    quote do
      fn value, runtime_opts, env ->
        # Merge compile-time validator opts with runtime opts (runtime takes precedence)
        merged_opts = Keyword.merge(unquote(opts_ast), runtime_opts)
        unquote(module_alias).validate(value, merged_opts, env)
      end
    end
  end

  # Generates AST for bare module
  # All validators are arity-3: validate(value, opts, env)
  defp ast_bare_module_to_function(module_alias) do
    quote do
      fn value, runtime_opts, env ->
        unquote(module_alias).validate(value, runtime_opts, env)
      end
    end
  end

  # Transforms {Module, opts} tuple syntax to function calls
  defp ast_transform_list_item(
         {{:__aliases__, _, _} = module_alias, opts_ast},
         _user_env,
         _caller_env
       )
       when is_list(opts_ast) do
    ast_module_with_opts_to_function(module_alias, opts_ast)
  end

  # Transforms bare module syntax to function calls
  defp ast_transform_list_item(
         {:__aliases__, _, _} = module_alias,
         _user_env,
         _caller_env
       ) do
    ast_bare_module_to_function(module_alias)
  end

  # Try to lift function calls, or validate that it's a valid validator
  defp ast_transform_list_item(other, _user_env, caller_env) do
    # First validate - reject literals before attempting to lift
    validate_list_item!(other)

    case ast_lift_call_to_unary(other, caller_env) do
      nil -> other
      lifted -> lifted
    end
  end

  # ============================================================================
  # VALIDATION
  # ============================================================================

  # Validates that list items are functions, not literals
  # Note: Module aliases ({:__aliases__, _, _}) are transformed before validation,
  # so they never reach this function
  # Anonymous function
  defp validate_list_item!({:fn, _, _}), do: :ok
  # Function capture
  defp validate_list_item!({:&, _, _}), do: :ok
  defp validate_list_item!({name, _, context}) when is_atom(name) and is_atom(context), do: :ok
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

  # ============================================================================
  # ERROR HELPERS
  # ============================================================================

  defp raise_bare_module_error(module_alias) do
    raise CompileError, description: Errors.bare_module_error(module_alias)
  end

  defp raise_invalid_operation_error(other) do
    raise CompileError, description: Errors.invalid_operation_error(other)
  end

  defp raise_invalid_function_error(func_name) do
    raise CompileError,
      description: Errors.invalid_function_error(func_name, @all_allowed_functions)
  end

  defp raise_invalid_validator(literal) do
    raise CompileError, description: Errors.invalid_validator_error(literal)
  end
end
