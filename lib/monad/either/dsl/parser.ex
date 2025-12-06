defmodule Funx.Monad.Either.Dsl.Parser do
  @moduledoc false
  # Internal parser for Either DSL - converts AST into Step structs

  alias Funx.Monad.Either.Dsl.Step

  # Operation type classification (for error messages)
  @either_functions [:filter_or_else, :or_else, :map_left, :flip, :tap]
  @bindable_functions [:validate]
  @all_allowed_functions @either_functions ++ @bindable_functions

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
        parse_monad_operation(:bind, args, meta, caller_env)

      {:map, meta, args} ->
        parse_monad_operation(:map, args, meta, caller_env)

      {:ap, meta, args} ->
        {operation, _opts} = parse_operation_args(args)
        %Step.Ap{applicative: operation, __meta__: extract_meta(meta)}

      {:__aliases__, _, _} = module_alias ->
        raise_bare_module_error(module_alias)

      {func_name, meta, args} when is_atom(func_name) and is_list(args) ->
        parse_either_function_to_step(func_name, args, meta, user_env, caller_env)

      other ->
        raise_invalid_operation_error(other)
    end
  end

  # Extract common logic for bind and map operations
  defp parse_monad_operation(type, args, meta, caller_env) do
    {operation, opts} = parse_operation_args(args)
    lifted_op = ast_lift_call_to_unary(operation, caller_env) || operation
    expanded_op = ast_expand_module_alias(lifted_op, caller_env)
    metadata = extract_meta(meta)

    case type do
      :bind -> %Step.Bind{operation: expanded_op, opts: opts, __meta__: metadata}
      :map -> %Step.Map{operation: expanded_op, opts: opts, __meta__: metadata}
    end
  end

  defp parse_either_function_to_step(func_name, args, meta, user_env, caller_env) do
    # Lift function calls and transform modules in arguments
    transformed_args =
      Enum.map(args, fn arg ->
        lifted = ast_lift_call_to_unary(arg, caller_env) || arg
        ast_transform_modules_to_functions(lifted, user_env, caller_env)
      end)

    metadata = extract_meta(meta)

    cond do
      func_name in @either_functions ->
        %Step.EitherFunction{function: func_name, args: transformed_args, __meta__: metadata}

      func_name in @bindable_functions ->
        %Step.BindableFunction{function: func_name, args: transformed_args, __meta__: metadata}

      true ->
        raise_invalid_function_error(func_name)
    end
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

  # Expand module aliases to actual module atoms at compile time
  defp ast_expand_module_alias({:__aliases__, _, _} = module_alias, caller_env) do
    Macro.expand(module_alias, caller_env)
  end

  defp ast_expand_module_alias(other, _caller_env), do: other

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

  # Transform modules in validator lists and arguments
  defp ast_transform_modules_to_functions(arg, user_env, caller_env) do
    case arg do
      # Transform list of validators
      items when is_list(items) ->
        Enum.map(items, &ast_transform_list_item(&1, user_env, caller_env))

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
  defp ast_transform_list_item(
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
  defp ast_transform_list_item({:__aliases__, _, _} = module_alias, user_env, _caller_env) do
    quote do
      fn value -> unquote(module_alias).run(value, [], unquote(user_env)) end
    end
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
        "Invalid operation: #{inspect(other)}. Use 'bind', 'map', 'ap', or Either functions."
  end

  defp raise_invalid_function_error(func_name) do
    raise CompileError,
      description: """
      Invalid operation: #{func_name}

      Bare function calls are not allowed in the DSL pipeline.

      If you meant to call an Either function, only these are allowed:
        #{inspect(@all_allowed_functions)}

      If you meant to use a custom function, you must use 'bind' or 'map':
        bind #{func_name}(...)
        map #{func_name}(...)

      Or use a function capture:
        map &#{func_name}/1

      Or create a module that implements run/3.
      """
  end

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
end
