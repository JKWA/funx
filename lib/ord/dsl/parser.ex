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
  #   - :atom              → Lens.key(:atom)
  #   - :atom, or_else: x  → {Prism.key(:atom), x}
  #   - Lens.key(...)      → Lens.key(...) (pass through)
  #   - Prism.key(...)     → Prism.key(...) (pass through)
  #   - {Prism, x}         → {Prism, x} (pass through)
  #   - fn -> ... end      → fn -> ... end (pass through)
  #   - Behaviour          → fn v -> Behaviour.project(v, []) end
  #
  # contramap/2 is the ONLY place that converts optics to functions.
  # The parser never creates function wrappers around optics.

  alias Funx.Optics.Lens
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

    projection_ast = build_projection_ast(projection_value, or_else, meta, caller_env)
    ord_ast = custom_ord || quote(do: Funx.Ord)
    metadata = extract_meta(meta)

    Step.new(direction, projection_ast, ord_ast, metadata)
  end

  # ============================================================================
  # PROJECTION AST BUILDING
  # ============================================================================

  defp build_projection_ast(atom, nil, _meta, _caller_env) when is_atom(atom) do
    quote do
      Lens.key(unquote(atom))
    end
  end

  defp build_projection_ast(atom, or_else, _meta, _caller_env)
       when is_atom(atom) and not is_nil(or_else) do
    quote do
      {Prism.key(unquote(atom)), unquote(or_else)}
    end
  end

  defp build_projection_ast({:&, _, _} = fun_ast, or_else, meta, _caller_env) do
    if is_nil(or_else) do
      fun_ast
    else
      raise CompileError,
        line: Keyword.get(meta, :line),
        description: Errors.or_else_with_captured_function()
    end
  end

  defp build_projection_ast({:fn, _, _} = fun_ast, or_else, meta, _caller_env) do
    if is_nil(or_else) do
      fun_ast
    else
      raise CompileError,
        line: Keyword.get(meta, :line),
        description: Errors.or_else_with_anonymous_function()
    end
  end

  defp build_projection_ast(
         {{:., _, [{:__aliases__, _, _}, _]}, _, args} = fun_ast,
         or_else,
         _meta,
         _caller_env
       )
       when args == [] or is_nil(args) do
    if is_nil(or_else) do
      fun_ast
    else
      # Runtime: if helper returns Lens, contramap will raise
      quote do
        {unquote(fun_ast), unquote(or_else)}
      end
    end
  end

  defp build_projection_ast(
         {{:., _, [{:__aliases__, _, [:Lens]}, :key]}, _, _} = lens_ast,
         or_else,
         meta,
         _caller_env
       ) do
    if is_nil(or_else) do
      lens_ast
    else
      raise CompileError,
        line: Keyword.get(meta, :line),
        description: Errors.or_else_with_lens()
    end
  end

  defp build_projection_ast(
         {{:., _, [{:__aliases__, _, [:Lens]}, :path]}, _, _} = lens_ast,
         or_else,
         meta,
         _caller_env
       ) do
    if is_nil(or_else) do
      lens_ast
    else
      raise CompileError,
        line: Keyword.get(meta, :line),
        description: Errors.or_else_with_lens()
    end
  end

  defp build_projection_ast(
         {{:., _, [{:__aliases__, _, [:Prism]}, _]}, _, _} = prism_ast,
         or_else,
         _meta,
         _caller_env
       ) do
    if is_nil(or_else) do
      prism_ast
    else
      quote do
        {unquote(prism_ast), unquote(or_else)}
      end
    end
  end

  defp build_projection_ast({prism_ast, or_else_ast}, nil, _meta, _caller_env) do
    quote do
      {unquote(prism_ast), unquote(or_else_ast)}
    end
  end

  defp build_projection_ast({_prism_ast, _or_else_ast}, _extra_or_else, meta, _caller_env) do
    raise CompileError,
      line: Keyword.get(meta, :line),
      description: Errors.redundant_or_else()
  end

  defp build_projection_ast({:__aliases__, _, _} = module_alias, or_else, meta, caller_env) do
    if is_nil(or_else) do
      expanded_module = Macro.expand(module_alias, caller_env)
      validate_behaviour_implementation!(expanded_module, meta)

      quote do
        fn value -> unquote(expanded_module).project(value, []) end
      end
    else
      raise CompileError,
        line: Keyword.get(meta, :line),
        description: Errors.or_else_with_behaviour()
    end
  end

  defp build_projection_ast(other, _or_else, meta, _caller_env) do
    raise CompileError,
      line: Keyword.get(meta, :line),
      description: Errors.invalid_projection_type(other)
  end

  # ============================================================================
  # VALIDATION
  # ============================================================================

  defp validate_behaviour_implementation!(module, meta) do
    Code.ensure_compiled!(module)
    behaviours = module.module_info(:attributes)[:behaviour] || []

    unless Funx.Ord.Dsl.Behaviour in behaviours do
      raise CompileError,
        line: Keyword.get(meta, :line),
        description: Errors.missing_behaviour_implementation(module)
    end

    :ok
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
