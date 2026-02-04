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
  #   - check projection, predicate      → Step{projection: proj, predicate: pred, negate: false}
  #   - negate check projection, pred    → Step{projection: proj, predicate: pred, negate: true}
  #   - check projection, do: predicate  → Step{projection: proj, predicate: pred}
  #   - all do ... end                   → Block{strategy: :all, children: [...]}
  #   - any do ... end                   → Block{strategy: :any, children: [...]}
  #   - negate_all do ... end            → Block{strategy: :any, children: [negated...]} (De Morgan)
  #   - negate_any do ... end            → Block{strategy: :all, children: [negated...]} (De Morgan)
  #
  # ## Projections
  #
  # The `check` directive supports:
  #   - Atom fields: `:name` → uses Prism.key(:name)
  #   - List/Struct paths: `[:a, :b]` or `[User, :name]` → uses Prism.path(...)
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

  # Parse "negate_all do ... end"
  # Apply De Morgan's Laws: not(A and B) = (not A) or (not B)
  defp parse_entry_to_node({:negate_all, meta, [[do: block]]}, caller_env) do
    children = parse_operations(block, caller_env)
    negated_children = Enum.map(children, &negate_node/1)
    metadata = extract_meta(meta)
    Block.new(:any, negated_children, metadata)
  end

  # Parse "negate_any do ... end"
  # Apply De Morgan's Laws: not(A or B) = (not A) and (not B)
  defp parse_entry_to_node({:negate_any, meta, [[do: block]]}, caller_env) do
    children = parse_operations(block, caller_env)
    negated_children = Enum.map(children, &negate_node/1)
    metadata = extract_meta(meta)
    Block.new(:all, negated_children, metadata)
  end

  # Parse "any do ... end" or "all do ... end"
  defp parse_entry_to_node({directive, meta, [[do: block]]}, caller_env)
       when directive in [:any, :all] do
    children = parse_operations(block, caller_env)
    metadata = extract_meta(meta)
    Block.new(directive, children, metadata)
  end

  # Parse "check projection, predicate"
  defp parse_entry_to_node({:check, meta, [projection_ast, predicate_ast]}, _caller_env) do
    normalized_projection = normalize_projection(projection_ast)
    normalized_predicate = normalize_check_predicate(predicate_ast)
    metadata = extract_meta(meta)
    Step.new_with_projection(normalized_projection, normalized_predicate, false, metadata)
  end

  # Parse "check projection" (single argument) - defaults to truthy check
  defp parse_entry_to_node({:check, meta, [projection_ast]}, _caller_env) do
    normalized_projection = normalize_projection(projection_ast)
    truthy_predicate = default_truthy_predicate()
    metadata = extract_meta(meta)
    Step.new_with_projection(normalized_projection, truthy_predicate, false, metadata)
  end

  # Parse "negate check projection, predicate" - negated projection
  defp parse_entry_to_node(
         {:negate, meta, [{:check, _check_meta, [projection_ast, predicate_ast]}]},
         _caller_env
       ) do
    normalized_projection = normalize_projection(projection_ast)
    normalized_predicate = normalize_check_predicate(predicate_ast)
    metadata = extract_meta(meta)
    Step.new_with_projection(normalized_projection, normalized_predicate, true, metadata)
  end

  # Parse "negate check projection" (single argument) - negated truthy check
  defp parse_entry_to_node(
         {:negate, meta, [{:check, _check_meta, [projection_ast]}]},
         _caller_env
       ) do
    normalized_projection = normalize_projection(projection_ast)
    truthy_predicate = default_truthy_predicate()
    metadata = extract_meta(meta)
    Step.new_with_projection(normalized_projection, truthy_predicate, true, metadata)
  end

  # Parse "negate predicate" - bare negation
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
          # Error: bare module reference without pred/1 will cause runtime error
          raise CompileError,
            line: Keyword.get(meta, :line),
            description: Errors.bare_module_without_behaviour(expanded_module)
        end

      _ ->
        # Not a module alias, treat as regular predicate
        Step.new(predicate_ast, false, %{})
    end
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

  # Default predicate for single-argument check: truthy check
  # Returns AST for `fn value -> !!value end` (truthy, not strict == true)
  defp default_truthy_predicate do
    quote do
      fn value -> !!value end
    end
  end

  # Normalize predicate AST in check directive
  #
  # Handles behaviour module tuple syntax: {Module, opts} -> Module.pred(opts)
  # All other predicates pass through unchanged.
  #
  # Note: Unlike bare behaviour modules at top-level, we don't validate
  # that the module implements the behaviour at compile time. This matches
  # how the validate DSL handles validators - shape validation only.
  # Runtime will fail with a clear error if the module doesn't have pred/1.
  defp normalize_check_predicate({{:__aliases__, _meta, _} = module_alias, opts})
       when is_list(opts) do
    quote do
      unquote(module_alias).pred(unquote(opts))
    end
  end

  # Bare module reference in check: Module -> Module.pred([])
  defp normalize_check_predicate({:__aliases__, _meta, _} = module_alias) do
    quote do
      unquote(module_alias).pred([])
    end
  end

  # All other predicates pass through unchanged
  defp normalize_check_predicate(predicate_ast), do: predicate_ast

  # Normalize projection AST to canonical form
  #
  # Atoms are converted to Prism.key calls for safe nil handling.
  # Lists are converted to Prism.path calls for nested field access (supports structs too).
  # Optics and functions are validated and passed through.
  defp normalize_projection(atom) when is_atom(atom) do
    quote do
      Prism.key(unquote(atom))
    end
  end

  defp normalize_projection(list) when is_list(list) do
    quote do
      Prism.path(unquote(list))
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

  # Variables - pass through (runtime values)
  defp normalize_projection({var_name, _, context} = var_ast)
       when is_atom(var_name) and is_atom(context) do
    var_ast
  end

  # Module function calls - pass through (e.g., OpticHelpers.my_lens())
  defp normalize_projection({{:., _, _}, _, _} = call_ast) do
    call_ast
  end

  # Invalid projection type
  defp normalize_projection(other_ast) do
    raise CompileError,
      description: Errors.invalid_projection_type(other_ast)
  end

  # ============================================================================
  # De Morgan's Law Helpers
  # ============================================================================

  # Flip strategy for De Morgan's transformation
  defp flip_strategy(:any), do: :all
  defp flip_strategy(:all), do: :any

  # Negate a node (Step or Block)
  defp negate_node(%Step{negate: negate} = step) do
    # Flip the negate flag
    %{step | negate: not negate}
  end

  defp negate_node(%Block{strategy: strategy, children: children} = block) do
    # Apply De Morgan's recursively: flip strategy and negate children
    flipped_strategy = flip_strategy(strategy)
    negated_children = Enum.map(children, &negate_node/1)
    %{block | strategy: flipped_strategy, children: negated_children}
  end
end
