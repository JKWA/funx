defmodule Funx.Ord.Dsl.Parser do
  @moduledoc false
  # Internal parser for Ord DSL - converts keyword list AST into Step structs

  alias Funx.Monad.Maybe
  alias Funx.Optics.Lens
  alias Funx.Optics.Prism
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
    raise CompileError,
      description:
        "Invalid Ord DSL syntax. Expected `asc projection` or `desc projection`, got: #{inspect(other)}"
  end

  # ============================================================================
  # PROJECTION PARSING
  # ============================================================================

  defp parse_projection(direction, projection_value, opts, meta, caller_env) do
    default = Keyword.get(opts, :default)
    custom_ord = Keyword.get(opts, :ord)

    projection_ast = build_projection_ast(projection_value, default, meta, caller_env)
    ord_ast = custom_ord || quote(do: Funx.Ord)
    metadata = extract_meta(meta)

    Step.new(direction, projection_ast, ord_ast, metadata)
  end

  # ============================================================================
  # PROJECTION AST BUILDING
  # ============================================================================

  # Atom without default -> Lens.key(atom)
  defp build_projection_ast(atom, nil, _meta, _caller_env) when is_atom(atom) do
    quote do
      fn value ->
        Lens.view!(value, Lens.key(unquote(atom)))
      end
    end
  end

  # Atom with default -> {Prism.key(atom), default}
  defp build_projection_ast(atom, default, _meta, _caller_env)
       when is_atom(atom) and not is_nil(default) do
    quote do
      fn value ->
        value
        |> Prism.preview(Prism.key(unquote(atom)))
        |> Maybe.get_or_else(unquote(default))
      end
    end
  end

  # Function (captured or anonymous)
  defp build_projection_ast({:&, _, _} = fun_ast, default, meta, _caller_env) do
    if is_nil(default) do
      fun_ast
    else
      raise CompileError,
        line: Keyword.get(meta, :line),
        description:
          "The `default:` option is only valid with atom or explicit Prism projections, not with functions."
    end
  end

  defp build_projection_ast({:fn, _, _} = fun_ast, default, meta, _caller_env) do
    if is_nil(default) do
      fun_ast
    else
      raise CompileError,
        line: Keyword.get(meta, :line),
        description:
          "The `default:` option is only valid with atom or explicit Prism projections, not with functions."
    end
  end

  # Explicit Lens struct
  defp build_projection_ast(
         {{:., _, [{:__aliases__, _, [:Lens]}, :key]}, _, _} = lens_ast,
         default,
         meta,
         _caller_env
       ) do
    if is_nil(default) do
      quote do
        fn value -> Lens.view!(value, unquote(lens_ast)) end
      end
    else
      raise CompileError,
        line: Keyword.get(meta, :line),
        description:
          "The `default:` option is only valid with atom or explicit Prism projections, not with Lens."
    end
  end

  defp build_projection_ast(
         {{:., _, [{:__aliases__, _, [:Lens]}, :path]}, _, _} = lens_ast,
         default,
         meta,
         _caller_env
       ) do
    if is_nil(default) do
      quote do
        fn value -> Lens.view!(value, unquote(lens_ast)) end
      end
    else
      raise CompileError,
        line: Keyword.get(meta, :line),
        description:
          "The `default:` option is only valid with atom or explicit Prism projections, not with Lens."
    end
  end

  # Explicit Prism - bare or with default option
  defp build_projection_ast(
         {{:., _, [{:__aliases__, _, [:Prism]}, _]}, _, _} = prism_ast,
         default,
         meta,
         _caller_env
       ) do
    if is_nil(default) do
      # Bare Prism -> use Maybe.lift_ord
      quote do
        fn value -> Prism.preview(value, unquote(prism_ast)) end
      end
    else
      raise CompileError,
        line: Keyword.get(meta, :line),
        description:
          "Ambiguous Prism usage. Use either bare Prism OR {Prism, default} tuple, not Prism with `default:` option."
    end
  end

  defp build_projection_ast({prism_ast, default_ast}, nil, _meta, _caller_env) do
    # {Prism.key(:foo), default} tuple
    quote do
      fn value ->
        value
        |> Prism.preview(unquote(prism_ast))
        |> Maybe.get_or_else(unquote(default_ast))
      end
    end
  end

  defp build_projection_ast({_prism_ast, _default_ast}, _extra_default, meta, _caller_env) do
    raise CompileError,
      line: Keyword.get(meta, :line),
      description:
        "Invalid usage. {Prism, default} tuple already contains a default value. Do not use `default:` option."
  end

  # Module (Behaviour implementation)
  defp build_projection_ast({:__aliases__, _, _} = module_alias, default, meta, caller_env) do
    if is_nil(default) do
      # Expand module alias
      expanded_module = Macro.expand(module_alias, caller_env)

      # Validate that module implements Behaviour
      validate_behaviour_implementation!(expanded_module, meta)

      quote do
        fn value -> unquote(expanded_module).project(value, []) end
      end
    else
      raise CompileError,
        line: Keyword.get(meta, :line),
        description:
          "The `default:` option is only valid with atom or explicit Prism projections, not with Behaviour modules."
    end
  end

  # Unknown projection type
  defp build_projection_ast(other, _default, meta, _caller_env) do
    raise CompileError,
      line: Keyword.get(meta, :line),
      description:
        "Invalid projection. Expected atom, function, Lens, Prism, or Behaviour module, got: #{inspect(other)}"
  end

  # ============================================================================
  # VALIDATION
  # ============================================================================

  defp validate_behaviour_implementation!(module, meta) do
    # Ensure module is compiled
    Code.ensure_compiled!(module)

    # Check if module implements Behaviour
    behaviours = module.module_info(:attributes)[:behaviour] || []

    unless Funx.Ord.Dsl.Behaviour in behaviours do
      raise CompileError,
        line: Keyword.get(meta, :line),
        description: "Module #{inspect(module)} must implement Funx.Ord.Dsl.Behaviour"
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
