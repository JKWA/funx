defmodule Funx.Predicate.Dsl.Parser do
  @moduledoc false
  # Compile-time parser that converts Predicate DSL syntax into Step/Block nodes.
  #
  # ## Architecture Overview
  #
  # The parser is the first phase of DSL compilation:
  #   1. Parser (this module) - Normalizes syntax → Step/Block nodes
  #   2. Executor - Converts nodes → quoted runtime code
  #   3. Runtime - Executes compiled predicate checks
  #
  # ## Syntax Recognition
  #
  # The parser recognizes these forms:
  #
  #   - Bare predicate                   → Step{predicate: ast, negate: false}
  #   - negate predicate                 → Step{predicate: ast, negate: true}
  #   - check projection, predicate      → Step{projection: proj, predicate: pred}
  #   - check projection, do: predicate  → Step{projection: proj, predicate: pred}
  #   - all do ... end                   → Block{strategy: :all, children: [...]}
  #   - any do ... end                   → Block{strategy: :any, children: [...]}
  #
  # ## Projections
  #
  # The `check` directive supports:
  #   - Atom fields: `:name` → uses Prism.key(:name)
  #   - Lens: `Lens.key(:name)` or `Lens.path([:a, :b])`
  #   - Prism: `Prism.key(:name)`, `Prism.at(0)`, etc.
  #   - Functions: `&get_value/1` or `fn x -> x.value end`

  alias Funx.Optics.Prism
  alias Funx.Predicate.Dsl.{Block, Errors, Step}

  @doc """
  Parse a DSL block into a list of Step/Block nodes
  """
  def parse_operations(block, caller_env) do
    block
    |> extract_operations()
    |> Enum.map(&parse_entry_to_node(&1, caller_env))
  end

  defp extract_operations({:__block__, _meta, lines}) when is_list(lines), do: lines
  defp extract_operations(single_line), do: [single_line]

  # Parse "any do ... end" or "all do ... end"
  defp parse_entry_to_node({directive, meta, [[do: block]]}, caller_env)
       when directive in [:any, :all] do
    children = parse_operations(block, caller_env)

    if Enum.empty?(children) do
      raise CompileError,
        line: Keyword.get(meta, :line),
        description: Errors.empty_block(directive)
    end

    metadata = extract_meta(meta)
    Block.new(directive, children, metadata)
  end

  # Parse "check projection, predicate"
  defp parse_entry_to_node({:check, meta, [projection_ast, predicate_ast]}, _caller_env) do
    normalized_projection = normalize_projection(projection_ast)
    metadata = extract_meta(meta)
    Step.new_with_projection(normalized_projection, predicate_ast, false, metadata)
  end

  # Parse "negate predicate"
  defp parse_entry_to_node({:negate, meta, [predicate_ast]}, _caller_env) do
    metadata = extract_meta(meta)
    Step.new(predicate_ast, true, metadata)
  end

  # Parse "negate" without predicate (error)
  defp parse_entry_to_node({:negate, meta, nil}, _caller_env) do
    raise CompileError,
      line: Keyword.get(meta, :line),
      description: Errors.negate_without_predicate()
  end

  defp parse_entry_to_node({:negate, meta, []}, _caller_env) do
    raise CompileError,
      line: Keyword.get(meta, :line),
      description: Errors.negate_without_predicate()
  end

  # Parse behaviour module with options: "{HasMinimumAge, minimum: 21}"
  defp parse_entry_to_node({{:__aliases__, meta, _} = module_alias, opts}, caller_env)
       when is_list(opts) do
    parse_behaviour_module(module_alias, opts, meta, caller_env)
  end

  # Parse bare behaviour module or other AST
  # This catch-all handles:
  # - Behaviour modules: IsActive → check if module has pred/1
  # - Other predicates: variables, functions, etc.
  defp parse_entry_to_node(predicate_ast, caller_env) do
    case predicate_ast do
      {:__aliases__, meta, _} = module_alias ->
        # Try to parse as behaviour module
        expanded_module = Macro.expand(module_alias, caller_env)

        if function_exported?(expanded_module, :pred, 1) do
          parse_behaviour_module(module_alias, [], meta, caller_env)
        else
          # Warn: bare module reference without pred/1 will cause runtime error
          emit_bare_module_warning(expanded_module, meta)
          # Not a behaviour, treat as regular predicate (will fail at runtime)
          Step.new(predicate_ast, false, %{})
        end

      _ ->
        # Not a module alias, treat as regular predicate
        Step.new(predicate_ast, false, %{})
    end
  end

  defp emit_bare_module_warning(module, meta) do
    IO.warn(
      """
      Bare module reference #{inspect(module)} does not implement Predicate.Dsl.Behaviour.

      This will cause a BadFunctionError at runtime because module atoms are not functions.

      To fix, choose one of:
        1. Implement the Predicate.Dsl.Behaviour:
           @behaviour Funx.Predicate.Dsl.Behaviour
           def pred(_opts), do: fn value -> ... end

        2. Use tuple syntax to pass options:
           {#{inspect(module)}, []}

        3. Call a function explicitly:
           #{inspect(module)}.my_predicate_function()

        4. Use a variable or captured function instead:
           my_predicate  # where my_predicate is bound to a function
      """,
      Keyword.take(meta, [:line, :file])
    )
  end

  defp parse_behaviour_module(module_alias, opts, meta, caller_env) do
    expanded_module = Macro.expand(module_alias, caller_env)

    unless function_exported?(expanded_module, :pred, 1) do
      raise CompileError,
        line: Keyword.get(meta, :line),
        description:
          "Module #{inspect(expanded_module)} does not implement the Predicate.Dsl.Behaviour (missing pred/1)"
    end

    # Generate AST to call Module.pred(opts) at runtime
    behaviour_ast =
      quote do
        unquote(module_alias).pred(unquote(opts))
      end

    metadata = extract_meta(meta)
    Step.new_behaviour(behaviour_ast, false, metadata)
  end

  defp extract_meta(meta) do
    %{
      line: Keyword.get(meta, :line),
      file: Keyword.get(meta, :file)
    }
  end

  # Normalize projection AST to canonical form
  #
  # Atoms are converted to Prism.key calls for safe nil handling.
  # Optics and functions are passed through as-is.
  defp normalize_projection(atom) when is_atom(atom) do
    quote do
      Prism.key(unquote(atom))
    end
  end

  # Lens/Prism/Traversal - pass through
  defp normalize_projection({{:., _, [{:__aliases__, _, [:Lens | _]}, _]}, _, _} = optic_ast) do
    optic_ast
  end

  defp normalize_projection({{:., _, [{:__aliases__, _, [:Prism | _]}, _]}, _, _} = optic_ast) do
    optic_ast
  end

  defp normalize_projection({{:., _, [{:__aliases__, _, [:Traversal | _]}, _]}, _, _} = optic_ast) do
    optic_ast
  end

  # Functions (captured and anonymous) - pass through
  defp normalize_projection({:&, _, _} = fun_ast), do: fun_ast
  defp normalize_projection({:fn, _, _} = fun_ast), do: fun_ast

  # Everything else - pass through (will be evaluated at runtime)
  defp normalize_projection(other_ast), do: other_ast
end
