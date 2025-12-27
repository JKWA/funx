defmodule Funx.Ord.Dsl.Parser do
  @moduledoc false
  # Internal parser for Ord DSL - converts keyword list AST into Step structs
  #
  # ## Normalization Contract
  #
  # This parser normalizes all projection syntax into one of four canonical types
  # that contramap/2 accepts:
  #
  #   1. Lens.t()              - bare Lens struct
  #   2. Prism.t()             - bare Prism struct (uses Maybe.lift_ord)
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
  # contramap/2 is the ONLY place that converts optics to functions.
  # The parser never creates function wrappers around optics.

  alias Funx.Optics.Prism
  alias Funx.Ord.Dsl.Errors
  alias Funx.Ord.Dsl.Step

  # ============================================================================
  # PUBLIC API
  # ============================================================================

  @doc """
  Parse a DSL block into a list of Step structs
  """
  def parse_operations(block, caller_env) do
    block
    |> extract_operations()
    |> Enum.map(&parse_entry_to_step(&1, caller_env))
  end

  # ============================================================================
  # OPERATION EXTRACTION
  # ============================================================================

  defp extract_operations({:__block__, _meta, lines}) when is_list(lines), do: lines
  defp extract_operations(single_line), do: [single_line]

  # ============================================================================
  # ENTRY PARSING
  # ============================================================================

  # Parse "asc value, opt: val" or "desc value" syntax
  # AST format: {direction, meta, [value, [opts]]} for function-style calls with options
  # or {direction, meta, [value]} for function-style calls without options
  defp parse_entry_to_step({direction, meta, [projection_value, opts]}, caller_env)
       when direction in [:asc, :desc] and is_list(opts) do
    parse_projection(direction, projection_value, opts, meta, caller_env)
  end

  defp parse_entry_to_step({direction, meta, [projection_value]}, caller_env)
       when direction in [:asc, :desc] do
    parse_projection(direction, projection_value, [], meta, caller_env)
  end

  defp parse_entry_to_step(other, _caller_env) do
    raise CompileError, description: Errors.invalid_dsl_syntax(other)
  end

  # ============================================================================
  # PROJECTION PARSING
  # ============================================================================

  defp parse_projection(direction, projection_value, opts, meta, caller_env) do
    or_else = Keyword.get(opts, :or_else)
    custom_ord = Keyword.get(opts, :ord)
    behaviour_opts = Keyword.drop(opts, [:or_else, :ord])

    {projection_ast, type} =
      build_projection_ast(projection_value, or_else, behaviour_opts, meta, caller_env)

    ord_ast = custom_ord || quote(do: Funx.Ord)
    metadata = extract_meta(meta)

    Step.new(direction, projection_ast, ord_ast, type, metadata)
  end

  # ============================================================================
  # PROJECTION AST BUILDING
  # ============================================================================

  defp build_projection_ast(atom, nil, _behaviour_opts, _meta, _caller_env) when is_atom(atom) do
    ast =
      quote do
        Prism.key(unquote(atom))
      end

    {ast, :projection}
  end

  defp build_projection_ast(atom, or_else, _behaviour_opts, _meta, _caller_env)
       when is_atom(atom) and not is_nil(or_else) do
    ast =
      quote do
        {Prism.key(unquote(atom)), unquote(or_else)}
      end

    {ast, :projection}
  end

  defp build_projection_ast({:&, _, _} = fun_ast, or_else, _behaviour_opts, meta, _caller_env) do
    if is_nil(or_else) do
      {fun_ast, :projection}
    else
      raise CompileError,
        line: Keyword.get(meta, :line),
        description: Errors.or_else_with_captured_function()
    end
  end

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
  # Handles calls like `OrdHelpers.by_name()` which could return either a
  # projection or an Ord map. We can't determine the return type at compile time.
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
      function_exported?(expanded_module, :lt?, 2) ->
        {module_alias, :module_ord}

      function_exported?(expanded_module, :ord, 1) ->
        ast = build_behaviour_ord_ast(expanded_module, behaviour_opts, meta)
        {ast, :ord_map}

      function_exported?(expanded_module, :__struct__, 0) ->
        ast = build_struct_filter_ast(expanded_module)
        {ast, :projection}

      true ->
        raise CompileError,
          line: Keyword.get(meta, :line),
          description:
            "Module #{inspect(expanded_module)} does not have lt?/2, ord/1, or __struct__/0"
    end
  end

  defp build_projection_ast(other, _or_else, _behaviour_opts, meta, _caller_env) do
    raise CompileError,
      line: Keyword.get(meta, :line),
      description: Errors.invalid_projection_type(other)
  end

  # ============================================================================
  # MODULE PROJECTION HELPERS
  # ============================================================================

  # Build a type filter projection for struct modules
  # Returns true for matching structs, false otherwise
  # This allows type partitioning without imposing struct-field ordering
  defp build_struct_filter_ast(struct_module) do
    quote do
      fn
        %unquote(struct_module){} -> true
        _ -> false
      end
    end
  end

  # Generates a call to the behaviour's ord/1 function with options.
  #
  # The behaviour's ord/1 returns an Ord map at runtime, which the executor
  # uses directly (no contramap wrapping needed).
  defp build_behaviour_ord_ast(behaviour_module, behaviour_opts, _meta) do
    quote do
      unquote(behaviour_module).ord(unquote(behaviour_opts))
    end
  end

  # ============================================================================
  # METADATA EXTRACTION
  # ============================================================================

  defp extract_meta(meta) when is_list(meta) do
    %{
      line: Keyword.get(meta, :line),
      column: Keyword.get(meta, :column)
    }
  end
end
