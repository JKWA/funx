defmodule Funx.Eq.Dsl.Parser do
  @moduledoc false
  # Compile-time parser that converts Eq DSL syntax into typed AST nodes.
  #
  # ## Architecture Overview
  #
  # The parser is the first phase of DSL compilation:
  #   1. Parser (this module) - Normalizes syntax → typed Step/Block nodes
  #   2. Executor - Converts nodes → quoted runtime code
  #   3. Runtime - Executes compiled equality checks
  #
  # ## Type-Based Optimization
  #
  # The parser detects projection types at compile time to eliminate runtime
  # branching and warnings. Each Step is tagged with one of:
  #
  #   - :projection - Optics (Lens/Prism/Traversal) or functions → contramap
  #   - :module_eq  - Module with eq?/2 (like Funx.Eq) → to_eq_map
  #   - :eq_map     - Behaviour returning Eq map → use directly
  #   - :dynamic    - 0-arity helpers (unknown type) → runtime detection
  #
  # This allows the executor to generate specific code paths instead of
  # runtime case statements that trigger compiler warnings.
  #
  # ## Syntax Normalization
  #
  # All user syntax is normalized to canonical forms that contramap/2 accepts:
  #
  #   - :atom              → Prism.key(:atom)
  #   - :atom, or_else: x  → {Prism.key(:atom), x}
  #   - Lens.key(...)      → pass through
  #   - Prism.key(...)     → pass through (or tuple with or_else)
  #   - fn x -> ... end    → pass through
  #   - Module with eq?/2  → module atom (converted by executor)
  #   - Module with eq/1   → Module.eq(opts) call (returns Eq map)
  #   - Struct module      → type filter function
  #
  # ## Nested Blocks
  #
  # The DSL supports nested any/all blocks for complex logic:
  #
  #   - any do ... end  → Block{strategy: :any, children: [...]}
  #   - all do ... end  → Block{strategy: :all, children: [...]}
  #
  # Top-level is implicitly "all" (AND logic).

  alias Funx.Eq.Dsl.{Block, Errors, Step}
  alias Funx.Optics.Prism

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

  # Parse "on value, opt: val" or "on value" or "not_on value"
  defp parse_entry_to_node({directive, meta, [[do: block]]}, caller_env)
       when directive in [:any, :all] do
    children = parse_operations(block, caller_env)
    metadata = extract_meta(meta)
    Block.new(directive, children, metadata)
  end

  defp parse_entry_to_node({directive, meta, [projection_value, opts]}, caller_env)
       when directive in [:on, :not_on] and is_list(opts) do
    negate = directive == :not_on
    parse_projection(projection_value, opts, negate, meta, caller_env)
  end

  defp parse_entry_to_node({directive, meta, [projection_value]}, caller_env)
       when directive in [:on, :not_on] do
    negate = directive == :not_on
    parse_projection(projection_value, [], negate, meta, caller_env)
  end

  defp parse_entry_to_node(other, _caller_env) do
    raise CompileError, description: Errors.invalid_dsl_syntax(other)
  end

  # Parses a single projection (on/not_on directive) into a Step node.
  #
  # Separates DSL-reserved options (:or_else, :eq) from behaviour options,
  # then delegates to build_projection_ast for type-specific handling.
  defp parse_projection(projection_value, opts, negate, meta, caller_env) do
    or_else = Keyword.get(opts, :or_else)
    custom_eq = Keyword.get(opts, :eq)
    behaviour_opts = Keyword.drop(opts, [:or_else, :eq])

    {projection_ast, type} =
      build_projection_ast(projection_value, or_else, behaviour_opts, meta, caller_env)

    eq_ast = custom_eq || quote(do: Funx.Eq)
    metadata = extract_meta(meta)

    Step.new(projection_ast, eq_ast, negate, type, metadata)
  end

  # Atom without or_else
  defp build_projection_ast(atom, nil, _behaviour_opts, _meta, _caller_env) when is_atom(atom) do
    ast =
      quote do
        Prism.key(unquote(atom))
      end

    {ast, :projection}
  end

  # Atom with or_else
  defp build_projection_ast(atom, or_else, _behaviour_opts, _meta, _caller_env)
       when is_atom(atom) and not is_nil(or_else) do
    ast =
      quote do
        {Prism.key(unquote(atom)), unquote(or_else)}
      end

    {ast, :projection}
  end

  # Captured function
  defp build_projection_ast({:&, _, _} = fun_ast, or_else, _behaviour_opts, meta, _caller_env) do
    if is_nil(or_else) do
      {fun_ast, :projection}
    else
      raise CompileError,
        line: Keyword.get(meta, :line),
        description: Errors.or_else_with_captured_function()
    end
  end

  # Anonymous function
  defp build_projection_ast({:fn, _, _} = fun_ast, or_else, _behaviour_opts, meta, _caller_env) do
    if is_nil(or_else) do
      {fun_ast, :projection}
    else
      raise CompileError,
        line: Keyword.get(meta, :line),
        description: Errors.or_else_with_anonymous_function()
    end
  end

  # Helper function call (0-arity)
  #
  # Handles calls like `EqHelpers.by_name()` which could return either a
  # projection or an Eq map. We can't determine the return type at compile time.
  #
  # Without or_else: Use :dynamic type for runtime detection
  # With or_else: Creates {result, or_else} tuple → :projection type
  #   (contramap handles tuples directly)
  defp build_projection_ast(
         {{:., _, [{:__aliases__, _, _}, _]}, _, args} = fun_ast,
         or_else,
         _behaviour_opts,
         _meta,
         _caller_env
       )
       when args == [] or is_nil(args) do
    if is_nil(or_else) do
      {fun_ast, :dynamic}
    else
      ast =
        quote do
          {unquote(fun_ast), unquote(or_else)}
        end

      {ast, :projection}
    end
  end

  # Lens.key
  defp build_projection_ast(
         {{:., _, [{:__aliases__, _, [:Lens]}, :key]}, _, _} = lens_ast,
         or_else,
         _behaviour_opts,
         meta,
         _caller_env
       ) do
    if is_nil(or_else) do
      {lens_ast, :projection}
    else
      raise CompileError,
        line: Keyword.get(meta, :line),
        description: Errors.or_else_with_lens()
    end
  end

  # Lens.path
  defp build_projection_ast(
         {{:., _, [{:__aliases__, _, [:Lens]}, :path]}, _, _} = lens_ast,
         or_else,
         _behaviour_opts,
         meta,
         _caller_env
       ) do
    if is_nil(or_else) do
      {lens_ast, :projection}
    else
      raise CompileError,
        line: Keyword.get(meta, :line),
        description: Errors.or_else_with_lens()
    end
  end

  # Prism (any Prism function)
  defp build_projection_ast(
         {{:., _, [{:__aliases__, _, [:Prism]}, _]}, _, _} = prism_ast,
         or_else,
         _behaviour_opts,
         _meta,
         _caller_env
       ) do
    ast =
      if is_nil(or_else) do
        prism_ast
      else
        quote do
          {unquote(prism_ast), unquote(or_else)}
        end
      end

    {ast, :projection}
  end

  # Traversal (any Traversal function)
  defp build_projection_ast(
         {{:., _, [{:__aliases__, _, [:Traversal]}, _]}, _, _} = traversal_ast,
         or_else,
         _behaviour_opts,
         meta,
         _caller_env
       ) do
    if is_nil(or_else) do
      {traversal_ast, :projection}
    else
      raise CompileError,
        line: Keyword.get(meta, :line),
        description: Errors.or_else_with_traversal()
    end
  end

  # Tuple with prism and or_else
  defp build_projection_ast({prism_ast, or_else_ast}, nil, _behaviour_opts, _meta, _caller_env) do
    ast =
      quote do
        {unquote(prism_ast), unquote(or_else_ast)}
      end

    {ast, :projection}
  end

  defp build_projection_ast(
         {_prism_ast, _or_else_ast},
         _extra_or_else,
         _behaviour_opts,
         meta,
         _caller_env
       ) do
    raise CompileError,
      line: Keyword.get(meta, :line),
      description: Errors.redundant_or_else()
  end

  # Module reference - determines module type and generates appropriate code
  #
  # Modules can serve three purposes in the DSL, checked in precedence order:
  #
  # 1. Eq module (has eq?/2) - e.g., Funx.Eq, custom Eq implementations
  #    Returns: module atom with :module_eq type
  #    Executor: Calls Utils.to_eq_map(module)
  #
  # 2. Behaviour (has eq/1) - returns Eq map from options
  #    Returns: Module.eq(opts) call with :eq_map type
  #    Executor: Uses the returned Eq map directly
  #
  # 3. Struct (has __struct__/0) - type filter for structural equality
  #    Returns: fn %Struct{} -> true; _ -> false end with :projection type
  #    Executor: Wraps in contramap (always returns true for same type)
  #
  # Note: or_else is rejected with modules since it only makes sense with
  # optional projections (Prisms), not with Eq implementations or type filters.
  defp build_projection_ast(
         {:__aliases__, _, _} = module_alias,
         or_else,
         behaviour_opts,
         meta,
         caller_env
       ) do
    unless is_nil(or_else) do
      raise CompileError,
        line: Keyword.get(meta, :line),
        description: Errors.or_else_with_behaviour()
    end

    expanded_module = Macro.expand(module_alias, caller_env)

    cond do
      function_exported?(expanded_module, :eq?, 2) ->
        {module_alias, :module_eq}

      function_exported?(expanded_module, :eq, 1) ->
        ast = build_behaviour_eq_ast(expanded_module, behaviour_opts, meta)
        {ast, :eq_map}

      function_exported?(expanded_module, :__struct__, 0) ->
        ast = build_struct_filter_ast(expanded_module)
        {ast, :projection}

      true ->
        raise CompileError,
          line: Keyword.get(meta, :line),
          description:
            "Module #{inspect(expanded_module)} does not have eq?/2, eq/1, or __struct__/0"
    end
  end

  # Unknown projection type
  defp build_projection_ast(other, _or_else, _behaviour_opts, meta, _caller_env) do
    raise CompileError,
      line: Keyword.get(meta, :line),
      description: Errors.invalid_projection_type(other)
  end

  # Generates a type filter function for struct modules.
  #
  # Used when a struct module doesn't implement Eq or Behaviour - creates
  # a function that returns true only for instances of that struct type.
  # When wrapped in contramap, this makes equality checks only pass for
  # values of the same struct type (structural equality).
  defp build_struct_filter_ast(struct_module) do
    quote do
      fn
        %unquote(struct_module){} -> true
        _ -> false
      end
    end
  end

  # Generates a call to the behaviour's eq/1 function with options.
  #
  # The behaviour's eq/1 returns an Eq map at runtime, which the executor
  # uses directly (no contramap wrapping needed).
  defp build_behaviour_eq_ast(behaviour_module, behaviour_opts, _meta) do
    quote do
      unquote(behaviour_module).eq(unquote(behaviour_opts))
    end
  end

  # Extracts line and column metadata for error reporting.
  defp extract_meta(meta) when is_list(meta) do
    %{
      line: Keyword.get(meta, :line),
      column: Keyword.get(meta, :column)
    }
  end
end
