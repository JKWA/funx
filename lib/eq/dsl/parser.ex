defmodule Funx.Eq.Dsl.Parser do
  @moduledoc false
  # Internal parser for Eq DSL - converts AST into Step and Block structs
  #
  # ## Normalization Contract
  #
  # This parser normalizes all projection syntax into one of four canonical types
  # that contramap/2 accepts:
  #
  #   1. Lens.t()              - bare Lens struct
  #   2. Prism.t()             - bare Prism struct
  #   3. {Prism.t(), or_else}  - Prism with or_else value
  #   4. (a -> b)              - projection function
  #
  # All syntax sugar resolves to these types:
  #
  #   - :atom              → Prism.key(:atom)
  #   - :atom, or_else: x  → {Prism.key(:atom), x}
  #   - Lens.key(...)      → Lens.key(...) (pass through)
  #   - Prism.key(...)     → Prism.key(...) (pass through)
  #   - {Prism, x}         → {Prism, x} (pass through)
  #   - fn -> ... end      → fn -> ... end (pass through)
  #   - Behaviour          → fn v -> Behaviour.project(v, []) end
  #
  # ## Nesting Support
  #
  # Unlike Ord DSL, Eq DSL supports nested blocks:
  #
  #   - any do ... end     → Block with strategy: :any
  #   - all do ... end     → Block with strategy: :all
  #
  # These create a tree structure instead of a flat list.
  #
  # contramap/2 is the ONLY place that converts optics to functions.
  # The parser never creates function wrappers around optics.

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

  defp parse_projection(projection_value, opts, negate, meta, caller_env) do
    or_else = Keyword.get(opts, :or_else)
    custom_eq = Keyword.get(opts, :eq)

    # Separate DSL-reserved options from behaviour options
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
  defp build_projection_ast(
         {{:., _, [{:__aliases__, _, _}, _]}, _, args} = fun_ast,
         or_else,
         _behaviour_opts,
         _meta,
         _caller_env
       )
       when args == [] or is_nil(args) do
    if is_nil(or_else) do
      # No or_else - could be projection or Eq map, use runtime detection
      {fun_ast, :dynamic}
    else
      # With or_else - creates tuple {result, or_else} which contramap handles
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

  # Module (with eq?/2, behaviour eq/1, or struct type filter)
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
      # Check if module has eq?/2 directly (like Funx.Eq, custom Eq modules)
      function_exported?(expanded_module, :eq?, 2) ->
        # Return the module directly - executor will use it as Eq
        {module_alias, :module_eq}

      # Check if module has eq/1 (Behaviour)
      function_exported?(expanded_module, :eq, 1) ->
        # Call the behaviour's eq/1 to get Eq map
        ast = build_behaviour_eq_ast(expanded_module, behaviour_opts, meta)
        {ast, :eq_map}

      # Check if it's a struct without Behaviour - use as type filter
      function_exported?(expanded_module, :__struct__, 0) ->
        ast = build_struct_filter_ast(expanded_module)
        {ast, :projection}

      # Unknown module type
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

  defp build_struct_filter_ast(struct_module) do
    quote do
      fn
        %unquote(struct_module){} -> true
        _ -> false
      end
    end
  end

  defp build_behaviour_eq_ast(behaviour_module, behaviour_opts, _meta) do
    quote do
      unquote(behaviour_module).eq(unquote(behaviour_opts))
    end
  end

  defp extract_meta(meta) when is_list(meta) do
    %{
      line: Keyword.get(meta, :line),
      column: Keyword.get(meta, :column)
    }
  end
end
