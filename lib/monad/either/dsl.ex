defmodule Funx.Monad.Either.Dsl do
  @moduledoc """
  Provides a declarative DSL for composing error-handling pipelines using Kleisli composition.

  ... (UNCHANGED DOCSTRING, OMITTED FOR BREVITY)
  """

  # credo:disable-for-this-file Credo.Check.Design.AliasUsage
  alias Funx.Monad.Either

  defmacro __using__(_opts) do
    quote do
      import Funx.Monad.Either.Dsl
    end
  end

  # ============================================================================
  # Helper: Auto-pipe lifting of Module.fun(args...)
  # ============================================================================

  # Detect a call like Module.fun(args...) and rewrite it into:
  #   fn x -> Module.fun(x, args...) end
  defp lift_call_to_unary({{:., _, [mod_ast, fun_atom]}, _, args_ast}) do
    quote do
      fn x ->
        unquote(mod_ast).unquote(fun_atom)(x, unquote_splicing(args_ast))
      end
    end
  end

  # Not a call expression we can lift → return nil
  defp lift_call_to_unary(_other), do: nil

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
            (for example via the Funx.Monad.Dsl.Behaviour).
            """
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
        import Either
        unquote(result)
      end).()
    end
  end

  # ============================================================================
  # First operation
  # ============================================================================

  defp compile_first_operation(input, operation_ast, user_env, caller_env) do
    case operation_ast do
      {:bind, _, [operation]} ->
        compile_first_bind_operation(input, operation, [], user_env, caller_env)

      {:bind, _, [operation, opts]} when is_list(opts) ->
        compile_first_bind_operation(input, operation, opts, user_env, caller_env)

      {:map, _, [operation]} ->
        compile_first_map_operation(input, operation, [], user_env, caller_env)

      {:map, _, [operation, opts]} when is_list(opts) ->
        compile_first_map_operation(input, operation, opts, user_env, caller_env)

      {:run, _, [operation]} ->
        compile_first_run_operation(input, operation, [], user_env, caller_env)

      {:run, _, [operation, opts]} when is_list(opts) ->
        compile_first_run_operation(input, operation, opts, user_env, caller_env)

      {func_name, meta, args} when is_atom(func_name) and is_list(args) ->
        transformed_args = Enum.map(args, &transform_modules_to_functions(&1, user_env))

        quote do
          unquote({func_name, meta, [input | transformed_args]})
        end

      {:__aliases__, _, _} = module_alias ->
        raise CompileError,
          description: """
          Invalid operation: #{Macro.to_string(module_alias)}

          Modules must be used with a keyword:
            run #{Macro.to_string(module_alias)}
            bind #{Macro.to_string(module_alias)}
            map #{Macro.to_string(module_alias)}
          """

      other ->
        raise CompileError,
          description: "Invalid operation: #{inspect(other)}. Use 'run', 'bind', 'map', or Either functions."
    end
  end

  # ============================================================================
  # First bind
  # ============================================================================

  defp compile_first_bind_operation(input, operation, opts, user_env, caller_env) do
    operation =
      case lift_call_to_unary(operation) do
        nil -> operation
        lifted -> lifted
      end

    case operation do
      {:__aliases__, _, _} = module_alias ->
        ensure_step_module_has_run!(module_alias, caller_env)

        quote do
          Funx.Monad.bind(unquote(input), fn value ->
            Funx.Monad.Either.Dsl.normalize_run_result(
              unquote(module_alias).run(value, unquote(user_env), unquote(opts))
            )
          end)
        end

      module when is_atom(module) ->
        quote do
          Funx.Monad.bind(unquote(input), fn value ->
            Funx.Monad.Either.Dsl.normalize_run_result(
              unquote(module).run(value, unquote(user_env), unquote(opts))
            )
          end)
        end

      func ->
        quote do
          Funx.Monad.bind(unquote(input), fn value ->
            Funx.Monad.Either.Dsl.normalize_run_result(
              unquote(func).(value)
            )
          end)
        end
    end
  end

  # ============================================================================
  # First map
  # ============================================================================

  defp compile_first_map_operation(input, operation, opts, user_env, caller_env) do
    operation =
      case lift_call_to_unary(operation) do
        nil -> operation
        lifted -> lifted
      end

    case operation do
      {:__aliases__, _, _} = module_alias ->
        ensure_step_module_has_run!(module_alias, caller_env)

        quote do
          Funx.Monad.map(unquote(input), fn value ->
            unquote(module_alias).run(value, unquote(user_env), unquote(opts))
          end)
        end

      module when is_atom(module) ->
        quote do
          Funx.Monad.map(unquote(input), fn value ->
            unquote(module).run(value, unquote(user_env), unquote(opts))
          end)
        end

      func ->
        quote do
          Funx.Monad.map(unquote(input), unquote(func))
        end
    end
  end

  # ============================================================================
  # First run
  # ============================================================================

  defp compile_first_run_operation(input, operation, opts, user_env, _caller_env) do
    case operation do
      {:__aliases__, _, _} = module_alias ->
        quote do
          unquote(module_alias).run(unquote(input), unquote(user_env), unquote(opts))
        end

      module when is_atom(module) ->
        quote do
          unquote(module).run(unquote(input), unquote(user_env), unquote(opts))
        end

      func ->
        quote do
          unquote(func).(unquote(input))
        end
    end
  end

  # ============================================================================
  # Subsequent operations
  # ============================================================================

  defp compile_operation(previous, operation_ast, user_env, caller_env) do
    case operation_ast do
      {:bind, _, [operation]} ->
        compile_bind_operation(previous, operation, [], user_env, caller_env)

      {:bind, _, [operation, opts]} when is_list(opts) ->
        compile_bind_operation(previous, operation, opts, user_env, caller_env)

      {:map, _, [operation]} ->
        compile_map_operation(previous, operation, [], user_env, caller_env)

      {:map, _, [operation, opts]} when is_list(opts) ->
        compile_map_operation(previous, operation, opts, user_env, caller_env)

      {:run, _, [operation]} ->
        compile_run_operation(previous, operation, [], user_env, caller_env)

      {:run, _, [operation, opts]} when is_list(opts) ->
        compile_run_operation(previous, operation, opts, user_env, caller_env)

      {func_name, meta, args} when is_atom(func_name) and is_list(args) ->
        compile_either_function(previous, func_name, meta, args, user_env)

      {:__aliases__, _, _} = module_alias ->
        raise CompileError,
          description: """
          Invalid operation: #{Macro.to_string(module_alias)}

          Use run/bind/map with modules.
          """

      other ->
        raise CompileError,
          description: "Invalid operation: #{inspect(other)}."
    end
  end

  # ============================================================================
  # bind (subsequent)
  # ============================================================================

  defp compile_bind_operation(previous, operation, opts, user_env, caller_env) do
    operation =
      case lift_call_to_unary(operation) do
        nil -> operation
        lifted -> lifted
      end

    case operation do
      {:__aliases__, _, _} = module_alias ->
        ensure_step_module_has_run!(module_alias, caller_env)

        quote do
          Funx.Monad.bind(unquote(previous), fn value ->
            Funx.Monad.Either.Dsl.normalize_run_result(
              unquote(module_alias).run(value, unquote(user_env), unquote(opts))
            )
          end)
        end

      module when is_atom(module) ->
        quote do
          Funx.Monad.bind(unquote(previous), fn value ->
            Funx.Monad.Either.Dsl.normalize_run_result(
              unquote(module).run(value, unquote(user_env), unquote(opts))
            )
          end)
        end

      func ->
        quote do
          Funx.Monad.bind(unquote(previous), fn value ->
            Funx.Monad.Either.Dsl.normalize_run_result(
              unquote(func).(value)
            )
          end)
        end
    end
  end

  # ============================================================================
  # map (subsequent)
  # ============================================================================

  defp compile_map_operation(previous, operation, opts, user_env, caller_env) do
    operation =
      case lift_call_to_unary(operation) do
        nil -> operation
        lifted -> lifted
      end

    case operation do
      {:__aliases__, _, _} = module_alias ->
        ensure_step_module_has_run!(module_alias, caller_env)

        quote do
          Funx.Monad.map(unquote(previous), fn value ->
            unquote(module_alias).run(value, unquote(user_env), unquote(opts))
          end)
        end

      module when is_atom(module) ->
        quote do
          Funx.Monad.map(unquote(previous), fn value ->
            unquote(module).run(value, unquote(user_env), unquote(opts))
          end)
        end

      func ->
        quote do
          Funx.Monad.map(unquote(previous), unquote(func))
        end
    end
  end

  # ============================================================================
  # run (subsequent)
  # ============================================================================

  defp compile_run_operation(previous, operation, opts, user_env, _caller_env) do
    case operation do
      {:__aliases__, _, _} = module_alias ->
        quote do
          unquote(module_alias).run(unquote(previous), unquote(user_env), unquote(opts))
        end

      module when is_atom(module) ->
        quote do
          unquote(module).run(unquote(previous), unquote(user_env), unquote(opts))
        end

      func ->
        quote do
          unquote(func).(unquote(previous))
        end
    end
  end

  # ============================================================================
  # Either.function support
  # ============================================================================

  defp compile_either_function(previous, func_name, _meta, args, user_env) do
    transformed_args = Enum.map(args, &transform_modules_to_functions(&1, user_env))

    case func_name do
      func when func in [:filter_or_else, :or_else, :map_left, :get_or_else] ->
        quote do
          unquote(func_name)(unquote(previous), unquote_splicing(transformed_args))
        end

      _ ->
        quote do
          Funx.Monad.bind(unquote(previous), fn value ->
            unquote(func_name)(value, unquote_splicing(transformed_args))
          end)
        end
    end
  end

  # ============================================================================
  # Transform modules in validator lists
  # ============================================================================

  defp transform_modules_to_functions(arg, user_env) do
    case arg do
      items when is_list(items) ->
        Enum.map(items, &transform_list_item(&1, user_env))

      other ->
        other
    end
  end

  defp transform_list_item({:__aliases__, _, _} = module_alias, user_env) do
    quote do
      fn value -> unquote(module_alias).run(value, unquote(user_env), []) end
    end
  end

  defp transform_list_item(other, _user_env), do: other

  # ============================================================================
  # Lift input into Either context
  # ============================================================================

  @doc false
  @spec lift_input(any() | Either.t() | {:ok, any()} | {:error, any()}) :: Either.t()
  def lift_input(input) do
    case input do
      # Already an Either - pass through
      %Either.Right{} = either -> either
      %Either.Left{} = either -> either

      # Result tuple - convert to Either
      {:ok, value} -> Either.right(value)
      {:error, reason} -> Either.left(reason)

      # Plain value - wrap in Right
      value -> Either.pure(value)
    end
  end

  # ============================================================================
  # normalize tuple/Either returns
  # ============================================================================

  @doc false
  @spec normalize_run_result(tuple() | Either.t()) :: Either.t()
  def normalize_run_result(result) do
    case result do
      {:ok, value} -> Either.right(value)
      {:error, reason} -> Either.left(reason)
      %Either.Right{} = either -> either
      %Either.Left{} = either -> either

      other ->
        raise ArgumentError, """
        run/1 must return either an Either struct or a result tuple.
        Got: #{inspect(other)}
        """
    end
  end

  # ============================================================================
  # return type wrapping
  # ============================================================================

  defp wrap_with_return_type(pipeline_ast, return_as) do
    case return_as do
      :either ->
        pipeline_ast

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
          description: "Invalid return type: #{inspect(return_as)}. Must be :either, :tuple, or :raise"
    end
  end
end
